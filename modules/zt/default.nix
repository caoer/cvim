# The `zt` layer
#
# Keymaps, filetypes, spelling, clipboard, and the Lua residue.
#
# Implements `cvim.utilities.*`, declared in `../options/utilities.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [
    # One concern per file, alphabetical. The Lua residue and the declarative
    # half were built as separate units and reconciled here.
    ./clipboard.nix
    ./codesign.nix
    ./duckdb.nix
    ./filetypes.nix
    ./folds.nix
    ./keymaps.nix
    ./leader-parity.nix
    ./opts.nix
    ./plugins.nix
    ./random-string.nix
    ./save-notify.nix
    ./secrets.nix
    ./spell.nix
    ./suda.nix
    ./treesitter-guard.nix
    ./yank-ref.nix
  ];
}
