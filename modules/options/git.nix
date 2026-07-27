# `cvim.git` — Git integration.
{ lib, ... }:
{
  options.cvim.git.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Git integration: signs, diffs, conflict resolution, and the
      repository-browsing entry points.
    '';
  };
}
