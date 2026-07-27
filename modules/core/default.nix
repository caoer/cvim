# The `core` layer
#
# Syntax, completion, formatting, linting, motions, surround/pairs.
#
# Implements `cvim.editor.*`, declared in `../options/editor.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [ ];
}
