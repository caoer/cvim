# Diagnostics presentation.
#
# Diagnostics are not an LSP-only surface — linters publish into the same
# namespace — so this configures `vim.diagnostic` globally rather than per
# client, and stays useful on a buffer no language server ever attached to.
#
# The display policy is one idea: severity filters what is shown AT A DISTANCE,
# never what exists. End-of-line text carries warnings and errors only, the
# cursor line carries everything, and navigation reaches every severity. Nothing
# is hidden, only deferred to a cheaper glance.
{ config, lib, ... }:
let
  cfg = config.cvim.lsp;
in
{
  config = lib.mkIf cfg.enable {
    diagnostic.settings = {
      # Errors sort above warnings on a line that has both, so the sign column
      # and the floats lead with the worst thing rather than the first thing.
      severity_sort = true;

      # Re-linting while the user is mid-word produces diagnostics about half-
      # typed code, which then move as they finish the line.
      update_in_insert = false;

      virtual_text =
        if cfg.diagnostics.virtualText then
          {
            severity.min = "warn";
            # Name the producer only when more than one could have produced it;
            # a lone server's name on every line is noise.
            source = "if_many";
          }
        else
          false;

      virtual_lines = if cfg.diagnostics.virtualLines then { current_line = true; } else false;

      float = {
        border = "rounded";
        source = "if_many";
        header = "";
      };

      signs.text = {
        "__rawKey__vim.diagnostic.severity.ERROR" = "";
        "__rawKey__vim.diagnostic.severity.WARN" = "";
        "__rawKey__vim.diagnostic.severity.INFO" = "";
        "__rawKey__vim.diagnostic.severity.HINT" = "󰌵";
      };
    };
  };
}
