# `cvim.picker` — Finding things.
{ lib, ... }:
{
  options.cvim.picker.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Finding things: the picker, the file explorer, and the diagnostics
      list.
    '';
  };
}
