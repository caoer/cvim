# `cvim.lsp` — The language-server core.
{ lib, ... }:
{
  options.cvim.lsp.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      The language-server core: server wiring, diagnostics presentation, and
      the LSP keymaps.

      Individual servers live in `lang`; this area is the plumbing they attach
      to.
    '';
  };
}
