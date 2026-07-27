# `cvim.lang.web` — CSS, HTML and JSON.
#
# Implements `cvim.lang.web`, declared in `../options/lang.nix`. This module
# reads that block and nothing else.
#
# ## Three servers, one package
#
# `cssls`, `html` and `jsonls` are three binaries out of a single derivation
# (`vscode-langservers-extracted`). Enabling all three costs one package, not
# three, which is why the declared default enables all three rather than making
# a choice nobody benefits from. `eslint` comes out of the same derivation;
# `tailwindcss` and `biome` do not, and both are off by default.
#
# ## Editor-surface states
#
# - **empty** — a `.css`/`.html`/`.json` buffer outside any project: the server
#   attaches with the buffer's directory as root. JSON gets syntax diagnostics
#   with no schema; CSS and HTML behave normally. No error.
# - **partial** — one of the three attached and another not (a filetype only
#   one of them claims, e.g. `jsonc`): normal. `cvim.lsp.status()` reports per
#   filetype, so this is `ok`, not `partial`, for the server that claims it.
# - **error** — `toolchain = "devshell"` outside a devshell: nothing attaches,
#   `status()` reports `missing` with `package = false`, and a format attempt
#   reports conform's "no formatter found".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang.web;

  enabled = config.cvim.lang.enable && cfg.enable;

  # The check `../options/lang.nix` delegates down here, because `formatters`
  # and `linters` are `str`: an unknown name throws instead of evaluating clean
  # and formatting nothing.
  pick =
    what: table: name:
    table.${name} or (throw ''
      cvim.lang.web.${what}: "${name}" is not a name this module knows.
      Known ${what}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      Add it to the map in modules/lang/web.nix, or drop it from the list.
    '');

  # The names that reach Lua, each one forced through `pick` first. `seq` is
  # what keeps the check on the SAME evaluation path as the value it guards:
  # resolving packages only for `extraPackages` leaves `toolchain = "devshell"`
  # with no force point at all, and a typo then evaluates clean, builds clean
  # and formats nothing.
  checked =
    what: table: names:
    map (name: builtins.seq (pick what table name) name) names;

  formatterPackages = {
    prettier = pkgs.prettier;
    prettierd = pkgs.prettierd;
    biome = pkgs.biome;
  };

  linterPackages = {
    stylelint = pkgs.stylelint;
    eslint_d = pkgs.eslint_d;
  };

  grammarPackage =
    name:
    config.plugins.treesitter.package.builtGrammars.${name}
      or (throw ''
        cvim.lang.web.grammars: "${name}" is not a grammar in
        `plugins.treesitter.package.builtGrammars`. Check the spelling against
        nvim-treesitter's parser names.
      '');

  ships = cfg.toolchain != "devshell";
  devshellFirst = cfg.toolchain == "prefer-devshell";

  # What the three default servers claim between them: cssls takes the three
  # stylesheet dialects, html takes html, jsonls takes json and jsonc.
  filetypes = [
    "css"
    "scss"
    "less"
    "html"
    "json"
    "jsonc"
  ];

  formatterNames = checked "formatters" formatterPackages cfg.formatters;
  linterNames = checked "linters" linterPackages cfg.linters;

  toolPackages =
    map (pick "formatters" formatterPackages) cfg.formatters
    ++ map (pick "linters" linterPackages) cfg.linters;

  # Freeform surface (plan §7): typos build clean and no-op. Read back out of a
  # running client, never trusted from eval.
  serverConfig = {
    # Hostile-defaults review, jsonls: the one server here with a network
    # story. vscode-json-language-server resolves remote `$schema` URLs by
    # asking the CLIENT for the content (a `vscode/content` request), it does
    # not fetch them itself. cvim implements no such handler, so no schema is
    # downloaded and no request leaves the editor. That is a property of the
    # client, not a setting, so it is asserted at runtime rather than declared
    # here — see the module's verification notes.
    jsonls.config.settings.json.validate.enable = true;

    # Hostile-defaults review, tailwindcss (off by default): it walks the
    # project for class usage and watches for changes. Turning it on is a scan
    # decision, not a convenience one.
    tailwindcss = { };
    # Hostile-defaults review, eslint (off by default): it executes the
    # PROJECT'S eslint config, which is arbitrary JavaScript from the repo you
    # opened. Same class as any plugin-from-a-repo hazard.
    eslint = { };
    biome = { };
  };
in
{
  config = lib.mkIf enabled {
    plugins.treesitter.grammarPackages = map grammarPackage cfg.grammars;

    lsp.servers = lib.genAttrs cfg.servers (
      name:
      lib.recursiveUpdate {
        enable = true;
        package = lib.mkIf (!ships) null;
        packageFallback = devshellFirst;
      } (serverConfig.${name} or { })
    );

    plugins.conform-nvim.settings.formatters_by_ft = lib.genAttrs filetypes (_: formatterNames);
    plugins.lint.lintersByFt = lib.genAttrs filetypes (_: linterNames);

    extraPackages = lib.mkIf (ships && !devshellFirst) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && devshellFirst) toolPackages;
  };
}
