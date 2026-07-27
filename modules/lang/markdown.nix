# `cvim.lang.markdown` — Markdown.
#
# Implements `cvim.lang.markdown`, declared in `../options/lang.nix`. This
# module reads that block and nothing else.
#
# ## Linters are off, and that is the setting
#
# `linters = [ ]` is plan §6 row 12, spelled directly. The incident behind it:
# a markdown linter named but never installed pops an ENOENT dialog on every
# single write. `autoInstall` is `false`, so "named" and "installed" are
# different facts, and the gap is silent until you save.
#
# **How the guarantee actually holds — measured, and not what it looks like.**
# This module sets `lintersByFt.markdown = [ ]`, and that empty list never
# reaches Lua: nixvim's `toLuaObject` drops empty attribute values, so the
# emitted table is `__lint.linters_by_ft = { }` with no `markdown` key at all.
#
# The `[ ]` is still load-bearing, just not in the way it reads. Defining
# `lintersByFt` at all makes nixvim emit that assignment, and the assignment
# REPLACES nvim-lint's own `linters_by_ft`, whose default maps `markdown` to
# `vale`. So markdown ends up unlinted because the default table was wiped, not
# because an empty list overrode one entry.
#
# The failure that follows from this, stated because it is not this module's to
# fix: with `cvim.lang.enable = false` and `plugins.lint.enable = true`, nothing
# defines `lintersByFt`, nothing is emitted, and nvim-lint's `markdown = vale`
# default comes back — §6 row 12's ENOENT incident, exactly. That belongs to
# whoever owns `plugins.lint`, and is reported rather than patched from here.
#
# cvim wires no `yamllint` here. YAML is not one of the twelve languages, and
# the other half of §6 row 12 (yamllint's line-length rule disabled) belongs to
# whoever wires yamllint, not to markdown.
#
# ## ccc_mdformat
#
# ZT's own formatter: mdformat with the canonical flags and ship-set baked in.
# It arrives as the `cccMdformat` module arg, threaded from `flake.nix`; this
# module never re-derives the package.
#
# File mode (`stdin = false` + `$FILENAME`) matches its tested in-place
# `ccc-mdformat FILE` contract. The command is the bare binary name, not a
# store path, so `toolchain` governs it like every other tool: `closure` puts
# cvim's copy first on `$PATH`, `prefer-devshell` puts it last, `devshell`
# ships nothing.
#
# ## Editor-surface states
#
# - **empty** — a `.md` buffer in a directory with no git root: measured,
#   `marksman` still attaches (`cvim.lsp.status()` reports `ok`) and indexes
#   that directory alone. No diagnostics, no error.
# - **partial** — `marksman` not attached (devshell toolchain, or a filetype
#   marksman does not claim): formatting still works, because conform runs
#   `ccc-mdformat` directly and never asks the LSP.
# - **error** — `ccc-mdformat` not on `$PATH` (only reachable with
#   `toolchain = "devshell"`): `<leader>F` reports conform's "no formatter
#   found" message. The buffer is untouched; nothing is written silently.
#   The *quiet* error is the timeout above, not this one: over `timeout_ms`,
#   conform logs to `$XDG_STATE_HOME/nvim/conform.log`, returns true, and
#   changes nothing.
{
  config,
  lib,
  cccMdformat,
  ...
}:
let
  cfg = config.cvim.lang.markdown;

  enabled = config.cvim.lang.enable && cfg.enable;

  # The check `../options/lang.nix` delegates down here, because `formatters`
  # and `linters` are `str`: an unknown name throws instead of evaluating clean
  # and formatting nothing.
  pick =
    what: table: name:
    table.${name} or (throw ''
      cvim.lang.markdown.${what}: "${name}" is not a name this module knows.
      Known ${what}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      Add it to the map in modules/lang/markdown.nix, or drop it from the list.
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
    ccc_mdformat = cccMdformat;
  };

  # Empty on purpose. §6 row 12 keeps markdown unlinted, so there is no linter
  # to map — and an empty map is what makes `linters = [ "markdownlint" ]`
  # throw with a readable message instead of shipping a name nothing installs.
  linterPackages = { };

  grammarPackage =
    name:
    config.plugins.treesitter.package.builtGrammars.${name} or (throw ''
      cvim.lang.markdown.grammars: "${name}" is not a grammar in
      `plugins.treesitter.package.builtGrammars`. Check the spelling against
      nvim-treesitter's parser names.
    '');

  ships = cfg.toolchain != "devshell";
  devshellFirst = cfg.toolchain == "prefer-devshell";

  filetypes = [ "markdown" ];

  formatterNames = checked "formatters" formatterPackages cfg.formatters;
  linterNames = checked "linters" linterPackages cfg.linters;

  # conform's default `timeout_ms` is 1000, and ccc-mdformat does not fit in it.
  # Measured inside a running editor, not from a shell: 1734 ms cold, 1109 ms
  # warm, against 13 ms for ruff_format, 11 ms for shfmt and ~80 ms for
  # prettier. It is a Python program with a plugin set to import, and it is the
  # only formatter cvim ships that is anywhere near the limit.
  #
  # Over the limit, conform logs `Formatter 'ccc_mdformat' timeout` to
  # `$XDG_STATE_HOME/nvim/conform.log`, `format()` still returns true, and the
  # buffer is untouched. So markdown silently does not format, and the return
  # value says it did. That is why this number is here and why it was found
  # only by formatting in a real editor — a headless probe that passes its own
  # generous `timeout_ms` proves the formatter works and hides that the shipped
  # path does not reach it.
  #
  # 5000 is ~3x the measured worst case. Formatting is a deliberate act, never
  # on-save, so a ceiling this high costs nothing when the tool is healthy.
  # `timeout_ms` is a per-filetype option (conform's `allowed_default_opts`),
  # which is the lever inside this module's ownership — `default_format_opts` is
  # global and belongs to the editor layer.
  timeoutMs = 5000;

  # conform's per-filetype table takes positional formatter names alongside
  # named options; nixvim spells the positional half `__unkeyed-N`.
  ftEntry =
    names:
    if names == [ ] then
      names
    else
      lib.listToAttrs (lib.imap1 (i: n: lib.nameValuePair "__unkeyed-${toString i}" n) names)
      // {
        timeout_ms = timeoutMs;
      };

  toolPackages =
    map (pick "formatters" formatterPackages) cfg.formatters
    ++ map (pick "linters" linterPackages) cfg.linters;
