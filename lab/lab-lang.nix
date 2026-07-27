# Scratch space for the `lang` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lang/` or get deleted. Nothing here ships.
#
# ## Why this file is not empty right now — scaffolding, not candidates
#
# The `lang` modules configure plugins other units own, and those units have
# not landed. Without them a `lang` module evaluates green and does nothing at
# runtime, which is the §7 failure class this layer most needs to avoid. So the
# lab supplies the missing plumbing so behaviour can be READ OUT of a running
# editor:
#
# - `plugins.lspconfig` — U7's. Load-bearing, not cosmetic: without it
#   `vim.lsp.config[name]` is `nil` for every server, no `cmd` exists, and
#   nothing attaches. An unattached server then looks exactly like a
#   misconfigured one.
# - `plugins.conform-nvim` / `plugins.lint` — U3's. Without them
#   `formatters_by_ft` and `linters_by_ft` are attrsets nothing reads.
# - `plugins.treesitter` — U3's. Without it `grammarPackages` builds nothing.
#
# Every one of these is a scaffold for verification. None of it belongs in
# `modules/lang/*`, and a claim verified here is a claim verified under a
# lab-local plumbing layer — say so when reporting it.
{
  plugins = {
    lspconfig.enable = true;

    treesitter.enable = true;

    conform-nvim.enable = true;

    lint.enable = true;
  };
}
