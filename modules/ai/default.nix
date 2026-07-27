# The `ai` layer
#
# AI tooling.
#
# Implements `cvim.ai.*`, declared in `../options/ai.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [
    ./claudecode.nix
  ];
}
