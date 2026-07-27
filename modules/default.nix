# cvim module root.
#
# Two halves, deliberately separate:
#   options/  declares the `cvim.*` semantic surface (what a user turns on)
#   <layer>/  implements it in nixvim terms (how it is turned on)
#
# Ownership: one implementation unit owns exactly one `<layer>/` directory and
# exactly one `options/<area>.nix` file. Nothing here is shared between units.
{
  imports = [
    ./options

    # Not a layer and owns no options: a tree-wide invariant, asserted against
    # the source of every module above. See platform-guard/default.nix.
    ./platform-guard

    ./core
    ./ui
    ./picker
    ./git
    ./lsp
    ./lang
    ./ai
    ./zt
  ];
}
