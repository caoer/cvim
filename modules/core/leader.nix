# `<leader>` and `<localleader>`
#
# empty:   `cvim.editor.leader = null` sets nothing; Neovim's default backslash applies.
# partial: one of leader/localLeader null — the other is still set; they are independent.
# error:   none reachable. Both are plain globals; a bad value binds a strange key, it does not fail.
#
# WHY THIS FILE EXISTS AT ALL. cvim is built directly on nixvim, which sets no
# `mapleader`. cnixvim appeared to set Space, but it does not — it inherits
# `globals.mapleader = " "` and `globals.maplocalleader = " "` from khanelivim
# (`modules/nixvim/keymappings.nix:14-15`, verified at rev 2d9c53ea). cvim has
# no khanelivim, so both were falling through to Neovim's default of backslash
# and every `<leader>` binding in the distro was landing on `\`.
#
# Both are set here, in the core layer, because `mapleader` is editor-wide
# behaviour rather than any one feature's — and because a global written from a
# feature layer is exactly the ownership violation the layer carve prevents.
#
# ORDERING IS THE WHOLE RISK. `mapleader` is read when a mapping is DEFINED,
# not when it is pressed. A global set after a layer has defined its keymaps
# binds nothing, and the failure is silent: the config looks right and half the
# keymaps answer to the wrong key. nixvim emits `globals` near the top of
# init.lua, ahead of the plugin and keymap sections, which is what makes this
# correct — see the readback check in the unit report rather than trusting the
# claim.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    globals = lib.filterAttrs (_: v: v != null) {
      mapleader = cfg.leader;
      maplocalleader = cfg.localLeader;
    };
  };
}
