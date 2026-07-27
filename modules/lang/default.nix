# The `lang` layer
#
# One file per language: grammar, server, formatter, linter.
#
# Implements `cvim.lang.*`, declared in `../options/lang.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# The four heavy toolchains are imported here like every other language and are
# off on every profile, `default` included (D4). Importing them is what makes
# their absence a measurement rather than a coincidence: a language that is
# never imported is also absent from every closure, and the two are
# indistinguishable from the outside.
{
  imports = [
    ./java.nix
    ./csharp.nix
    ./cpp.nix
    ./rust.nix
  ];
}
