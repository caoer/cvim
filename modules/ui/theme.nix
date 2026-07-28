# Colorschemes — tokyonight applied at startup, three alternates installed
# beside it, all four following the terminal's appearance.
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
# ── FOLLOWING `&background` IS THE SELECTION RULE FOR THE ALTERNATES ─────────
#
# Every scheme installed here maps `&background` to a variant of its own:
# tokyonight `style`/`light_style`, catppuccin `background.{dark,light}`,
# kanagawa `background.{dark,light}`, rose-pine `variant = "auto"`. Each also
# re-applies on a live `background` flip — measured, not read off a README:
# `Normal` guibg goes 1a1b26→e1e2e7 (tokyonight), 1e1e2e→eff1f5 (catppuccin),
# 1f1f28→f2ecbc (kanagawa), 191724→faf4ed (rose-pine). A scheme that ignored
# `&background` would freeze the editor in one appearance while wezterm flipped,
# which is the exact failure this layer exists to prevent — so it does not go in
# this file.
#
# THE FAMILY NAME FOLLOWS THE TERMINAL; A VARIANT NAME PINS ONE APPEARANCE.
# `<leader>uC` lists both, because `:colorscheme` does. Picking `kanagawa` keeps
# the OSC 11 link; picking `kanagawa-lotus` loads lotus directly and leaves
# `&background` on `dark` — observed, and correct, since naming a variant is how
# a user says "this one, regardless". Pick the family name to keep the flip.
#
# ── WHY `colorscheme` IS FORCED ─────────────────────────────────────────────
#
# nixvim's colorscheme modules each set the top-level `colorscheme` to their own
# name with `mkDefault` (lib/plugins/mk-neovim-plugin.nix). Enable four and
# there are four definitions at one priority, which is a merge conflict at eval,
# not a silent last-one-wins. `lib.mkForce` names the startup scheme once and
# takes the other three out of the race: they are INSTALLED, not applied.
# `modules/ui/theme-picker.nix` is what applies them, and it reads this same
# option rather than repeating the name.
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
    colorscheme = lib.mkForce "tokyonight";

    colorschemes = {
      tokyonight = {
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

          # nvim paints its own background. Transparent would hand the terminal
          # the background while every other colour here is still computed
          # against tokyonight's — and `modules/ui/bufferline.nix` and the
          # statusline read those live highlight groups, so the two halves would
          # disagree. Same class of failure as the light-mode tab bar incident.
          transparent = false;

          # `:terminal` buffers get the theme's 16 ANSI colours. cvim runs real
          # programs in them — lazygit through snacks, the claudecode terminal,
          # overseer task output — and without this those panes render in the
          # host terminal's palette while the editor renders in tokyonight's.
          terminal_colors = true;

          # THE DEFAULT HERE IS COMPUTED FROM A PLUGIN CVIM DOES NOT HAVE.
          # Upstream's default is `all = package.loaded.lazy == nil` and
          # `auto = true` (config.lua:41-48): `auto` asks lazy.nvim which plugins
          # are installed, and `all` is the fallback for when there is no lazy to
          # ask. cvim has no lazy.nvim, so `all` has been true all along by
          # accident of absence, and `auto` has been dead code. Both are stated
          # here so the setting is a decision: style all 72 plugin groups
          # (groups/*.lua) and let the cache absorb the cost, rather than
          # enumerate cvim's plugin set in a second place that rots on every
          # plugin added.
          plugins = {
            all = true;
            auto = false;
          };

          # Compiled highlights land in `stdpath("cache")/tokyonight-<style>.json`.
          # The cache key is the style, but the stored entry carries the colours,
          # the group list, the plugin version and the opts it was built from, and
          # is discarded unless all of them still match (groups/init.lua:139-149).
          # So a settings change in this file takes effect on the next start; there
          # is no stale-theme trap to clear by hand after a rebuild.
          cache = true;
        };
      };

      # The alternates. Each states both halves of its `&background` mapping for
      # the same reason tokyonight does — the light half is the one that gets
      # silently inherited and then found wrong on the first appearance flip.
      catppuccin = {
        enable = true;
        settings.background = {
          dark = "mocha";
          light = "latte";
        };
      };

      kanagawa = {
        enable = true;
        settings.background = {
          dark = "wave";
          light = "lotus";
        };
      };

      rose-pine = {
        enable = true;
        settings = {
          # `auto` is what reads `&background`; without it rose-pine pins one
          # variant and the OSC 11 link is dead for this scheme alone.
          variant = "auto";
          dark_variant = "main";
        };
      };
    };
  };
}
