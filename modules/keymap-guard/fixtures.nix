# FIXTURES — never imported as a module. Plain data, fed through the SAME
# collision function the live config goes through (`default.nix`).
#
# Read `default.nix` first; this file only makes sense against it.
#
# WHY DATA AND NOT FILES-READ-AS-TEXT. `platform-guard/fixtures/` are `.nix`
# files the detector reads with `builtins.readFile`, because that detector's
# subject IS source text. This one's subject is the evaluated config, so a
# fixture that were source text would exercise a different code path than the
# thing under test — the fixture would pass while the detector rotted. These
# are keymap records, the same shape the live sources normalize into.
#
# They cannot leak into the live config: `default.nix` imports this with
# `import`, as a value, and nothing adds it to any `imports` list. It declares
# no `config`, so it is not a module and could not contribute keymaps even if
# someone tried. That is trap 4 — "the guard flags itself" — closed
# structurally rather than by an exclusion that can be forgotten.
#
# ── ONE FIXTURE PER DISCRIMINATOR ──────────────────────────────────────────
#
# The detector has three independent mechanisms, and a fixture exercising only
# some of them certifies the rest as working. `platform-guard` paid for this
# lesson: regressing its rule to a bare token match left its only quiet fixture
# green, so the boolean-predicate half was untested and could have rotted
# silently. Each fixture below is the arm that goes red for exactly one
# regression:
#
#   fires.sameModePair          the prefix relation itself
#   fires.leaderNotation        `<leader>`/`<Space>` normalization
#   fires.mapModeOverlap        mode "" expanding to include "n"
#   fires.visualSelectOverlap   mode "v" expanding to { "x", "s" }
#   quiet.modeDisjoint          mode sets compared by INTERSECTION, not by
#                               presence of a shared key
#   quiet.siblingsNoPrefix      a shared prefix that is not itself a mapping
#
# Collapse mode handling to "any mode matches any mode" and `quiet.modeDisjoint`
# goes red. Narrow it to string equality and both `mapModeOverlap` and
# `visualSelectOverlap` go quiet — red on the other arm. Neither regression can
# ship green.
{
  # ── MUST BE FLAGGED ────────────────────────────────────────────────────────
  fires = {
    # The defect this guard exists to prevent, in its measured form.
    # `<leader>l` was a complete mapping and a prefix of nine `<leader>l*`
    # siblings. Defined first it fired immediately and `d` ran as a bare
    # normal-mode command; `p` pasted the SYSTEM CLIPBOARD into the buffer,
    # because `modules/zt/clipboard.nix` sets `clipboard.register =
    # "unnamedplus"`. Removed in `874ef06`; nothing but this file prevents the
    # third instance.
    sameModePair = [
      {
        mode = "n";
        key = "<leader>l";
      }
      {
        mode = "n";
        key = "<leader>ld";
      }
    ];

    # Same collision, written in two spellings of the same key. `mapleader` is
    # a space, so `<Space>gg` and `<leader>g` are the same key space and the
    # prefix relation is real — but only after normalization. Compare the raw
    # strings and this pair is invisible.
    #
    # Not hypothetical: `<leader>gg` is a live mapping (lazygit), and `<Space>`
    # is an ordinary way to write it.
    leaderNotation = [
      {
        mode = "n";
        key = "<leader>g";
      }
      {
        mode = "n";
        key = "<Space>gg";
      }
    ];

    # Mode `""` is `:map` — normal, visual, select AND operator-pending. It is
    # the shape `lsp.keymaps` emits (nixvim writes `mode = ""` for every entry
    # in it), so this is the live tree's own spelling, not a contrivance. A
    # detector comparing mode strings for equality reads `""` and `"n"` as
    # different and misses every collision the LSP surface can produce.
    mapModeOverlap = [
      {
        mode = "";
        key = "<leader>h";
      }
      {
        mode = "n";
        key = "<leader>hv";
      }
    ];

    # Mode `"v"` is visual AND select; `"x"` is visual only. They overlap, so
    # this stalls, and again string equality would miss it. The complement of
    # `quiet.modeDisjoint` below: same prefix, same visual family, opposite
    # verdict — which is what makes both verdicts mean something.
    visualSelectOverlap = [
      {
        mode = "v";
        key = "<leader>h";
      }
      {
        mode = "x";
        key = "<leader>hz";
      }
    ];
  };

  # ── MUST STAY QUIET ────────────────────────────────────────────────────────
  quiet = {
    # THE FALSE POSITIVE THIS GUARD MUST NEVER PRODUCE, copied from the live
    # tree: `modules/zt/plugins.nix` binds `<leader>h` in VISUAL mode (run the
    # Hurl selection) while `<leader>hv` and `<leader>hm` are NORMAL mode.
    # Mode-disjoint, so no precedence conflict exists and nothing waits — the
    # code is correct exactly as written.
    #
    # 19db7e85 found this shape before the guard was built. A check that
    # red-flags correct code teaches people to work around it, and the
    # workaround is permanent while the check is not.
    modeDisjoint = [
      {
        mode = "v";
        key = "<leader>h";
      }
      {
        mode = "n";
        key = "<leader>hv";
      }
      {
        mode = "n";
        key = "<leader>hm";
      }
    ];

    # Mappings sharing a prefix that is NOT itself a mapping. This is the
    # ordinary, correct way to build a key space and it is the ENTIRE tree:
    # all 79 `keymaps` entries share `<leader>`, and `<leader>` binds nothing.
    # Nothing waits, because there is nothing shorter to wait on. A detector
    # keyed on "shares a leading substring" rather than "IS a prefix of" flags
    # every one of them.
    #
    # All three are live mappings, and their LENGTHS DIFFER on purpose. Equal-
    # length keys can never collide — the detector requires the prefix to be
    # strictly shorter — so a fixture of same-length siblings is quiet under
    # every regression and certifies nothing. That is the failure this file
    # warns about, and the first draft of this fixture had it.
    siblingsNoPrefix = [
      {
        mode = "n";
        key = "<leader>e";
      }
      {
        mode = "n";
        key = "<leader>ff";
      }
      {
        mode = "n";
        key = "<leader>fw";
      }
    ];
  };
}
