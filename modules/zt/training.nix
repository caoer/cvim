# Vim training — hardtime.nvim, installed but OFF until toggled.
#
# ZT chose it on the U13 day-1 drive. It starts disabled: hardtime nags on
# every non-idiomatic keypress, and the daily-drive window is for finding
# cvim's defects, not for fighting a trainer. `<leader>vh` arms it when he
# wants a session.
#
# Editor-surface states:
#   empty   — disabled state is silent; nothing runs until the toggle.
#   partial — none.
#   error   — :Hardtime toggle is the plugin's own command; a failure is its
#             own error text.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.hardtime = {
      enable = true;
      settings.enabled = false;
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>vh";
        action = "<cmd>Hardtime toggle<cr>";
        options = {
          desc = "Toggle Hardtime";
          silent = true;
        };
      }
    ];
  };
}
