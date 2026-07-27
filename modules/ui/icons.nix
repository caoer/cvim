# File-type icons — mini.icons, standing in for nvim-web-devicons.
#
# `mockDevIcons` registers mini.icons under the `nvim-web-devicons` module name,
# so plugins that require that module by name find it and cvim ships one icon set
# instead of two. Verified: `require("nvim-web-devicons")` resolves in the running
# editor with only mini.icons enabled.
#
# Icon highlight groups are mini.icons' own, derived from the colorscheme, so they
# track an appearance flip — the lua glyph's colour changes between night and day
# in the captures, which is why no colour is set here.
#
# Editor-surface states:
#   empty   — a buffer with no file (`[No Name]`) gets the default file glyph.
#   partial — an extension mini.icons does not know returns the generic file
#             glyph rather than nothing; verified with a nonsense extension,
#             which produced a different glyph from a known one rather than an
#             empty string.
#   error   — a plugin requiring `nvim-web-devicons` when the mock is off gets a
#             normal Lua module-not-found error, not a silent blank icon.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.icons.enable) {
    plugins.mini-icons = {
      enable = true;
      mockDevIcons = true;
    };
  };
}
