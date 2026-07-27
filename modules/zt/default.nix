# The `zt` layer
#
# Keymaps, filetypes, spelling, clipboard, and the Lua residue.
#
# Implements `cvim.utilities.*`, declared in `../options/utilities.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [
    # U9a — the Lua residue. One concern per file.
    ./clipboard.nix
    ./folds.nix
    ./treesitter-guard.nix
    ./yank-ref.nix
  ];
}
