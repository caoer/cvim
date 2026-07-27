# Session persistence — persistence.nvim.
#
# empty:   no saved session for a directory — `load()` is a silent no-op and
#          the keys below simply do nothing; `select()` shows an empty picker.
# partial: sessions save per-cwd, so a repo opened from a different directory
#          reads as "no session" rather than loading the wrong one.
# error:   a corrupt session file surfaces as neovim's own :source error;
#          persistence adds no failure modes of its own.
#
# Added on ZT's first daily-drive day (U13): khanelivim shipped session
# save/load and cvim's initial cut dropped it. The keys are khanelivim's,
# verbatim, for muscle-memory parity — this trio is measured from the old
# runtime's keymap dump, not from khanelivim's source.
#
# Saving is automatic: persistence writes the session on VimLeavePre. Its
# writes comply with the state-dir rule — sessions land under
# `vim.fn.stdpath('state') .. '/sessions/'`, never in the store.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.persistence.enable = true;

    keymaps = [
      {
        mode = "n";
        key = "<leader>Ss";
        action.__raw = ''
          function()
            require("persistence").select()
          end
        '';
        options = {
          desc = "Select a session to load";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>Sl";
        action.__raw = ''
          function()
            require("persistence").load()
          end
        '';
        options = {
          desc = "Load the session for the current directory";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>SL";
        action.__raw = ''
          function()
            require("persistence").load({ last = true })
          end
        '';
        options = {
          desc = "Load the last session";
          silent = true;
        };
      }
    ];
  };
}
