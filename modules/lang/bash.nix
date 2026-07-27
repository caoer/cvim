# `cvim.lang.bash` — Bash and POSIX shell.
#
# Implements `cvim.lang.bash`, declared in `../options/lang.nix`. This module
# reads that block and nothing else.
#
# ## Why shellcheck and shfmt are named rather than assumed
#
# `conform` and `nvim-lint` both default `autoInstall` to **false**, so a tool
# that is not in `formatters`/`linters` is a tool that does not exist — not one
# fetched on demand. Both lists are therefore explicit, and both names resolve
# to a package in the maps below.
#
# `bashls` is the third tool, and it overlaps both: bash-language-server shells
# out to `shellcheck` whenever it finds one on `$PATH`, and can format through
# `shfmt` on its own. cvim gives each job one owner:
#
# - **diagnostics** — `shellcheck`, reached through `bashls` (live, no write
#   needed) rather than through nvim-lint. The `shellcheck` binary still has to
#   be in the closure for that to work, which is why it appears in `linters`
#   and why removing it from the list silently costs you diagnostics.
# - **formatting** — conform's `shfmt`. `bashIde.shfmt` stays off; two
#   formatters over one buffer is how a file gets rewritten twice.
#
# ## Editor-surface states
#
# - **empty** — a `.sh` buffer outside any git repo: `bashls` still attaches
#   with the buffer's directory as root, and shellcheck diagnostics appear for
#   that file alone.
# - **partial** — `bashls` attached but no `shellcheck` on `$PATH` (only
#   reachable with `toolchain = "devshell"`): the server attaches, completion
#   and symbols work, and diagnostics are simply empty. Nothing announces this,
#   which is why `shellcheck` ships in the closure by default.
# - **error** — `toolchain = "devshell"` outside a devshell: nothing attaches,
#   `cvim.lsp.status()` reports `missing` with `package = false`, and a format
#   attempt reports conform's "no formatter found".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang.bash;

  enabled = config.cvim.lang.enable && cfg.enable;

  # The check `../options/lang.nix` delegates down here, because `formatters`
  # and `linters` are `str`: an unknown name throws instead of evaluating clean
  # and doing nothing.
  pick =
    what: table: name:
    table.${name} or (throw ''
      cvim.lang.bash.${what}: "${name}" is not a name this module knows.
      Known ${what}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      Add it to the map in modules/lang/bash.nix, or drop it from the list.
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
    shfmt = pkgs.shfmt;
  };

  linterPackages = {
    shellcheck = pkgs.shellcheck;
  };

  grammarPackage =
    name:
    config.plugins.treesitter.package.builtGrammars.${name}
      or (throw ''
        cvim.lang.bash.grammars: "${name}" is not a grammar in
        `plugins.treesitter.package.builtGrammars`. Check the spelling against
        nvim-treesitter's parser names.
      '');

  ships = cfg.toolchain != "devshell";
  devshellFirst = cfg.toolchain == "prefer-devshell";

  # `sh` is what neovim gives `.sh` and shebang scripts; `bash` is what it gives
  # `.bash`. bashls covers both, so both get the same tools.
  filetypes = [
    "sh"
    "bash"
  ];

  formatterNames = checked "formatters" formatterPackages cfg.formatters;
  linterNames = checked "linters" linterPackages cfg.linters;

  # Same rule as `python.nix`: a linter a configured server already publishes
  # stays in `linters` (that is what puts its binary in the closure) and is kept
  # out of `linters_by_ft`. `bashls` is the server that shells out to
  # shellcheck, so the subtraction is derived from `servers` — drop `bashls` and
  # nvim-lint takes the job back.
  serverOwnedLinters = lib.optionals (builtins.elem "bashls" cfg.servers) [ "shellcheck" ];

  toolPackages =
    map (pick "formatters" formatterPackages) cfg.formatters
    ++ map (pick "linters" linterPackages) cfg.linters;

  # Freeform surface (plan §7): a typo here builds clean and no-ops. Read back
  # out of a running client, never trusted from eval.
  serverConfig = {
    bashls.config.settings.bashIde = {
      # HOSTILE DEFAULT. bash-language-server background-analyses every file
      # matching its glob under the workspace root at attach time. Open one
      # stray `.sh` in a directory with no git root and the root becomes that
      # directory — in `$HOME` that is the fff-class incident again (§6 row 1).
      # Upstream's cap is 500 files; cvim sets a bound it can state.
      backgroundAnalysisMaxFiles = 500;

      # Formatting belongs to conform (see the header). Leaving this on gives
      # the buffer two formatters that disagree about flags.
      shfmt.path = "";
    };
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

    # nvim-lint stays out of shell: `bashls` already runs shellcheck and
    # publishes it as LSP diagnostics. The list still names `shellcheck`,
    # because that is what puts the binary the server needs into the closure.
    plugins.lint.lintersByFt = lib.genAttrs filetypes (
      _: lib.subtractLists serverOwnedLinters linterNames
    );

    extraPackages = lib.mkIf (ships && !devshellFirst) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && devshellFirst) toolPackages;
  };
}
