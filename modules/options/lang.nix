# `cvim.lang` — Per-language toolchains.
{ lib, ... }:
{
  options.cvim.lang.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Per-language toolchains: grammars, servers, formatters, and linters
      for the languages actually written on this host.

      This is the heavy area. The `server` profile turns it off, which is the
      difference between a remote text editor and a workstation build.
    '';
  };
}
