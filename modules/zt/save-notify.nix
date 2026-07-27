# `<leader>ww` — write the buffer and say so.
#
# `:w` is silent for an already-small change, which on a slow filesystem is
# indistinguishable from "nothing happened". This writes and then names the
# file that was written.
#
# The notification is emitted per keypress, not per event, so repeated saves
# do not stack a growing column: each call replaces the previous transient.
#
# empty:   an unnamed buffer fails at `:w` with vim's own E32 before the notify
#          runs — the error is the notification, and no "Saved" claim is made
#          for a write that did not happen.
# partial: with snacks absent (it belongs to another layer) the pcall falls
#          back to `vim.notify`, so the binding is never dead — it degrades
#          from a titled fancy notification to a plain one.
# error:   a write that fails for any other reason (read-only file, missing
#          parent directory) raises from `vim.cmd("w")` and stops the function,
#          so no success notification follows a failed save.
#          Capture: results/captures/u9a/u9a-save-notify-6x.ansi.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLua = ''
      vim.keymap.set("n", "<leader>ww", function()
        vim.cmd("w")
        local ok, snacks = pcall(require, "snacks")
        if ok and snacks.notify then
          snacks.notify.info(vim.fn.expand("%"), { title = "Saved", style = "fancy" })
        else
          vim.notify("Saved: " .. vim.fn.expand("%"), vim.log.levels.INFO)
        end
      end, { desc = "Save file" })
    '';
  };
}
