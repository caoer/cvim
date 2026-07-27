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
    # Cross-layer build-time assertions (U12). Not a layer and not an area:
    # every property it checks is violated by two layers interacting, so no
    # single layer is positioned to assert it.
    ./assertions.nix

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
