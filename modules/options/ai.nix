# `cvim.ai` — AI tooling.
{ lib, ... }:
{
  options.cvim.ai.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      AI tooling.

      Kept as its own area rather than folded into `utilities` because more
      AI tooling is plausible and the cost of the split is one file.
    '';
  };
}
