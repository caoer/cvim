# nvim-lightbulb — a sign on lines where a code action is available.
#
# Advisory only: `gra` runs the code action whether or not the sign is showing.
#
# ── Hostile-defaults review (§4 convention 1) ───────────────────────────
#
# Provenance: nvim-lightbulb, kosayoda/nvim-lightbulb, MIT. Packaged in
# nixpkgs as `vimPlugins.nvim-lightbulb` and pinned through nixvim's own
# nixpkgs — not vendored, so no `rev`/`hash` pin is needed here. nixvim ships a
# maintained module for it (`plugins.nvim-lightbulb`). Upstream last touched
# 2026-04-27, actively maintained.
#
# Grep of its settings surface for
# `scan|watch|poll|index|auto.?(save|write|update)|network|telemetry`:
# no network, no telemetry, no scanning, no filesystem writes, no indexing.
# It reads code actions from servers already attached and draws an extmark.
#
# One genuinely hostile default, and it is why `updatetime` is set to -1 below.
#
# ── Why the naive wiring is wrong, twice ────────────────────────────────
#
# 1. `autocmd.enabled` defaults to FALSE. Enabling the plugin and stopping
#    there yields a plugin that loads, validates and never draws anything —
#    a silent no-op with a green build.
#
# 2. Turning `autocmd.enabled` on makes the plugin execute
#    `vim.opt.updatetime = 200` inside its own setup, globally. `updatetime`
#    is not a lightbulb setting: it governs CursorHold for every consumer and
#    the swap-file write interval. A sign-column decoration silently rewriting
#    a core editor option owned by another layer is exactly the class §4
#    convention 1 exists to catch. `updatetime = -1` is the documented opt-out
#    ("set to a negative value to avoid setting the updatetime") and the
#    plugin's guard is `if updatetime > 0`, so -1 skips the assignment
#    entirely.
#
#    Consequence, stated rather than hidden: the bulb refreshes on CursorHold,
#    so its latency is whatever `updatetime` the core layer chooses. At
#    neovim's stock 4000ms the bulb is slow. That is the core layer's call to
#    make for the whole editor, not this layer's to take by side effect.
{ config, lib, ... }:
let
  cfg = config.cvim.lsp;
in
{
  config = lib.mkIf (cfg.enable && cfg.lightbulb) {
    plugins.nvim-lightbulb = {
      enable = true;

      settings = {
        # Sign column only. Virtual text at end-of-line would compete with
        # diagnostics for the same cells, and the float/line/number handlers
        # decorate far more loudly than an advisory marker should.
        sign = {
          enabled = true;
          # Nerd-font glyph, one cell. Upstream's default is the emoji 💡,
          # which is double-width and misaligns the sign column.
          text = "󰌶";
          lens_text = "󰉼";
        };
        virtual_text.enabled = false;
        float.enabled = false;
        status_text.enabled = false;
        number.enabled = false;
        line.enabled = false;

        # Below diagnostic signs, so an error never loses its cell to a hint
        # that a code action exists.
        priority = 10;

        autocmd = {
          enabled = true;
          # See the header. -1 means "do not touch the global updatetime".
          updatetime = -1;
          events = [
            "CursorHold"
            "CursorHoldI"
          ];
        };

        # Clear the bulb when the window loses focus, so a stale marker never
        # sits in an inactive split.
        hide_in_unfocused_buffer = true;
      };
    };

    # ── The npcall shim ──────────────────────────────────────────────────
    #
    # nvim-lightbulb calls `vim.F.npcall` (init.lua:305 and :381). `vim.F` is
    # a deprecated namespace whose members are being re-homed onto `vim`
    # directly; `npcall`'s replacement is `vim.npcall`. Once the rename lands,
    # the old name routes through `vim.deprecate()` — and because the bulb
    # updates on CursorHold, that warning fires at cursor-idle cadence rather
    # than once. When the old name is finally deleted, the plugin breaks.
    #
    # Re-pointing the old name at the new one silences the deprecation path
    # and survives the deletion.
    #
    # The guard is the whole trick, and it is why this is not a one-liner.
    # Measured on this build: neovim 0.12.4 has `vim.F.npcall` as a function
    # and `vim.npcall` as NIL. An unguarded `vim.F.npcall = vim.npcall` would
    # therefore assign nil today and break nvim-lightbulb immediately — the
    # shim would cause the outage it exists to prevent. It must stay inert
    # until the replacement actually exists.
    #
    # `extraConfigLuaPre` so this runs before plugin setup.
    extraConfigLuaPre = ''
      if vim.F and vim.npcall then
        vim.F.npcall = vim.npcall
      end
    '';
  };
}
