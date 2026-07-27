# Scratch space for the `lsp` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/lsp/` or get deleted. Nothing here ships.
#
# The expected-servers producer was proven here against four stubbed servers
# (nixd -> ok, lua_ls + emmylua_ls -> partial, taplo -> missing, markdown ->
# none) plus a scratch statusline to make the four states visible. Captures are
# in the session directory as `u7-lsp-state-{none,ok,partial,missing}.ansi`.
# The stub is removed: it was evidence, not configuration, and `modules/lsp/`
# ships zero servers on purpose.
{
}
