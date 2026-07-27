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
# - `plugins.conform-nvim` / `plugins.lint` — U3's. Without them
#   `formatters_by_ft` and `linters_by_ft` are attrsets nothing reads.
# - `plugins.treesitter` — U3's. Without it `grammarPackages` builds nothing.
#
# `plugins.lspconfig` was here too until U7 landed. It is gone now: the `lsp`
# layer enables it, so **attach is verified in the shipped `.#default` build**
# rather than against scaffolding. Formatting still needs this file, so a
# formatting claim is a `.#lab` claim and an attach claim is not — that
# distinction is the point of keeping the two apart.
{
  plugins = {
    treesitter.enable = true;

    conform-nvim.enable = true;

    lint.enable = true;
  };
}
