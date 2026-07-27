# Colorscheme — tokyonight, following the terminal's appearance.
#
# The whole mechanism is one link: neovim asks the terminal for its background
# with OSC 11, sets `&background` from the reply, and tokyonight picks `style`
# when that is `dark` and `light_style` when it is `light`. It re-picks on every
# change, so a live appearance flip restyles the running editor. Nothing here
# detects anything; wezterm and tmux already do (osfiles config/wezterm — dark →
# "Tokyo Night", light → "Tokyo Night Day", and tmux is driven to the same
# family). Verified end to end: wezterm → tmux → nvim reports
# `background=dark` / `colors_name=tokyonight-night`, and `:set background=light`
# flips it to `tokyonight-day` with every UI colour recomputed.
#
# This is why no module in this layer may write a hex literal. A baked colour
# survives the flip and the other appearance renders it unreadable — the
# light-mode tab bar incident. Take colours from live highlight groups instead.
#
# Editor-surface states:
#   empty   — no buffers open: the theme still owns the background and chrome.
#   partial — terminal never answers OSC 11: `&background` stays `dark`, so the
#             night variant applies. Correct-looking, never an error.
#   error   — colorscheme missing from the closure: neovim raises E185 loudly at
#             startup. There is no silent fallback to guess at.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.theme.enable) {
    colorschemes.tokyonight = {
      enable = true;

      settings = {
        # Variant names, not colours. `night` is the variant whose background
        # matches wezterm's "Tokyo Night" exactly, and `day` matches "Tokyo
        # Night Day" — so the editor and the terminal agree in both
        # appearances. `light_style` is tokyonight's own default; it is stated
        # anyway, so the light half of the contract is legible at the call site
        # rather than inherited silently.
        style = "night";
        light_style = "day";
      };
    };
  };
}
