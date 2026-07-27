# File references for pasting into an agent prompt: `@path#Lm-n` and the
# `<content …>` XML wrapper.
#
# Four shapes on two axes — relative vs absolute path, reference-only vs
# reference-plus-content. All four write register `+`, so the clipboard layer
# decides where they actually land (pbcopy locally, OSC52 + tmux elsewhere).
#
# All four states below were measured, not inferred.
#
# empty:   an unnamed buffer emits exactly `@`. The notify still fires, so the
#          nothing-to-reference case is visible rather than silent, and nothing
#          errors.
# partial: outside a git worktree the relative form falls back to `:~:.` and
#          emits `@fixture.lua` — cwd-relative rather than failing.
# error:   `git rev-parse` failing is caught by the `shell_error` check and
#          degrades to `:~:.`. Measured twice, because the two causes degrade
#          differently: with NO git binary at all (`PATH` pointing at an empty
#          directory) it still emits the relative `@src/fixture.lua`, since
#          `:~:.` resolves against a live cwd; with a DEAD cwd it emits the
#          absolute `@/private/tmp/.../fixture.lua`, since `:~:.` has nothing
#          to relativize against. Neither raises.
#          Captures: results/captures/u9a/u9a-yank-ref-parity.txt,
#                    results/captures/u9a/u9a-surface-states.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLua = ''
      local zt_yank = {}

      local function zt_git_root()
        local root = vim.fn.systemlist("git rev-parse --show-toplevel 2>/dev/null")[1]
        if vim.v.shell_error == 0 and root and #root > 0 then return root end
        return nil
      end

      local function zt_relative_path()
        local abs = vim.fn.expand("%:p")
        local git_root = zt_git_root()
        if git_root then
          return abs:gsub("^" .. vim.pesc(git_root) .. "/", "")
        end
        return vim.fn.fnamemodify(abs, ":~:.")
      end

      local function zt_get_range(is_visual)
        if not is_visual then return nil, nil end
        local s = vim.fn.line("v")
        local e = vim.fn.line(".")
        if s > e then s, e = e, s end
        if s > 0 and e > 0 then return s, e end
        return nil, nil
      end

      function zt_yank.yank_ref(is_visual)
        local path = zt_relative_path()
        local s, e = zt_get_range(is_visual)
        local ref = s and string.format("@%s#L%d-%d", path, s, e) or ("@" .. path)
        vim.fn.setreg("+", ref)
        vim.notify(ref)
      end

      function zt_yank.yank_ref_abs(is_visual)
        local path = vim.fn.expand("%:p")
        local s, e = zt_get_range(is_visual)
        local ref = s and string.format("@%s#L%d-%d", path, s, e) or ("@" .. path)
        vim.fn.setreg("+", ref)
        vim.notify(ref)
      end

      function zt_yank.yank_xml_empty(is_visual)
        local filepath = vim.fn.expand("%:p")
        local s, e = zt_get_range(is_visual)
        if not s then s = vim.fn.line("."); e = s end
        local xml = string.format('<content filepath="@%s" lines="L%d-%d">\n  \n</content>', filepath, s, e)
        vim.fn.setreg("+", xml)
        vim.notify(string.format("Copied ref: @%s L%d-%d", filepath, s, e))
      end

      function zt_yank.yank_xml_full(is_visual)
        local filepath = vim.fn.expand("%:p")
        local s, e = zt_get_range(is_visual)
        local lines
        if s then
          lines = vim.fn.getline(s, e)
        else
          s = vim.fn.line("."); e = s
          lines = { vim.fn.getline(s) }
        end
        local content = table.concat(lines, "\n")
        local xml = string.format('<content filepath="%s" lines="L%d-%d">\n%s\n</content>', filepath, s, e, content)
        vim.fn.setreg("+", xml)
        vim.notify(string.format("Copied: %s L%d-%d", filepath, s, e))
      end

      -- Exposed for the parity harness; the keymaps below are the real surface.
      _G.zt_yank = zt_yank

      vim.keymap.set("n", "<leader>yc", function() zt_yank.yank_ref(false) end, { desc = "Copy @file ref (relative)" })
      vim.keymap.set("v", "<leader>yc", function() zt_yank.yank_ref(true) end, { desc = "Copy @file ref (relative)" })
      vim.keymap.set("n", "<leader>yC", function() zt_yank.yank_ref_abs(false) end, { desc = "Copy @file ref (absolute)" })
      vim.keymap.set("v", "<leader>yC", function() zt_yank.yank_ref_abs(true) end, { desc = "Copy @file ref (absolute)" })
      vim.keymap.set("n", "<leader>yx", function() zt_yank.yank_xml_empty(false) end, { desc = "Copy XML ref (no content)" })
      vim.keymap.set("v", "<leader>yx", function() zt_yank.yank_xml_empty(true) end, { desc = "Copy XML ref (no content)" })
      vim.keymap.set("n", "<leader>yX", function() zt_yank.yank_xml_full(false) end, { desc = "Copy XML with content" })
      vim.keymap.set("v", "<leader>yX", function() zt_yank.yank_xml_full(true) end, { desc = "Copy XML with content" })
    '';
  };
}
