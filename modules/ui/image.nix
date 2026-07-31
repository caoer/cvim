# Inline images and mermaid diagrams — snacks.image.
#
# This is the unit decisions/u4a-snacks-image.md deferred out of U4a (session
# 27-07-nvim-distro). The recipe below is the one that session verified in both
# directions; the findings it recorded are folded in rather than re-derived.
#
# ## What renders, and through what
#
# snacks.image places images over the kitty graphics protocol. In a markdown
# buffer its doc renderer draws image links inline and shells `mmdc` to turn
# ```mermaid fences into PNGs. The mermaid converter keys its theme on
# `vim.o.background` (image/init.lua picks `neutral` for light, `dark` for
# dark), so diagrams follow a day/night flip like everything else in this layer.
#
# ## Inline placement depends on the terminal, not on this module
#
# INLINE placement inside tmux needs the protocol's unicode placeholders.
# Mainline wezterm lacks them (upstream issue 986); ZT runs a patched build
# (upstream PR #7924 plus local retro-resolution fixes, branch
# build-placeholders), and that wezterm exports `SNACKS_KITTY=true`
# (osfiles config/wezterm/common.lua) because snacks' terminal table
# hard-codes wezterm as placeholder-less. The env var is the capability
# advertisement; only the patched terminal sets it.
#
# Two consequences worth stating:
#   - Without placeholders snacks disables inline (image/init.lua) and diagrams
#     open in a floating window instead. Degraded, not broken.
#   - The tmux server must have `SNACKS_KITTY` in its environment for panes to
#     inherit it. A tmux server started under an old terminal keeps the old
#     environment until `set-environment -g` or a server restart.
#
# ## The two packages, both load-bearing
#
#   mermaid-cli   `mmdc`, the fence converter. It drives a browser through
#                 puppeteer; the darwin browser path lives in
#                 image-puppeteer.nix, split out because the platform guard
#                 forbids a platform condition in a file that also carries
#                 plugin config.
#   imagemagick   `magick`, which snacks needs to convert raster formats.
#                 Shipped explicitly because U4a measured the bare closure
#                 resolving `magick` to a homebrew binary — silently absent on
#                 any linux host.
#
# This stack measured 479 MiB of closure in U4a (lab 1.50 → 1.96 GiB), which is
# why `cvim.ui.image.enable` exists and why the server profile turns it off.
#
# Editor-surface states:
#   empty   — a markdown buffer with no image links and no fences gets nothing:
#             no extmarks, no conversions, no processes spawned.
#   partial — terminal without placeholders (stock wezterm, or a pane missing
#             `SNACKS_KITTY`): diagrams render in a float instead of inline —
#             measured in the U4a session, not theorised.
#   error   — the browser is unreachable (var unset, Chrome missing): `mmdc`
#             exits nonzero and snacks reports the failed conversion; the
#             buffer text is untouched.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.image.enable) {
    # This module owns the `image` key, the way dashboard.nix owns `notifier`.
    # Naming a key is enabling it; `enabled = true` spells the intent.
    plugins.snacks = {
      enable = true;
      settings.image.enabled = true;
    };

    extraPackages = with pkgs; [
      mermaid-cli
      imagemagick
    ];
  };
}
