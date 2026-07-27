# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# The import list is kept ALPHABETICAL and each unit adds only its own lines,
# so three units landing four modules each merge mechanically. Reconciling it
# is a named integration step, owned by the unit that owns `../options/lang.nix`.
{
  imports = [
    ./bash.nix
    ./markdown.nix
    ./python.nix
    ./web.nix
  ];
}
