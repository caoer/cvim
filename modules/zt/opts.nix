# Editor option overrides — the taste settings from cnixvim's "Editor option
# overrides" section.
#
# Persistence-bearing options from that same section live in ./secrets.nix
# (`swapfile`, `shada`) and spelling in ./spell.nix, so each concern has one
# file. `backup` stays here: it is a plain editor preference, not part of the
# secret guard's mechanism.
#
# cnixvim needed `lib.mkForce` on several of these to beat khanelivim's
# values. cvim has no khanelivim and inherits nothing, so plain assignment is
# both sufficient and honest — a mkForce here would imply a contest that does
# not exist.
#
# Editor-surface states: not applicable — these are scalar option values with
# no rendering, empty, or error surface of their own.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    opts = {
      backup = false;
      hlsearch = false;
      scrolloff = 8;
      softtabstop = 2;
      updatetime = 50;
    };
  };
}
