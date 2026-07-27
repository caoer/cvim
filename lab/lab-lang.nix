# Scratch space for the `lang` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lang/` or get deleted. Nothing here ships.
#
# CURRENT CONTENTS ARE NOT CANDIDATES — they are SCAFFOLDING.
#
# The `lang` layer contributes entries into plugins owned by two other units:
# treesitter/conform/lint belong to U3 (editing core) and `plugins.lspconfig`
# belongs to U7 (LSP core). Neither has landed on this branch yet, so on the
# shipped `default` build those contributions are inert — the grammars, the
# `formatters_by_ft` entries and the servers are all configured and nothing
# turns them on.
#
# That matters for how any result from this build is read: **attach and format
# verified here are verified under lab scaffolding, not under the shipped
# module.** The two become the same claim only once U3 and U7 land, and this
# file gets emptied at that point.
#
# `plugins.lspconfig` specifically is load-bearing rather than cosmetic:
# `vim.lsp.config[name].filetypes` is `nil` for every name without it, so
# nothing resolves a filetype to a server and nothing attaches at all.
{
  # U3's, scaffolded here.
  plugins.treesitter.enable = true;
  plugins.conform-nvim.enable = true;
  plugins.lint.enable = true;
  # A lazy provider. `modules/lang/typescript.nix` asserts on this, because
  # without it typescript-tools becomes a start plugin and §6 row 2 returns.
  plugins.lz-n.enable = true;

  # U7's, scaffolded here.
  plugins.lspconfig.enable = true;
}
