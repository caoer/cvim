# `cvim.ui` — Appearance and chrome.
{ lib, ... }:
{
  options.cvim.ui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Appearance and chrome: colorscheme, statusline, buffer line, keymap
        hints, notifications, and markup rendering.
      '';
    };

    theme.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to set a colorscheme.

        `true` gives you tokyonight, following the terminal's appearance over
        OSC 11 — night when the terminal is dark, day when it is light.

        `false` leaves neovim on its built-in colorscheme. That is the right
        answer when you are bisecting a highlight bug and need to know whether
        the theme is the cause, and it is why this is an option rather than an
        assumption.
      '';
    };
  };
}
