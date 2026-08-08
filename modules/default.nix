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

    # Not layers: tree-wide invariants, asserted on every build.
    # platform-guard reads the SOURCE of every module above; keymap-guard reads
    # the EVALUATED config. Each file says why it is the one and not the other.
    ./platform-guard
    ./keymap-guard

    # Not a layer. The resolved PORT rows from the inherited-defaults sweep —
    # editor-wide options that belong to no single feature. See its header.
    ./defaults

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
