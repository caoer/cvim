# The `picker` layer
#
# Picker, file explorer, diagnostics list.
#
# Implements `cvim.picker.*`, declared in `../options/picker.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# Ships: snacks.picker (general finder), fff (fast file finder), yazi (file
# explorer), trouble (diagnostics list). glance and harpoon were evaluated as
# candidates and rejected by ZT on 2026-07-27 — see the U5 card.
#
# Editor-surface states — each verified in a running editor on aarch64-darwin,
# captures under results/captures/u5/ in the session directory:
#
#   empty    Picker shows the typed query with a `0/0` counter and an empty
#            list; trouble prints "No results for **diagnostics**" and opens
#            no window (`open_no_results = false`).
#            [state-a-zero-results.ansi, state-e-trouble-empty.ansi]
#
#   partial  NOT DISTINGUISHABLE, and that is a measured result rather than an
#            omission: while an LSP has attached but published nothing,
#            trouble renders BYTE-IDENTICALLY to a clean buffer — `diff`
#            reports no difference between the two captures. trouble is a pure
#            function of `vim.diagnostic` contents, so it cannot report attach
#            progress. The distinguishing signal is the statusline's
#            partial-attach element, which is U7 work, not this layer's.
#            [state-g-trouble-partial.ansi vs state-e-trouble-empty.ansi]
#
#   error    Trouble renders a grouped tree with severity markers and counts
#            (`E:1 W:1 H:1`) and per-item positions; the sign column carries
#            E/W/H. [state-f-trouble-error.ansi]
#
# Narrow-pane (80x24, SSH reality): both pickers fit exactly, widest rendered
# line 80 columns, zero overflow. snacks.picker drops to a stacked
# list-over-preview layout; fff drops its preview entirely, being below the
# 130-column `layout.flex.size` threshold.
# [state-h-snacks-grep-80x24.ansi, state-i-fff-80x24.ansi]
{
  imports = [
    ./snacks-picker.nix
    ./fff.nix
    ./yazi.nix
    ./trouble.nix
  ];
}
