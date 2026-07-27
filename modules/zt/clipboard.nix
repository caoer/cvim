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
#          Capture: results/captures/u9a-clipboard-ssh-tmux.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
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
    '';
  };
}
