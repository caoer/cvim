# `lang/go` — Go.
#
# Ships the `go`/`gomod`/`gosum`/`gowork` grammars, `gopls`, and `gofmt`.
#
# ## `vulncheck = "Off"` is the whole reason this file has a settings block
#
# gopls ≥0.22 defaults `vulncheck` to `"Prompt"`. On every `go.mod` dependency
# change it sends a `window/showMessageRequest`, which nvim routes to a
# `vim.ui.select` picker; a redraw dismisses the picker before it can be
# answered, so gopls re-sends it on the next analysis cycle. That is the ~1s
# flicker loop of §6 row 4.
#
# `config` is the table handed to `vim.lsp.config("gopls", …)` and gopls reads
# its own options out of a `"gopls"` section, hence `settings.gopls.vulncheck`.
# That whole path is **freeform**: misspell any segment and the build is green,
# the option silently absent, and the flicker back. It is verified by reading
# the value out of a running editor, never from this file.
#
# ## Editor-surface states
#
# - empty   — no `go.mod`: gopls still attaches, single-file mode, no module
#             diagnostics. Not an error state and not signalled as one.
# - partial — gopls binary missing (outside a devshell under
#             `toolchain = "devshell"`): the buffer opens, highlighting works,
#             and the expected-servers signal reports `missing` with
#             `fallback = true`. That reads as "you are outside the devshell".
# - error   — a `go.mod` that does not parse: gopls attaches and reports the
#             parse failure as a diagnostic on the offending line. The editor
#             stays usable; nothing is silently swallowed.
#
# ## Hostile-defaults review
#
# gopls, nixpkgs `gopls` 0.23.0 — upstream `golang/tools`, the Go team's own
# server, in nixpkgs, not vendored, so no pinned `rev`/`hash` is needed.
# Grepping its settings surface for the scan/watch/index/network class returns
# exactly one live default worth acting on, and it is the one disabled above:
# `vulncheck` reaches the network to query the vulnerability database.
# `gopls` does index the module it is invoked on, which is its purpose and is
# bounded by the module rather than by `$HOME` — this is not the fff class.
# No telemetry, no auto-save, no auto-update.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.go;

  # Name → package. This map is the contract that keeps `formatters` and
  # `linters` honest: they are `str` in the option surface, so an unknown name
  # has to throw HERE or it silently formats nothing.
  formatterPackages = {
    # `gofmt` ships inside the Go toolchain rather than as its own derivation.
    gofmt = pkgs.go;
  };
  linterPackages = { };

  lookup =
    what: table: name:
    table.${name}
      or (throw "cvim.lang.go.${what}: unknown name '${name}'. Known: ${lib.concatStringsSep ", " (lib.attrNames table)}");

  toolPackages = lib.unique (
    map (lookup "formatters" formatterPackages) lang.formatters
    ++ map (lookup "linters" linterPackages) lang.linters
  );

  # `toolchain` decides who supplies the binaries; see `options/lang.nix`.
  shipsBinaries = lang.toolchain != "devshell";
  devshellWins = lang.toolchain == "prefer-devshell";
in
{
  config = lib.mkIf (cfg.enable && lang.enable) (
    lib.mkMerge [
      {
        plugins.treesitter.grammarPackages = map (
          g: config.plugins.treesitter.package.builtGrammars.${g}
        ) lang.grammars;

        plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) {
          go = lang.formatters;
        };

        plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) {
          go = lang.linters;
        };
      }

      # Toolchain binaries for formatters/linters. The server's own binary is
      # handled by `lsp.servers.<name>.package`, which does its own PATH
      # ordering, so it is deliberately not repeated here.
      # Both attributes are defined unconditionally, with the unused one
      # empty. Choosing the attribute NAME with an `if` instead makes this
      # module's shape depend on `config`, and nixvim's top level is freeform —
      # that is an infinite recursion, not a style preference.
      {
        extraPackages = lib.optionals (shipsBinaries && !devshellWins) toolPackages;
        extraPackagesAfter = lib.optionals (shipsBinaries && devshellWins) toolPackages;
      }

      (lib.mkIf (lib.elem "gopls" lang.servers) {
        lsp.servers.gopls = {
          enable = true;
          package = if shipsBinaries then pkgs.gopls else null;
          packageFallback = lang.toolchain != "closure";
          # Freeform from here down — verified in a running editor, not here.
          config.settings.gopls.vulncheck = "Off";
        };
      })
    ]
  );
}
