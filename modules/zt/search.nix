# `<leader>s` = +Search — snacks pickers over ephemeral editor state.
#
# ZT gave `s` to Search on the U13 day-1 drive (khanelivim layout); SOPS moved
# to `<leader>c` (Secrets) in the same change. The split from `<leader>f`
# (+Find): f finds FILES and project text; s searches EDITOR STATE — buffer
# lines, marks, registers, undo, notifications.
#
# Editor-surface states:
#   empty   — a picker over empty state (no marks, no undo) renders snacks' own
#             empty list, not an error.
#   partial — picker layer disabled: the whole group is absent rather than
#             present-and-broken (same rule as dashboard's picker keys).
#   error   — Snacks.picker functions fail loud through Snacks.notify.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
  pickerOn = config.cvim.picker.enable;

  pick = key: desc: fn: {
    mode = "n";
    key = "<leader>s${key}";
    action.__raw = ''
      function()
        Snacks.picker.${fn}()
      end
    '';
    options = {
      desc = desc;
      silent = true;
    };
  };
in
{
  config = lib.mkIf (cfg.enable && pickerOn) {
    keymaps = [
      (pick "s" "Search buffer lines" "lines")
      (pick "g" "Grep in project" "grep")
      (pick "w" "Search word under cursor" "grep_word")
      (pick "m" "Search marks" "marks")
      (pick "r" "Search registers" "registers")
      (pick "u" "Undo history" "undo")
      (pick "n" "Notification history" "notifications")
    ];
  };
}
