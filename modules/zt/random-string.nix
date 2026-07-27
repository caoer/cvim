# `<leader>xr` in visual mode — replace the selection with a random 16-char
# alphanumeric string.
#
# For scrubbing a token out of a buffer before pasting it somewhere, and for
# generating a placeholder that is obviously not a real value.
#
# Two details carried across deliberately:
#   - `"_c` deletes into the black-hole register, so the secret being replaced
#     never lands in `"` and therefore never reaches shada or the clipboard.
#     Using plain `c` here would defeat the purpose of the binding.
#   - The alphabet is `[A-Za-z0-9]` with no separators, so the result is safe to
#     drop into a quoted string, a URL, or a shell word without escaping.
#
# The seed mixes `os.clock()` with `os.time()` because `os.time()` alone has
# one-second resolution — two invocations inside the same second would return
# the same string.
#
# empty:   an empty visual selection replaces nothing and inserts the 16 chars
#          at the cursor; the binding is x-mode only, so there is no normal-mode
#          path that could fire on no selection at all.
# partial: a multi-line selection collapses to the single generated string —
#          `c` on a linewise selection is vim's own behaviour, not a truncation
#          introduced here.
# error:   none reachable — no I/O, no external process, no plugin dependency.
#          Capture: results/captures/u9a/u9a-random-string.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLua = ''
      vim.keymap.set("x", "<leader>xr", function()
        math.randomseed(os.clock() * 1e7 + os.time())
        local chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        local t = {}
        for i = 1, 16 do
          local idx = math.random(#chars)
          t[i] = chars:sub(idx, idx)
        end
        local s = table.concat(t)
        local keys = vim.api.nvim_replace_termcodes('"_c' .. s .. "<Esc>", true, false, true)
        vim.api.nvim_feedkeys(keys, "x", false)
      end, { desc = "Replace selection with random string" })
    '';
  };
}
