# The `dap` layer
#
# Debugger, adapters, and the debug-session UI.
#
# `dap` has no file under `options/` — the eight areas there are fixed — so
# this layer declares its own `cvim.dap.*` options next to the modules that
# read them. One implementation unit owns this directory.
{
  imports = [ ];
}
