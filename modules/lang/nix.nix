# `lang/nix` — Nix.
#
# Ships the `nix` grammar, one of two servers, `nixfmt`, and `statix`.
#
# ## Two servers, selected by profile — not both at once
#
# The choice lives in `options/lang.nix` as the default of
# `cvim.lang.nix.servers`, and it is the only language whose server follows the
# profile. Measured closures, per system, because the ratio is not the same on
# both and the server profile does not ship to the machine it was measured on:
#
# | server   | aarch64-darwin | x86_64-linux |
# |----------|----------------|--------------|
# | `nixd`   | 538.1 MB       | 730.8 MB     |
# | `nil_ls` |  87.9 MB       |  85.9 MB     |
#
# So `nixd` on a workstation, where evaluating real nixpkgs expressions is the
# point, and `nil_ls` on a server, where 645 MB of LLVM buys a box that reads
# Nix occasionally nothing at all.
#
# Enabling both at once is legal and deliberately not blocked — two servers on
# one buffer is a real thing to want while comparing them. It is simply not the
# default in either profile.
#
# ## Editor-surface states
#
# - empty   — a `.nix` file outside any flake: the server attaches and offers
#             completion from its own nixpkgs handle. `nixd` without a
#             configured expression cannot resolve `pkgs.*` and says so in the
#             hover rather than returning wrong answers.
# - partial — `nil_ls` attached where `nixd` was expected (a server-profile
#             build): diagnostics and formatting work, evaluation-aware
#             completion does not. Distinguishable by client name.
# - error   — a file that does not parse: the server reports the parse error as
#             a diagnostic at the offending span and keeps the previous
#             successful analysis for the rest of the buffer.
#
# ## Hostile-defaults review
#
# `nixd` (nix-community, in nixpkgs, not vendored) evaluates Nix to answer
# completion, which is its purpose; it is bounded by the expression it is
# pointed at and does no home-directory walk. `nil` (oxalica, in nixpkgs) is a
# pure-parse server with no evaluation. Grepping both settings surfaces for the
# scan/watch/poll/index/network/telemetry class returns nothing enabled by
# default in either. `statix` and `nixfmt` are one-shot processes on the
# current buffer. No telemetry, no auto-update, no auto-save.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.nix;

  # Name → package. `formatters`/`linters` are `str` in the option surface, so
  # an unknown name has to throw here or it silently formats nothing.
  formatterPackages = {
    nixfmt = pkgs.nixfmt-rfc-style;
  };
  linterPackages = {
    statix = pkgs.statix;
    deadnix = pkgs.deadnix;
  };

  lookup =
    what: table: name:
    table.${name}
      or (throw "cvim.lang.nix.${what}: unknown name '${name}'. Known: ${lib.concatStringsSep ", " (lib.attrNames table)}");

  toolPackages = lib.unique (
    map (lookup "formatters" formatterPackages) lang.formatters
    ++ map (lookup "linters" linterPackages) lang.linters
  );

  shipsBinaries = lang.toolchain != "devshell";
  devshellWins = lang.toolchain == "prefer-devshell";

  serverPackages = {
    nixd = pkgs.nixd;
    nil_ls = pkgs.nil;
  };

  mkServer = name: {
    ${name} = {
      enable = true;
      package = if shipsBinaries then serverPackages.${name} else null;
      packageFallback = lang.toolchain != "closure";
    };
  };
in
{
  config = lib.mkIf (cfg.enable && lang.enable) (
    lib.mkMerge [
      {
        plugins.treesitter.grammarPackages = map (
          g: config.plugins.treesitter.package.builtGrammars.${g}
        ) lang.grammars;

        plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) {
          nix = lang.formatters;
        };

        plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) {
          nix = lang.linters;
        };
      }

      # Both attributes are defined unconditionally, with the unused one
      # empty. Choosing the attribute NAME with an `if` instead makes this
      # module's shape depend on `config`, and nixvim's top level is freeform —
      # that is an infinite recursion, not a style preference.
      {
        extraPackages = lib.optionals (shipsBinaries && !devshellWins) toolPackages;
        extraPackagesAfter = lib.optionals (shipsBinaries && devshellWins) toolPackages;
      }

      { lsp.servers = lib.mkMerge (map mkServer lang.servers); }
    ]
  );
}
