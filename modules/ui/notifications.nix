# Notifications and messages — noice for the message/cmdline UI, nvim-notify as
# the popup backend, plus a startup queue so nothing said early is lost.
#
# The queue is the part worth explaining. `vim.notify` is the builtin until a
# plugin replaces it, and plugins are set up after this runs. Anything that
# notifies in between would land in the raw message area and vanish behind the
# first redraw — which is exactly when a broken plugin has something to say. So
# `vim.notify` is swapped for a collector, and the collected calls are flushed
# once something replaces it, or handed back to the builtin after 500ms if
# nothing does.
#
# Verified as a mechanism, not as a return value: a notification emitted while
# the collector was installed arrived in nvim-notify's own history at the right
# level, and `vim.g.cvim_notify_replayed` counted it. Had the flush silently done
# nothing, the counter would read 0 and the history would be empty — so the check
# cannot pass on a no-op.
#
# Editor-surface states:
#   empty   — nothing to show: no popup, no placeholder window, and
#             `notify.history()` is empty. Silence is the correct render.
#   partial — more notifications than fit: nvim-notify stacks them and they time
#             out independently; the queue only ever holds startup traffic.
#   error   — a notification arriving before the backend exists is queued, not
#             dropped, and never raises. The 500ms timer is the backstop for the
#             case where no backend ever appears.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.notifications.enable) {
    plugins = {
      noice.enable = true;
      notify.enable = true;
    };

    extraConfigLuaPre = ''
      do
        local queued = {}
        local original = vim.notify
        local function capture(...)
          table.insert(queued, vim.F.pack_len(...))
        end
        vim.notify = capture

        local timer = assert(vim.uv.new_timer())
        local check = assert(vim.uv.new_check())
        vim.g.cvim_notify_replayed = 0

        -- Both the check and the timer can reach replay, and closing a libuv
        -- handle twice raises. One flush only.
        local done = false
        local function replay()
          if done then
            return
          end
          done = true
          timer:stop()
          check:stop()
          timer:close()
          check:close()
          -- Only hand the builtin back if nothing replaced it; otherwise the
          -- replacement is what the queue should flush into.
          if vim.notify == capture then
            vim.notify = original
          end
          vim.schedule(function()
            for _, args in ipairs(queued) do
              vim.notify(vim.F.unpack_len(args))
            end
            vim.g.cvim_notify_replayed = #queued
            queued = {}
          end)
        end

        check:start(function()
          if vim.notify ~= capture then
            replay()
          end
        end)
        timer:start(500, 0, replay)
      end
    '';
  };
}
