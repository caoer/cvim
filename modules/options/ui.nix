# `cvim.ui` — Appearance and chrome.
{ lib, ... }:
{
  options.cvim.ui.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Appearance and chrome: colorscheme, statusline, buffer line, keymap
      hints, notifications, and markup rendering.
    '';
  };
}
