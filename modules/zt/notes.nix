# Notes — neorg (journal + workspace) and snacks scratch buffers.
#
# ZT chose neorg on the U13 day-1 drive. Default workspace: ~/notes — adjust
# the dirman path below if his norg tree lives elsewhere; the binding set is
# the old runtime's n-group flattened (the old no* sub-prefix collapses one
# level, match-not-copy).
#
# nn / ns are snacks scratch, not neorg — same as the old editor, where "New
# Scratch Buffer" / "Select Scratch Buffer" were snacks keys living in the
# Notes group.
#
# Editor-surface states:
#   empty   — journal/index commands create their files on first use; grep or
#             find over an empty workspace is an empty picker.
#   partial — a non-norg buffer: neorg commands report through their own
#             :Neorg error output, scratch keys work everywhere.
#   error   — a missing ~/notes directory is created by dirman on first
#             workspace open, not an error.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
  pickerOn = config.cvim.picker.enable;

  nmap = key: desc: action: {
    mode = "n";
    key = "<leader>n${key}";
    inherit action;
    options = {
      desc = desc;
      silent = true;
    };
  };

  nlua = key: desc: fn: {
    mode = "n";
    key = "<leader>n${key}";
    action.__raw = ''
      function()
        ${fn}
      end
    '';
    options = {
      desc = desc;
      silent = true;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    plugins.neorg = {
      enable = true;
      settings.load = {
        "core.defaults" = {
          __empty = null;
        };
        "core.concealer" = {
          __empty = null;
        };
        "core.journal" = {
          __empty = null;
        };
        "core.dirman".config = {
          workspaces.notes = "~/notes";
          default_workspace = "notes";
        };
      };
    };

    keymaps = [
      (nmap "c" "Toggle Concealer" "<cmd>Neorg toggle-concealer<cr>")
      (nmap "j" "Today's Journal" "<cmd>Neorg journal today<cr>")
      (nmap "J" "Custom Date Journal" "<cmd>Neorg journal custom<cr>")
      (nmap "i" "Open Index" "<cmd>Neorg index<cr>")
      (nmap "r" "Return from Notes" "<cmd>Neorg return<cr>")
      (nlua "n" "New Scratch Buffer" "Snacks.scratch()")
      (nlua "s" "Select Scratch Buffer" "Snacks.scratch.select()")
    ]
    ++ lib.optionals pickerOn [
      (nlua "g" "Grep Notes" ''Snacks.picker.grep({ cwd = vim.fn.expand("~/notes") })'')
      (nlua "f" "Find Notes" ''Snacks.picker.files({ cwd = vim.fn.expand("~/notes") })'')
    ];
  };
}
