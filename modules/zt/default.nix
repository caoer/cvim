# The `zt` layer
#
# Keymaps, filetypes, spelling, clipboard, and the Lua residue.
#
# Implements `cvim.utilities.*`, declared in `../options/utilities.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [
    # U9b — the declarative half. One concern per file, kept alphabetical so
    # the Leader's reconcile with U9a's list at integration is mechanical.
    ./filetypes.nix
    ./keymaps.nix
    ./opts.nix
    ./plugins.nix
    ./secrets.nix
    ./spell.nix
  ];
}
