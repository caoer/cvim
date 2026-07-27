# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`.
#
# Three units write language modules into this directory — 8a (go, typescript,
# nix, lua), 8b (python, bash, markdown, web) and 8c (java, csharp, cpp, rust) —
# so this import list is the one file they share. Each unit adds only its own
# lines and never reorders or tidies a sibling's, and the list is kept
# ALPHABETICAL. That is what makes the three-way merge mechanical rather than a
# judgement call. Reconciling it is a named integration step, owned by whoever
# owns `../options/lang.nix`.
{
  imports = [
    ./bash.nix
    ./go.nix
    ./lua.nix
    ./markdown.nix
    ./nix.nix
    ./python.nix
    ./typescript.nix
    ./web.nix
  ];
}
