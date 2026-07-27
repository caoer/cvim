# Scratch space for the `lang` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lang/` or get deleted. Nothing here ships.
#
# CURRENT CONTENTS ARE NOT CANDIDATES — they are SCAFFOLDING, and the list is
# deliberately as short as it can be.
#
# `plugins.lspconfig` used to be scaffolded here. It is not any more: U7 landed
# and `modules/lsp/servers.nix` enables it in the shipped configuration, so
# **server attach is now verified against the real build rather than against
# scaffolding**. That distinction is the whole reason this file documents
# itself — a claim proven against scaffolding you later delete is a claim about
# a different configuration.
#
# What remains belongs to U3 (editing core), which has not landed yet. Until it
# does, the `lang` layer's grammars, formatters and linters are configured and
# inert in the shipped build: treesitter, conform and nvim-lint are simply not
# enabled, so nothing consumes the entries the language modules contribute.
#
# `plugins.lz-n` is the exception worth naming: `modules/lang/typescript.nix`
# ASSERTS on it, because without a lazy provider typescript-tools becomes a
# start plugin and §6 row 2 (ENFILE → V8 OOM → SIGBUS) returns. The assertion
# fails the build rather than letting that ship, so this line is what keeps the
# lab buildable — not what makes the guard true.
{
  # U3's, scaffolded here until the editing core lands.
  plugins.treesitter.enable = true;
  plugins.conform-nvim.enable = true;
  plugins.lint.enable = true;
  plugins.lz-n.enable = true;
}
