# The `lsp` layer
#
# Server wiring, diagnostics presentation, LSP keymaps.
#
# Implements `cvim.lsp.*`, declared in `../options/lsp.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# This layer ships ZERO language servers. Servers belong to `lang`, which
# carries the toolchain closures and is the reason the `server` profile exists.
# A filetype that attaches nothing is this layer standing alone working
# correctly, not a defect.
#
# ── Editor-surface states ────────────────────────────────────────────────
#
# empty    No server covers the filetype: nothing binds, nothing renders, and
#          `require("cvim.lsp").status()` answers `state = "none"`. Silent by
#          design — an editor that announces every absence is noise.
# partial  Some expected servers attached, some did not: the attached ones give
#          their keymaps and diagnostics as usual, and `status()` answers
#          `state = "partial"` naming what is missing. This is the only state
#          the statusline is meant to draw attention to.
# error    A server dies, or its binary is not on `$PATH`: nothing is shown.
#          `:messages` stays empty, no dialog opens, every keymap in this layer
#          keeps working against whatever else attached, and `status()` counts
#          the server as missing rather than attached. The reason is written to
#          neovim's LSP log — `$XDG_STATE_HOME/nvim/lsp.log`, reachable as
#          `vim.lsp.log.get_filename()` — which records e.g.
#          `"taplo is not executable"`. Note the path, not a command:
#          nvim-lspconfig ships NO user commands at all on this pin, so
#          `:LspLog` and `:LspInfo` do not exist. `<leader>li` runs
#          `:checkhealth vim.lsp`, which is neovim's own report and does.
#
# ── Folds: this layer does not touch them ────────────────────────────────
#
# `foldmethod` and `foldexpr` are never set here, on `LspAttach` or on any
# other event. A buffer using marker folds still uses marker folds after a
# language server attaches, because nothing in this layer competes for the
# setting.
#
# That is a deliberate refusal, not an omission. The obvious LSP-folding wiring
# — an `LspAttach`/`BufWinEnter` autocmd that force-sets
# `foldexpr = v:lua.vim.lsp.foldexpr()` — clobbers whatever the buffer already
# had, and since LSP attaches asynchronously it lands *after* modelines and
# ftplugins have run. cnixvim carries a scheduled re-assert autocmd purely to
# undo that. cvim has no such wiring to undo, so the workaround does not need
# to exist here. Fold policy, including any opt-in LSP folding, belongs to the
# `zt` layer that owns the `zT` toggle.
{
  imports = [
    ./servers.nix
    ./expected-servers.nix
    ./diagnostics.nix
    ./keymaps.nix
    ./lightbulb.nix
  ];
}
