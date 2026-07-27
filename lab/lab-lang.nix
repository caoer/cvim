# Scratch space for the `lang` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lang/` or get deleted. Nothing here ships.
#
# ## This file is empty again, and that is a result rather than a tidy-up
#
# Through most of the `lang` work it scaffolded three things the language
# modules configure but do not own, so that behaviour could be read out of a
# running editor instead of inferred from a green eval:
#
# - `plugins.lspconfig` — the `lsp` layer's. Removed when U7 landed.
# - `plugins.treesitter`, `plugins.conform-nvim`, `plugins.lint` — the editing
#   core's. Removed now that it has landed.
# - `plugins.lz-n` — the lazy-loading provider. Removed when D10a landed.
#
# Each removal moved a claim from "verified against scaffolding" to "verified
# in the shipped build", and those are claims about two different
# configurations. While this file supplied a plugin, any behaviour resting on
# it was a `.#lab` claim and had to be reported as one — a claim proven against
# scaffolding you later delete says nothing about what ships.
#
# With the file empty, the `lang` layer's grammars, formatters and linters are
# consumed by real modules in `.#default`, so there is nothing left here to
# prop up.
{ }
