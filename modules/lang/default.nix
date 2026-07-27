# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [ ];
}
