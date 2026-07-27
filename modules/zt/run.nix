# Run — overseer.nvim task runner, `<leader>R` group.
#
# ZT chose it on the U13 day-1 drive (old R-group). Overseer autodetects
# tasks from the project (justfile, make, npm scripts, ...); no per-project
# config is declared here.
#
# Editor-surface states:
#   empty   — OverseerRun in a project with no detectable tasks shows an empty
#             task menu, not an error.
#   partial — none.
#   error   — a failing task stays visible in the task list with its output.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.overseer.enable = true;

    keymaps = [
      {
        mode = "n";
        key = "<leader>RR";
        action = "<cmd>OverseerRun<cr>";
        options = {
          desc = "Run task";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>Rt";
        action = "<cmd>OverseerToggle<cr>";
        options = {
          desc = "Toggle task list";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>Ra";
        action = "<cmd>OverseerQuickAction<cr>";
        options = {
          desc = "Task quick action";
          silent = true;
        };
      }
    ];
  };
}
