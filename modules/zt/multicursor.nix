# Multicursor — multicursor.nvim (jake-stewart), NOT multicursors.nvim.
#
# The distinction is the point: multicursors.nvim was dropped from the U3
# motions cluster on provenance (17 months unmaintained, single maintainer) —
# ZT's own gate. On the U13 day-1 drive ZT chose to restore the CAPABILITY via
# a maintained alternative with his old keys matched, which this module is.
# Do not swap back to multicursors.nvim.
#
# Keys are the old runtime's m-group verbatim (add/skip cursor above/below,
# add/skip by match, toggle), translated to multicursor.nvim's API.
#
# Editor-surface states:
#   empty   — cursor-add with no match / at buffer edge is the plugin's own
#             no-op; toggle with a single cursor simply stays single.
#   partial — none: the plugin has no external deps.
#   error   — leaving multicursor mode is <esc> (plugin default); a stuck
#             state is cleared by :MCclear if it ever occurs.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.editor;

  mc = key: desc: fn: {
    mode = [
      "n"
      "x"
    ];
    key = "<leader>m${key}";
    action.__raw = ''
      function()
        require("multicursor-nvim").${fn}
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
    extraPlugins = [ pkgs.vimPlugins.multicursor-nvim ];

    extraConfigLua = ''
      require("multicursor-nvim").setup()
    '';

    keymaps = [
      (mc "a" "Add cursor above" "lineAddCursor(-1)")
      (mc "A" "Skip cursor above" "lineSkipCursor(-1)")
      (mc "b" "Add cursor below" "lineAddCursor(1)")
      (mc "B" "Skip cursor below" "lineSkipCursor(1)")
      (mc "n" "Add cursor by match (next)" "matchAddCursor(1)")
      (mc "p" "Add cursor by match (prev)" "matchAddCursor(-1)")
      (mc "s" "Skip cursor by match (next)" "matchSkipCursor(1)")
      (mc "S" "Skip cursor by match (prev)" "matchSkipCursor(-1)")
      (mc "t" "Toggle cursor" "toggleCursor()")
    ];
  };
}
