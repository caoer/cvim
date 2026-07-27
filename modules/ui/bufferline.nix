# Buffer line — open buffers as tabs, numbered by position.
#
# `numbers = "ordinal"` makes each tab show its position rather than its buffer
# id, which is what makes `<leader>1-9` mean "the Nth tab you can see" instead of
# "whichever buffer happens to hold that id". The jumps are declared here beside
# the setting they depend on.
#
# No highlight table is set, deliberately. bufferline derives its colours from
# the active colorscheme and recomputes them on `ColorScheme`, so the tab bar
# follows a live appearance flip. Writing a highlight table here is how the
# light-mode tab bar became unreadable: the values were absolute, so the dark
# variant's fill and selected colours survived into day mode. Verified by
# capture — every tab-bar colour changes between appearances, sharing no RGB
# value with the other mode.
#
# Editor-surface states:
#   empty   — one buffer: a single tab renders, no error, no placeholder. With no
#             file at all the tab reads `[No Name]`. Both observed.
#   partial — more tabs than columns: the visible ones render and the remainder
#             collapse into a trailing count (at 80 columns, 4 buffers show as 2
#             tabs plus `2`). Nothing overlaps and nothing is cut mid-glyph.
#   error   — `<leader>N` for a tab that does not exist is a no-op from
#             bufferline's own command; it does not raise.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.bufferline.enable) {
    plugins.bufferline = {
      enable = true;
      settings.options.numbers = "ordinal";
    };

    keymaps = map (n: {
      mode = "n";
      key = "<leader>${toString n}";
      action = "<cmd>BufferLineGoToBuffer ${toString n}<cr>";
      options = {
        desc = "Go to buffer ${toString n}";
        silent = true;
      };
    }) (lib.range 1 9);
  };
}
