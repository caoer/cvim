# Diagnostics — nvim-lint
#
# empty:   a filetype with no linter produces no diagnostics and no message. Silence here is correct, not a failure.
# partial: linter configured but its binary absent — nvim-lint reports the spawn failure once per write; diagnostics from other linters still land.
# error:   a linter that exits non-zero with unparseable output yields no diagnostics for that pass; the buffer is never modified either way.
#
# nixvim wires the trigger itself (`BufWritePost` → `require('lint').try_lint()`),
# so this module configures WHAT runs, not WHEN.
#
# §6 ROW 12, FIRST HALF — markdown carries no linters.
#
# Read the mechanism here carefully, because the obvious spelling of it does
# not work. `lintersByFt.markdown = [ ]` is the natural way to write "markdown
# has no linters", it evaluates clean, `nix eval` confirms the empty list is
# present — AND IT NEVER REACHES LUA. nixvim's toLuaObject drops empty values,
# so the key is simply absent from the generated init.lua. An empty value in
# nixvim is not a value, it is an absence.
#
# Two things follow, and they point in opposite directions:
#
#   1. The hazard is smaller than it looks. nvim-lint's own default is
#      `M.linters_by_ft = {}` (lua/lint.lua:39) — genuinely empty. vale.lua and
#      markdownlint.lua are linter DEFINITIONS, available when named, not
#      defaults. So there is no upstream markdown default to fight, and nothing
#      is currently misfiring.
#   2. The guarantee still has to be real. "Nothing enables markdown linters
#      today" is a fact about the present, not a guarantee — and row 12 is a
#      guarantee. The lang layer cannot provide it either: when
#      `cvim.lang.enable = false` that layer emits nothing by construction, so
#      a guard living there disappears exactly when it is still needed.
#
# So the guard lives with the plugin that carries the default, and it is
# written as literal Lua in `luaConfig.post` rather than as a settings value.
# Literal Lua is emitted verbatim — it cannot be pruned, it runs immediately
# after the plugin's own config, and it holds regardless of what the lang layer
# does or whether it is enabled at all.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.lint = {
      enable = true;

      # §6 row 12, second half. yamllint's line-length rule fires "line too
      # long (N > 80 characters)" on every long YAML line, which is noise for
      # config and secret files that legitimately carry long values. Disabling
      # that ONE rule inline keeps the rest of yamllint — indentation, trailing
      # whitespace, syntax errors — which is the part worth having.
      linters.yamllint.args = [
        "--format"
        "parsable"
        "-d"
        "{extends: default, rules: {line-length: disable}}"
        "-"
      ];

      luaConfig.post = ''
        -- §6 row 12: markdown carries no linters, stated in Lua because an
        -- empty list on the Nix side would be dropped in translation and
        -- guarantee nothing. Survives `cvim.lang.enable = false`.
        require("lint").linters_by_ft.markdown = {}
      '';
    };
  };
}
