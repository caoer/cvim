# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`.
#
# Three units wrote the language modules in this directory — 8a (go,
# typescript, nix, lua), 8b (python, bash, markdown, web) and 8c (java, csharp,
# cpp, rust) — so this import list is the one file they shared. Each unit added
# only its own lines and never reordered a sibling's, and the list is kept
# ALPHABETICAL. That is what made the three-way merge mechanical rather than a
# judgement call; reconciling it was a named integration step rather than a
# surprise.
#
# The four heavy toolchains are imported here exactly like every other language
# and are off on every profile, `default` included (D4). **Importing them is
# what makes their absence a measurement rather than a coincidence:** a language
# that is never imported is also absent from every closure, and from the outside
# those two are indistinguishable.
{
  imports = [
    ./bash.nix
    ./cpp.nix
    ./csharp.nix
    ./go.nix
    ./java.nix
    ./lua.nix
    ./markdown.nix
    ./nix.nix
    ./python.nix
    ./rust.nix
    ./toml.nix
    ./typescript.nix
    ./web.nix
  ];
}
