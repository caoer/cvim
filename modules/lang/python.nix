# `cvim.lang.python` — Python.
#
# Implements `cvim.lang.python`, declared in `../options/lang.nix`. This module
# reads that block and nothing else.
#
# ## ruff is one binary wearing three hats — this module picks one per hat
#
# `ruff` can be an LSP server, a formatter and a linter, and the temptation is
# to wire all three. Doing so double-reports, measured in a running editor
# rather than reasoned about: with the ruff server attached, three findings;
# with nvim-lint's `ruff` fired as well, the same three arrive a second time,
# `Ruff|F401|L0` alongside `ruff|F401|L0`, in a separate namespace.
#
# The split cvim ships:
#
# - **diagnostics** — the `ruff` LSP server. Live as you type, no write needed.
# - **formatting** — conform's `ruff_format`, driven by the same `ruff` binary.
#   Conform rather than the server because `<leader>F` must work in the async
#   window before any server has attached, and because conform is where the
#   whole distro's formatting lives.
# - **types** — `basedpyright`, which ruff does not do at all.
#
# `linters` still NAMES ruff, because that is what puts the binary in the
# closure, and the module withholds it from `linters_by_ft` for exactly as long
# as the ruff server is enabled. Take the server out of `servers` and nvim-lint
# picks the job back up. One tool, one job, decided from the configuration
# rather than restated in two places.
#
# basedpyright then re-reports two of ruff's rules under its own names
# (`reportUnusedImport` = F401, `reportUnusedVariable` = F841 — also measured,
# three sources on one line). Those two are turned off below; every other
# basedpyright rule is kept, because ruff does not do type inference.
#
# ## Editor-surface states
#
# - **empty** — a `.py` buffer in a directory with no git root and no project
#   file: measured, **both** servers still attach and `cvim.lsp.status()`
#   reports `ok`. Diagnostics are whatever ruff finds in the single file.
# - **partial** — reached in normal use as a TRANSIENT: ruff attaches in well
#   under a second and basedpyright takes noticeably longer, so a freshly opened
#   buffer legitimately reports `partial` for a moment. It settles to `ok`. The
#   U7 contract states this async window; this module does not smooth it over,
#   and a probe that stops waiting at the first client will report it as a
#   permanent `partial` (measured — that false negative is the instrument's,
#   not the config's).
# - **error** — `toolchain = "devshell"` outside a devshell: no binary exists,
#   nothing attaches, and a format attempt reports conform's "no formatter
#   found" message. Loud, not silent.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang.python;

  # Both gates. `cvim.lang.enable` is the area; `cvim.lang.python.enable` is
  # the language. A `server` build has to turn both back on.
  enabled = config.cvim.lang.enable && cfg.enable;

  # `../options/lang.nix` closes the server name (enum) and deliberately leaves
  # `grammars`/`formatters`/`linters` as `str`, delegating the check here. This
  # map IS that check: an unknown name throws with the list of known ones
  # instead of evaluating clean and formatting nothing.
  pick =
    what: table: name:
    table.${name} or (throw ''
      cvim.lang.python.${what}: "${name}" is not a name this module knows.
      Known ${what}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      Add it to the map in modules/lang/python.nix, or drop it from the list.
    '');

  # The names that reach Lua, each one forced through `pick` first. `seq` is
  # what keeps the check on the SAME evaluation path as the value it guards:
  # resolving packages only for `extraPackages` leaves `toolchain = "devshell"`
  # with no force point at all, and a typo then evaluates clean, builds clean
  # and formats nothing — the exact hole this map exists to close, one layer
  # lower. Measured, not assumed.
  checked =
    what: table: names:
    map (name: builtins.seq (pick what table name) name) names;

  formatterPackages = {
    ruff_format = pkgs.ruff;
    ruff_fix = pkgs.ruff;
    ruff_organize_imports = pkgs.ruff;
    black = pkgs.black;
    isort = pkgs.isort;
  };

  linterPackages = {
    ruff = pkgs.ruff;
    mypy = pkgs.mypy;
    pylint = pkgs.pylint;
  };

  # Grammars resolve against the treesitter package the `editor` layer chose,
  # never `pkgs.vimPlugins.nvim-treesitter.*` — mixing the two pulls parsers
  # whose query files do not match the plugin.
  grammarPackage =
    name:
    config.plugins.treesitter.package.builtGrammars.${name}
      or (throw ''
        cvim.lang.python.grammars: "${name}" is not a grammar in
        `plugins.treesitter.package.builtGrammars`. Check the spelling against
        nvim-treesitter's parser names.
      '');

  # `toolchain`, spelled once for servers and tools alike.
  ships = cfg.toolchain != "devshell";
  devshellFirst = cfg.toolchain == "prefer-devshell";

  filetypes = [ "python" ];

  formatterNames = checked "formatters" formatterPackages cfg.formatters;
  linterNames = checked "linters" linterPackages cfg.linters;

  # A linter whose findings a configured server already publishes is kept in
  # `linters` — that is what puts its binary in the closure — and withheld from
  # `linters_by_ft`, because running it again reports every finding twice.
  # Derived from `servers`, not hardcoded: turn the ruff server off and
  # nvim-lint picks the job back up.
  serverOwnedLinters = lib.intersectLists [ "ruff" ] cfg.servers;

  toolPackages =
    map (pick "formatters" formatterPackages) cfg.formatters
    ++ map (pick "linters" linterPackages) cfg.linters;

  # `lsp.servers.<name>.config` is freeform: a typo here evaluates clean, builds
  # clean and no-ops at runtime (plan §7). Everything set below is therefore
  # read back out of a running editor, never trusted from eval.
  serverConfig = {
    # Hostile-defaults review, basedpyright: `diagnosticMode` decides whether it
    # type-checks the open file or crawls the whole workspace. Upstream already
    # defaults to `openFilesOnly`; cvim states it rather than inheriting it,
    # because the value that bites is one word away and silent.
    basedpyright.config.settings.basedpyright.analysis = {
      diagnosticMode = "openFilesOnly";

      # The two rules ruff already owns, silenced on the basedpyright side only
      # while the ruff server is the one reporting them. Without this, one
      # unused import is three diagnostics on one line. Plain `optionalAttrs`
      # rather than `mkIf`: this sits inside a freeform `attrsOf anything` that
      # is handed to `toLuaObject`, and a stray `mkIf` marker there would be
      # serialized rather than resolved.
      diagnosticSeverityOverrides = lib.optionalAttrs (builtins.elem "ruff" cfg.servers) {
        reportUnusedImport = "none";
        reportUnusedVariable = "none";
      };
    };
    pyright.config.settings.python.analysis.diagnosticMode = "openFilesOnly";
  };
in
{
  config = lib.mkIf enabled {
    plugins.treesitter.grammarPackages = map grammarPackage cfg.grammars;

    lsp.servers = lib.genAttrs cfg.servers (
      name:
      lib.recursiveUpdate {
        enable = true;
        # `null` only in the `devshell` case; otherwise the declared default
        # package stands, so this module never restates a package name nixvim
        # already knows.
        package = lib.mkIf (!ships) null;
        packageFallback = devshellFirst;
      } (serverConfig.${name} or { })
    );

    # Set even when the list is empty. Note that an empty list does NOT survive
    # into Lua — nixvim's `toLuaObject` drops empty attribute values — so `[ ]`
    # leaves the filetype out of the emitted table rather than mapping it to
    # nothing. Same end state here, different mechanism, and the difference
    # matters wherever the plugin has a default of its own (see markdown.nix).
    plugins.conform-nvim.settings.formatters_by_ft = lib.genAttrs filetypes (_: formatterNames);
    plugins.lint.lintersByFt = lib.genAttrs filetypes (
      _: lib.subtractLists serverOwnedLinters linterNames
    );

    extraPackages = lib.mkIf (ships && !devshellFirst) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && devshellFirst) toolPackages;
  };
}
