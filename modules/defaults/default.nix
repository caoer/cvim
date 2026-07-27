# Inherited-defaults decisions — the PORT rows from `cvim-defaults-parity`.
#
# WHY THIS DIRECTORY EXISTS. cvim has no khanelivim, so the 35 globals and 71
# opts cnixvim inherits that way are unset here. The parity sweep measured the
# difference (60 opts + 30 globals = 90 names), gave every one a decision, and
# this file is where the ones that resolved to PORT land. The other 80 resolved
# to DROP or to a named owning layer; the full table is the deliverable, at
# `results/defaults-parity-table.md` in the session tree.
#
# WHY NOT IN `core/`. Every `<layer>/` directory belongs to exactly one
# implementation unit, and these options are editor-wide rather than any one
# layer's — the same argument `core/leader.nix` makes for `mapleader`. Putting
# them in a feature layer is the ownership violation the layer carve prevents;
# putting them in `core/` specifically would mean two units writing `core/`.
#
# NO `cvim.defaults.enable` TOGGLE, DELIBERATELY. Every other layer gates on a
# `cvim.<area>.enable` switch because a layer is a feature you might not want.
# This is not a feature. A toggle here would mean "you may also have the state
# where these are undecided", and undecided-by-absence is precisely the accident
# this card exists to remove. There is no coherent off position.
#
# THE GATE THAT PRODUCED THIS LIST was completeness, not agreement with
# cnixvim. "Matches cnixvim" was explicitly not sufficient, because most of
# cnixvim's values are khanelivim taste that nobody on this project chose, and
# diffing to zero would have promoted ~90 accidents into ~90 requirements. Each
# line below carries the reason it survived that filter.
#
# Editor-surface states: not applicable — these are scalar option values with
# no rendering, empty, or error surface of their own.
{ ... }:
{
  opts = {
    # ── Decided by ZT, 2026-07-27 ──────────────────────────────────────────
    #
    # Eight names that no evidence could settle: they are taste, they are ON in
    # ZT's cnixvim editor today, and they are visible on every screen. Asked
    # directly rather than inferred, on the same precedent as `exrc` — which
    # went the other way and ships OFF by decision.

    # Line display. `relativenumber` is the consequential one: it changes how
    # every count motion is composed.
    number = true;
    relativenumber = true;
    cursorline = true;

    # Long lines run off the right edge instead of flowing onto continuation
    # rows. Note this is the one row where cvim's pre-port state was neovim's
    # default and the port REMOVES behaviour. Prose filetypes that want soft
    # wrap should set it buffer-locally in the layer that owns them.
    wrap = false;

    # Search casing, and they only work as a pair: `/foo` matches Foo and FOO,
    # `/Foo` matches only Foo. Without `ignorecase`, `smartcase` does nothing.
    ignorecase = true;
    smartcase = true;

    # New windows open where the eye goes next rather than displacing the one
    # being read.
    splitbelow = true;
    splitright = true;

    # ── Ported on evidence ─────────────────────────────────────────────────

    # U7 named this an LSP-layer dependency and the failure at `no` is silent:
    # every diagnostic sign and the lightbulb vanish with no error, so the layer
    # is configured correctly and displays nothing.
    #
    # The measured default `auto` does NOT break U7 — signs appear when there
    # are signs. What `auto` does is re-flow the whole buffer horizontally every
    # time a diagnostic arrives or clears. `yes` costs one column permanently
    # and makes U7's dependency an explicit choice instead of a default that
    # happens to be survivable.
    signcolumn = "yes";
  };
}
