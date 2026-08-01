# `cvim.lang.toml` — TOML.
#
# Implements `cvim.lang.toml`, declared in `../options/lang.nix`. This module
# reads that block and nothing else.
#
# One tool, both jobs: `taplo` is the language server AND the conform
# formatter, one binary, so the bashls/shfmt two-owners problem cannot arise —
# conform owns the deliberate `<leader>F` format, and even if the LSP path
# formatted, it would run the same binary with the same defaults.
#
# ## Editor-surface states
#
# - **empty** — a `.toml` buffer outside any project: taplo attaches in
#   single-file mode; formatting and syntax diagnostics work on that file
#   alone.
# - **partial** — `toolchain = "devshell"` inside a devshell that carries
#   `taplo`: everything works, from the devshell's copy.
# - **error** — a file that does not parse: taplo reports the parse error at
#   the offending span, and a format attempt leaves the buffer untouched
#   (conform's contract — a failed formatter never writes).
#
# ## Hostile-defaults review
#
# `taplo` (in nixpkgs, not vendored) is a one-shot process under conform and a
# single-file analyzer as a server; no workspace walk on attach. Its VSCode
# frontend fetches schema catalogs from schemastore.org, but the bare LSP as
# nixvim ships it is not configured with any catalog here — no schema key is
# set in this module, and none appears in the generated init.lua. No
# telemetry, no auto-update, no auto-save.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang.toml;

  enabled = config.cvim.lang.enable && cfg.enable;

  # The check `../options/lang.nix` delegates down here, because `formatters`
  # is `str`: an unknown name throws instead of evaluating clean and doing
  # nothing.
  pick =
    what: table: name:
    table.${name} or (throw ''
      cvim.lang.toml.${what}: "${name}" is not a name this module knows.
      Known ${what}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      Add it to the map in modules/lang/toml.nix, or drop it from the list.
    '');

  checked =
    what: table: names:
    map (name: builtins.seq (pick what table name) name) names;

  formatterPackages = {
    taplo = pkgs.taplo;
  };

  grammarPackage =
    name:
    config.plugins.treesitter.package.builtGrammars.${name} or (throw ''
      cvim.lang.toml.grammars: "${name}" is not a grammar in
      `plugins.treesitter.package.builtGrammars`. Check the spelling against
      nvim-treesitter's parser names.
    '');

  ships = cfg.toolchain != "devshell";
  devshellFirst = cfg.toolchain == "prefer-devshell";

  formatterNames = checked "formatters" formatterPackages cfg.formatters;

  toolPackages = map (pick "formatters" formatterPackages) cfg.formatters;
in
{
  config = lib.mkIf enabled {
    plugins.treesitter.grammarPackages = map grammarPackage cfg.grammars;

    lsp.servers = lib.genAttrs cfg.servers (_: {
      enable = true;
      package = lib.mkIf (!ships) null;
      packageFallback = cfg.toolchain != "closure";
    });

    plugins.conform-nvim.settings.formatters_by_ft.toml = formatterNames;

    extraPackages = lib.mkIf (ships && !devshellFirst) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && devshellFirst) toolPackages;
  };
}
