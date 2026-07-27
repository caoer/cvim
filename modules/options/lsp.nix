# `cvim.lsp` — The language-server core.
{ lib, ... }:
{
  options.cvim.lsp = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        The language-server core: server wiring, diagnostics presentation, and
        the LSP keymaps.

        Individual servers live in `lang`; this area is the plumbing they attach
        to. Turning this off is a real configuration, not a degenerate one — the
        editor keeps working, no LSP keymap binds, and
        `require("cvim.lsp")` is absent rather than broken.
      '';
    };

    inlayHints = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = ''
        Show inlay hints (inferred types, parameter names) as virtual text
        wherever a server provides them.

        Off by default because hints shift the visual width of every line that
        has one, which is a large change to make on a user's behalf. `<leader>lh`
        toggles them per buffer at runtime regardless of this setting.
      '';
    };

    lightbulb = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Mark lines where a language server offers a code action, with a sign in
        the sign column.

        The marker is advisory: `gra` runs the code action whether or not the
        sign is showing.
      '';
    };

    diagnostics = {
      virtualText = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = false;
        description = ''
          Append a short diagnostic message to the end of any line that has one,
          filtered to warnings and errors.

          Hints and information never appear here — they would fire on almost
          every line in some languages. `virtualLines` shows every severity for
          the line the cursor is on, so nothing is hidden, only deferred.
        '';
      };

      virtualLines = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = false;
        description = ''
          Show the full diagnostic text, all severities, on the line the cursor
          currently occupies.

          This is what makes `virtualText`'s severity filter safe: the truncated
          end-of-line form is a summary, and moving onto the line gives you the
          whole message without a keypress.
        '';
      };
    };
  };
}
