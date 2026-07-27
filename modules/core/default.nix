# The `core` layer
#
# Syntax, completion, formatting, linting, motions, surround/pairs.
#
# Implements `cvim.editor.*`, declared in `../options/editor.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# EAGER BY CHOICE. No module in this layer writes a `lazyLoad` spec. That is a
# decision, not an omission.
#
# `plugins.lz-n` is not enabled on main (verified by eval, not by a card
# status), and nixvim routes setup() on exactly that switch —
# lib/plugins/mk-neovim-plugin.nix writes `luaConfig.content` into init.lua
# only when `lazyLoad.enable` is FALSE; when it is true, setup is handed to the
# lz.n spec instead. So with no provider consuming the spec, a lazy-loaded
# plugin NEVER LOADS AND ITS setup() NEVER RUNS — it is an opt plugin, silently
# absent, on a green build.
#
# Writing no specs is therefore what makes this layer actually load. Every
# module here lands its setup() call directly in init.lua, which is checkable
# in the generated Lua rather than inferred. This layer is also the one every
# other layer assumes is already loaded, so eager is the honest shape for it
# regardless of when lz-n lands.
{
  imports = [
    ./lazy.nix
    ./leader.nix
    ./treesitter.nix
    ./completion.nix
    ./format.nix
    ./lint.nix
    ./comments.nix
    ./text.nix
    ./motions.nix
    ./sessions.nix
    ./large-buffer.nix
  ];
}
