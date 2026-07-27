# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# Three units write language modules into this directory (8a: go/typescript/
# nix/lua, 8b: python/bash/markdown/web, 8c: java/csharp/cpp/rust), so this
# import list is the one file they share. Keep it ALPHABETICAL and add only
# your own lines — never reorder or tidy a sibling's — which makes the
# three-way merge mechanical instead of a judgement call.
{
  imports = [
    ./go.nix
    ./lua.nix
    ./nix.nix
    ./typescript.nix
  ];
}
