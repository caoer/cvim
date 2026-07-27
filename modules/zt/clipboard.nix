# Dual clipboard: pbcopy/pbpaste on a local mac, OSC 52 + tmux everywhere else.
#
# This path predates cvim and cnixvim both. Every detail in it was earned by a
# failure, so it is carried across unchanged:
#
#   - The `regtype == "V"` trailing-newline append on BOTH branches. A
#     linewise yank whose text does not end in a newline pastes as charwise in
#     the receiving app, which silently joins it to the line it lands on.
#   - `require("vim.ui.clipboard.osc52").copy(reg)` rather than a hand-rolled
#     escape sequence — core owns the chunking and the base64, including the
#     terminal payload limit.
#   - `tmux save-buffer -` for paste, not OSC 52. OSC 52 paste requires a
#     terminal reply, which is unavailable over a plain pipe; the tmux buffer
#     is the only readable side over SSH.
#   - The `2>/dev/null` on save-buffer: outside tmux it writes to stderr and
#     would otherwise land in the pasted text.
#
# The branch is chosen ONCE at startup from `has("mac")` and `SSH_CONNECTION`,
# so an nvim started locally keeps pbcopy for its whole life even if a later
# `ssh` runs inside it. That is the intended behaviour — the clipboard should
# follow the terminal that owns the nvim process, not the innermost shell.
#
# empty:   yanking an empty selection sends an empty payload; pbcopy clears the
#          pasteboard and OSC 52 emits an empty sequence. Neither errors.
# partial: outside tmux and outside a local mac, copy still works (OSC 52 goes
#          straight to the terminal) but paste returns `{}` — the tmux buffer
#          is the only paste source. `"+p` is a silent no-op, by construction.
# error:   `pbcopy` missing (non-darwin reached via the mac branch) cannot
#          happen — the branch is guarded on `has("mac")`. `io.popen` failing
#          for pbpaste would raise; it is the same call the whole platform
#          depends on, so it is deliberately not defended.
#          Capture: results/captures/u9a/u9a-clipboard-ssh-tmux.txt.
#
# `<leader>yt` (zt_to_outer_tmux) has its own three states, since it targets a
# tty rather than the clipboard provider:
#   empty:   an empty unnamed register returns immediately — no process spawned,
#            no escape sequence written, no notification.
#   partial: OUTER_TTY unset falls through `tmux show-environment` and then
#            `tmux -L zt list-clients`; whichever resolves first is used.
#   error:   all three probes empty ⇒ a WARN, "Could not find outer tmux TTY",
#            and no write. This is the common case OUTSIDE ZT's nested-tmux
#            setup, so it must be loud rather than silent.
#          Capture: results/captures/u9a/u9a-outer-tmux.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    # Routes the unnamed register into `+`, so plain `yy` reaches the provider
    # below. Without it the provider is configured and unreachable from every
    # keystroke that does not name `"+` explicitly — a state that answers "yes"
    # to "is the clipboard set up" and fails on the first `yy`.
    #
    # ZT does not set this in cnixvim; it arrives from khanelivim
    # (`modules/nixvim/options.nix`, `clipboard.register = "unnamedplus"`).
    # cvim has no khanelivim, so it is declared here, beside the provider it
    # feeds. `unnamedplus` — not `unnamed` — is the ported value.
    clipboard.register = "unnamedplus";

    extraConfigLua = ''
      local is_local_mac = vim.fn.has("mac") == 1 and vim.env.SSH_CONNECTION == nil

      local function zt_copy_fn(reg)
        if is_local_mac then
          return function(lines, regtype)
            local text = table.concat(lines, "\n")
            if regtype == "V" then text = text .. "\n" end
            vim.fn.system("pbcopy", text)
          end
        end
        local osc52_fn = require("vim.ui.clipboard.osc52").copy(reg)
        return function(lines, regtype)
          if regtype == "V" then
            local copy = { unpack(lines) }
            table.insert(copy, "")
            return osc52_fn(copy)
          end
          return osc52_fn(lines)
        end
      end

      local function zt_paste_fn()
        if is_local_mac then
          local h = io.popen("pbpaste")
          local content = h:read("*a")
          h:close()
          local lines = vim.split(content, "\n", { plain = true })
          if #lines > 1 and lines[#lines] == "" then
            table.remove(lines)
            return lines, "V"
          end
          return lines
        end
        local h = io.popen("tmux save-buffer - 2>/dev/null")
        if h then
          local content = h:read("*a")
          h:close()
          if content and content ~= "" then
            local lines = vim.split(content, "\n", { plain = true })
            if #lines > 1 and lines[#lines] == "" then
              table.remove(lines)
              return lines, "V"
            end
            return lines
          end
        end
        return {}
      end

      vim.g.clipboard = {
        name = is_local_mac and "pbcopy/pbpaste" or "OSC 52 + tmux",
        copy  = { ["+"] = zt_copy_fn("+"), ["*"] = zt_copy_fn("*") },
        paste = { ["+"] = zt_paste_fn,      ["*"] = zt_paste_fn },
      }

      -- Push the last yank to the OUTER tmux's terminal, bypassing vim.g.clipboard.
      --
      -- `zt_yank.to_outer_tmux` in cnixvim, where it was defined but never bound.
      -- ZT's call: the unbound state was an oversight, so it is ported AND wired.
      --
      -- Why it exists: when nvim runs inside a NESTED tmux — the popup server on
      -- socket `scratch` — an OSC 52 written to nvim's own stdout reaches only
      -- the inner server, which is not the one holding the real terminal. This
      -- writes the escape sequence straight to the outer client's tty instead,
      -- so the yank lands in the actual system clipboard.
      --
      -- The three earned details, carried across intact:
      --   - `base64 -w0`: without -w0, base64 wraps at 76 columns and the
      --     embedded newlines terminate the OSC sequence early.
      --   - the OUTER_TTY chain: the env var is exported by
      --     ~/.config/tmux/start-shell.sh when the socket is `scratch`; the
      --     `tmux show-environment -g` fallback covers a shell that started
      --     before that ran, since start-shell.sh also sets it in the tmux
      --     server env.
      --   - `tmux -L zt list-clients`: the last-resort probe naming ZT's outer
      --     socket directly, for when neither the env var nor the server env
      --     carries it.
      --
      -- TWO FIXES vs the cnixvim text. Both are latent defects in a path that
      -- had never executed anywhere, not regressions.
      --
      --  1. `-g` on the show-environment probe. start-shell.sh writes with
      --     `tmux set-environment -g`, which is the GLOBAL environment; the
      --     original read `tmux show-environment` with no flag, which is the
      --     SESSION environment. Measured on a live server: after
      --     `set-environment -g`, session-scope `show-environment` answers
      --     "unknown variable" — and it still does for a session created
      --     afterwards. The two scopes never meet, so this fallback could
      --     never have resolved the value start-shell.sh sets.
      --
      --  2. The trailing newline. `base64 -w0` emits a trailing 0x0a and the
      --     original interpolated it INTO the payload, between the base64 and
      --     the BEL terminator. Stripped here. Measured honestly: tmux
      --     TOLERATES the stray byte (it recovered the payload either way), so
      --     this is spec-correctness rather than an observed breakage — a bare
      --     LF inside an OSC string is not valid, and terminals that are
      --     stricter than tmux are the ones this path exists to reach.
      function _G.zt_to_outer_tmux()
        local content = vim.fn.getreg('"')
        if content == "" then return end
        local tty = os.getenv("OUTER_TTY")
        if not tty or tty == "" then
          local env_output = vim.fn.system("tmux show-environment -g OUTER_TTY 2>/dev/null"):gsub("%s+$", "")
          tty = env_output:match("OUTER_TTY=(.+)")
        end
        if not tty or tty == "" then
          tty = vim.fn.system("tmux -L zt list-clients -F '#{client_tty}' 2>/dev/null | head -1"):gsub("%s+$", "")
        end
        if not tty or tty == "" then
          vim.notify("Could not find outer tmux TTY", vim.log.levels.WARN)
          return
        end
        local encoded = vim.fn.system("echo -n " .. vim.fn.shellescape(content) .. " | base64 -w0"):gsub("%s+$", "")
        local cmd = string.format("printf '\\033]52;c;%s\\007' > %s", encoded, tty)
        vim.fn.system(cmd)
      end

      vim.keymap.set("n", "<leader>yt", _G.zt_to_outer_tmux,
        { desc = "Copy last yank to outer tmux (OSC 52)" })
    '';
  };
}
