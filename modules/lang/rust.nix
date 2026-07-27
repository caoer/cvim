# `cvim.lang.rust` — rust-analyzer, the `rust` grammar, rustfmt.
#
# Off on every profile, `default` included (D4). A host asks for it back
# through `extendModules`; until one does, this file contributes nothing to any
# closure. Both gates have to be on: `cvim.lang.enable` and
# `cvim.lang.rust.enable`.
#
# ## What cvim ships here, and what it deliberately does not
#
# The editor side only: the server, the formatter, the grammar. `cargo` and
# `rustc` are not shipped and are not meant to be. rust-analyzer shells out to
# both — `cargo metadata --no-deps` to find the workspace root, `rustc --print
# sysroot` to locate the standard library sources — so in a bare directory
# outside a devshell you get a server that starts and answers almost nothing.
# That is `toolchain = "prefer-devshell"` working: the project pins its own Rust
# version and cvim never bakes one into the editor.
#
# ## Hostile defaults — what happens the moment a `.rs` buffer opens
#
# Provenance: `rust-analyzer` from nixpkgs on nixvim's pin (upstream rust-lang
# release, actively maintained); the behaviour below comes from
# nvim-lspconfig's bundled `lsp/rust_analyzer.lua`, not from cvim. No vendored
# plugin, so no `rev`/`hash` of our own to pin.
#
# On open, before a key is pressed:
#
#   - spawns `cargo metadata --no-deps` in the crate directory
#   - spawns `rustc --print sysroot` when the file sits under a registry, a git
#     checkout or a rustup toolchain
#   - indexes the entire cargo workspace *and* every dependency's sources
#   - `checkOnSave` is rust-analyzer's own default and stays on, so every write
#     runs `cargo check` and writes into the project's `target/`
#   - upstream enables the full code-lens set — run, debug, implementations,
#     references, updateTest — one extra request per visible symbol
#
# None of that is disabled here. It is what someone who turns Rust on is asking
# for, and it is exactly why the language is off by default. Every write lands
# in the project's own `target/`: never in the store, never in a shared cache.
#
# This file adds no plugin. That is a decision, not an omission: the whole
# language is one server plus two binaries, so there is nothing to defer, no
# `lazyLoad` spec to be inert while `plugins.lz-n` is off, and no `setup()` that
# could write a global the layer never declared.
#
# ## Editor-surface states
#
# empty    Off, or `servers = [ ]`: nothing attaches, `require("cvim.lsp")
#          .status()` answers `none`, and a `.rs` buffer is text plus grammar.
# partial  Needs two expected servers on one filetype; cvim configures one, so
#          this state is reachable only if a host adds a second.
# error    Two different ones, and only the first is quiet.
#
#          `rust-analyzer` missing from `$PATH` (`toolchain = "devshell"`
#          outside a devshell): nothing is drawn, no dialog opens, `status()`
#          answers `missing` rather than `none`, and the reason —
#          `rust-analyzer is not executable` — goes to
#          `vim.lsp.log.get_filename()`. Verified live.
#
#          `rustc` missing from `$PATH`: a fifteen-line Lua stack trace on
#          EVERY `.rs` buffer open, and no attach at all. This one is upstream
#          and unrelated to anything cvim sets. nvim-lspconfig's bundled
#          `lsp/rust_analyzer.lua` runs `rustc --print sysroot` from
#          `default_sysroot_src()` inside its `root_dir` resolver, through
#          `vim.system` with no `executable()` guard and no `pcall`, so the
#          ENOENT escapes into the `BufReadPost`/`FileType` autocmd chain:
#
#            ENOENT: no such file or directory (cmd): 'rustc'
#
#          Measured identically on a build that ships `rustfmt` and one that
#          does not — `pkgs.rustfmt` carries `rustfmt`, `cargo-fmt`,
#          `git-rustfmt` and `rustfmt-format-diff`, never `rustc` — so no
#          choice available to this module changes it. Shipping `rustc` to
#          silence it would cost 961 MB. Rust in cvim is a devshell language;
#          outside one it is not merely degraded, it is loud.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.rust;
  enable = cfg.enable && lang.enable;

  # ── The name → package maps ────────────────────────────────────────────
  #
  # `servers` is an enum in `../options/lang.nix`, so a wrong server name is
  # already a build error. `grammars`, `formatters` and `linters` are `str`,
  # and closing *that* hole is this file's job: every name below resolves to a
  # concrete package or throws. Without these maps `formatters = [ "rustfmtt" ]`
  # would evaluate clean and format nothing.

  # The valid grammar names are exactly what the configured nvim-treesitter can
  # build — a real map, and one that cannot go stale against the pin.
  grammarPackages = config.plugins.treesitter.package.builtGrammars;

  formatterPackages = {
    rustfmt = pkgs.rustfmt;
  };

  linterPackages = {
    clippy = pkgs.clippy;
  };

  resolve =
    option: table: name:
    table.${name} or (throw ''
      cvim.lang.rust.${option}: "${name}" is not a name modules/lang/rust.nix knows.
      Known ${option}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      A name this module cannot map to a package would configure a tool that is
      never installed, so it is refused here rather than at first use.
    '');

  # `resolve` fires when its result is *forced*, and that is not the same thing
  # as "always". `formatters` and `linters` reach `extraPackagesAfter`, which
  # the wrapper always forces, so a bad name there throws. `grammars` reach
  # `plugins.treesitter.grammarPackages`, which nothing forces while the editor
  # layer has treesitter off — so `grammars = [ "jaba" ]` evaluated perfectly
  # clean and built a derivation. Measured, not reasoned about.
  #
  # Assertions are forced by `build.package` on every build, so they do not
  # depend on anyone consuming the value. `resolve` stays as the value-path
  # guard; this is the one that always runs.
  nameAssertions =
    option: table: known: names:
    map (name: {
      assertion = table ? ${name};
      message = ''
        cvim.lang.rust.${option}: "${name}" is not a name modules/lang/rust.nix knows.
        ${known}
      '';
    }) names;

  # `toolchain` decides who supplies the binaries — the server's and the tools',
  # which move together on purpose.
  ships = lang.toolchain != "devshell";
  prefix = lang.toolchain == "closure";

  toolPackages = lib.unique (
    map (resolve "formatters" formatterPackages) lang.formatters
    ++ map (resolve "linters" linterPackages) lang.linters
  );

  # nixpkgs would throw about `rust-analyzer` on a system it does not build for;
  # this throws about the option that asked for it, and names the way out.
  packageAvailable =
    name:
    let
      p = config.lsp.servers.${name}.package;
    in
    p == null || (p.meta.available or true);
