# Formatting — conform, manual only
#
# empty:   no formatter configured for the filetype — `<leader>F` falls back to the LSP, and says so if there is none.
# partial: some formatters in the chain missing — conform runs the ones it has and reports the ones it cannot spawn.
# error:   a formatter that exits non-zero leaves the buffer untouched and surfaces its stderr; a failed format never writes a half-formatted buffer.
#
# §6 ROW 5 — format-on-save is OFF. Formatting is a deliberate act, never a
# side effect of `:w`. Silent on-save rewrites corrupt files that must stay
# byte-exact (verbatim upstream captures, faithful wiki sources, test
# fixtures), and the damage lands in a commit before anyone reads the diff.
#
# THE VALUE IS `false`, NOT `null`, AND THAT IS THE WHOLE POINT. The plan
# specifies `format_on_save = null`. Under nixvim `null` is not a value, it is
# an absence: toLuaObject drops it, `conform.setup()` receives `{}`, and
# format-on-save is off only because conform's own upstream default happens to
# be off. That is a guarantee resting on someone else's default, invisible in
# the generated Lua, and silently overridable by any later unit that sets the
# key. `false` survives translation, is greppable in the built artifact, and —
# because it is a real definition — makes a later conflicting definition a
# LOUD eval error instead of a silent override. Verified on the far side of the
# Nix→Lua boundary, in the generated init.lua, not in `nix eval`.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins.conform-nvim = {
      enable = true;
      settings = {
        format_on_save = lib.nixvim.mkRaw "false";
        format_after_save = lib.nixvim.mkRaw "false";
      };
    };

    # The manual path. `async = true` keeps a slow formatter from blocking the
    # editor, and `lsp_format = "fallback"` means a filetype with no configured
    # formatter still gets the LSP's own formatting rather than nothing.
    keymaps = [
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>F";
        action.__raw = ''
          function()
            require("conform").format({ async = true, lsp_format = "fallback" })
          end
        '';
        options = {
          desc = "Format buffer or selection (manual — format-on-save is off)";
          silent = true;
        };
      }
    ];
  };
}
