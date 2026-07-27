# The `ui` layer
#
# Colorscheme, statusline, buffer line, keymap hints, notifications.
#
# Implements `cvim.ui.*`, declared in `../options/ui.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
{
  imports = [
    ./theme.nix
  ];
}