in
{
  config = lib.mkIf enable {
    assertions =
      map (name: {
        assertion = packageAvailable name;
        message = ''
          cvim.lang.rust.servers: "${name}" has no package on ${pkgs.stdenv.hostPlatform.system}.
          Set cvim.lang.rust.toolchain = "devshell" to configure it without shipping a binary.
        '';
      }) lang.servers
      ++
        nameAssertions "grammars" grammarPackages
          "Valid grammars are the parsers the configured nvim-treesitter can build."
          lang.grammars
      ++ nameAssertions "formatters" formatterPackages "Known formatters: rustfmt." lang.formatters
      ++ nameAssertions "linters" linterPackages "Known linters: clippy." lang.linters;

    lsp.servers = lib.genAttrs lang.servers (_: {
      enable = true;
      # `null` means cvim ships nothing and the server runs only from $PATH.
      package = lib.mkIf (!ships) null;
      # Suffixed onto $PATH, so a devshell's rust-analyzer — the one matching
      # the project's toolchain — wins over cvim's.
      packageFallback = !prefix;
    });

    plugins.treesitter.grammarPackages = map (resolve "grammars" grammarPackages) lang.grammars;

    # Written only when the list is non-empty, and with `mkIf` rather than
    # `optionalAttrs`. Three reasons, all pointing the same way.
    #
    # `optionalAttrs false` still DEFINES the option, as `{ }`; `mkIf false`
    # defines nothing at all. `lintersByFt` is one of nixvim's null-default
    # options, and it emits `__lint.linters_by_ft = ...` only while it is
    # non-null — so a `{ }` definition writes an empty table into the generated
    # Lua where nothing should appear. Caught by reading that file: `nix eval`
    # reports `{ }` either way, which is exactly why the evaluated config is the
    # wrong instrument for this particular claim.
    #
    # nixvim's `toLuaObject` separately DROPS empty values, so
    # `formatters_by_ft.rust = [ ]` would be present in the evaluated config and
    # absent from the generated Lua. Writing it would be a claim this module
    # cannot keep.
    #
    # Leaving the key out equals "never linted" only because nvim-lint's own
    # `M.linters_by_ft` is empty upstream — read from the plugin source for
    # `rust`, not inferred from the mechanism. Where nvim-lint does ship a
    # default for a filetype, omitting the key leaves that default live.
    plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) {
      rust = lang.formatters;
    };
    plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) { rust = lang.linters; };

    extraPackages = lib.mkIf (ships && prefix) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && !prefix) toolPackages;
  };
}