in
{
  config = lib.mkIf enabled {
    plugins.treesitter.grammarPackages = map grammarPackage cfg.grammars;

    # Hostile-defaults review, marksman: it indexes every markdown file under
    # the workspace root at attach time, and its root markers are
    # `.marksman.toml` then `.git`. Opening one note inside a large vault
    # indexes the vault. That is what a markdown LSP is for, so cvim does not
    # fight it — but it is why `.marksman.toml` at a subtree root is the
    # supported way to bound it, and why that is written here rather than
    # rediscovered. No settings surface of its own is set: marksman has no
    # scan/watch/poll/network options to turn down.
    lsp.servers = lib.genAttrs cfg.servers (_: {
      enable = true;
      package = lib.mkIf (!ships) null;
      packageFallback = cfg.toolchain != "closure";
    });

    plugins.conform-nvim.settings = {
      formatters_by_ft = lib.genAttrs filetypes (_: ftEntry formatterNames);

      # Only defined when the name is actually in use, so a build that drops
      # `ccc_mdformat` from `formatters` does not carry a dangling definition.
      formatters = lib.mkIf (builtins.elem "ccc_mdformat" cfg.formatters) {
        ccc_mdformat = {
          command = cccMdformat.meta.mainProgram;
          args = [ "$FILENAME" ];
          stdin = false;
        };
      };
    };

    # Empty, and it serializes to nothing — see the header. What it buys is the
    # emitted `__lint.linters_by_ft` assignment, which is what wipes nvim-lint's
    # `markdown = vale` default.
    plugins.lint.lintersByFt = lib.genAttrs filetypes (_: linterNames);

    extraPackages = lib.mkIf (ships && !devshellFirst) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && devshellFirst) toolPackages;
  };
}
