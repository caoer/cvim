# The `cvim.*` option surface: one file per feature area, plus the profile
# cascade that gives them their defaults.
#
# House rule for every option declared under here: `false` and `null` are
# first-class values. A feature a user cannot turn off, and a setting a user
# cannot explicitly blank, is a defect — not a simplification. Concretely that
# means `types.bool` over "always on", and `types.nullOr t` wherever "unset"
# and "set to nothing" are different answers.
#
# Profiles set area defaults with `mkDefault` so any single option stays
# overridable without opting out of the whole profile.
{
  imports = [
    ./profiles.nix

    ./ai.nix
    ./editor.nix
    ./git.nix
    ./lang.nix
    ./lsp.nix
    ./picker.nix
    ./ui.nix
    ./utilities.nix
  ];
}
