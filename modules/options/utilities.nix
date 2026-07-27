# `cvim.utilities` — Editor-wide odds and ends.
{ lib, ... }:
{
  options.cvim.utilities.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      The remaining editor-wide settings: keymaps, filetype associations,
      spelling, and the plugins that do not belong to any other area.
    '';
  };
}
