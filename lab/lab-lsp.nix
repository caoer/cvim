# Scratch space for the `lsp` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lsp/` or get deleted. Nothing here ships.
#
# CURRENT TRIAL — probe: can `vim.lsp.config[name].filetypes` be resolved at
# runtime once `plugins.lspconfig` is enabled? The expected-servers producer
# depends on it entirely, so it gets proven before anything is built on it.
{
  plugins.lspconfig.enable = true;
}
