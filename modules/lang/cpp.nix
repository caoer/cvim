# `cvim.lang.cpp` — clangd, the `c` and `cpp` grammars, clang-format.
#
# Off on every profile, `default` included (D4). A host asks for it back
# through `extendModules`; until one does, this file contributes nothing to any
# closure. Both gates have to be on: `cvim.lang.enable` and
# `cvim.lang.cpp.enable`.
#
# ## One package, three tools
#
# `clang-tools` carries `clangd`, `clang-format` and `clang-tidy`. Server,
# formatter and linter therefore arrive together whichever of the three you ask
# for, and asking for all three costs no more than asking for one.
#
# A compiler is not shipped. clangd reads `compile_commands.json` — produced by
# the project's own build system — and without one it falls back to guessing
# flags per file. That is what `toolchain = "prefer-devshell"` is for: the
# project supplies the toolchain that produced the compile database, so its
# clangd wins on `$PATH` over cvim's.
#
# ## Hostile defaults — what happens the moment a `.cpp` buffer opens
#
# Provenance: `clang-tools` from nixpkgs on nixvim's pin (LLVM upstream); the
# behaviour is nvim-lspconfig's bundled `lsp/clangd.lua` plus clangd's own
# defaults. No vendored plugin, so no `rev`/`hash` of our own to pin.
#
# On open:
#
#   - clangd background-indexes the whole project. This is clangd's own default
#     (`--background-index` has been on since clangd 9) and cvim does not pass
#     the flag either way.
#   - that index is written to `.cache/clangd/index/` **inside the project
#     directory**. It is the one runtime write in this module that does not land
#     under `$XDG_STATE_HOME`, and clangd offers no flag to move it: the
#     location is compiled in. It is a project-local, regenerable cache, never a
#     store path, and it is recorded here rather than left to be discovered.
#   - `root_markers` includes `.git`, so opening a stray `.c` file inside any
#     repository indexes that whole repository.
#   - upstream's `on_attach` creates two buffer-local user commands,
#     `LspClangdSwitchSourceHeader` and `LspClangdShowSymbolInfo`. cvim binds no
#     key to either — see below.
#
# No network access, no telemetry, no watcher beyond clangd's own file
# notifications.
#
# ## No keymaps, on purpose
#
# `LspClangdSwitchSourceHeader` is the obvious candidate and it stays unbound.
# The natural spellings collide with things that already work: bare-letter and
# `g`-prefixed bindings shadow builtin motions, and every remaining use of a
# shadowed prefix then pays a `timeoutlen` wait. A language module that is off
# by default has no business spending the global keymap budget; a host that
# turns C++ on can bind the command itself.
#
# This file adds no plugin either. That is a decision, not an omission: the
# language is one server plus one package, so there is nothing to defer, no
# `lazyLoad` spec to be inert while `plugins.lz-n` is off, and no `setup()` that
# could write a global the layer never declared.
#
# ## Editor-surface states
#
# empty    Off, or `servers = [ ]`: nothing attaches, `require("cvim.lsp")
#          .status()` answers `none`, and a `.cpp` buffer is text plus grammar.
# partial  Needs two expected servers on one filetype; cvim configures one, so
#          this state is reachable only if a host adds a second.
# error    `clangd` missing from `$PATH` (`toolchain = "devshell"` outside a
#          devshell): nothing is drawn, no dialog opens, `status()` counts it
#          missing, and the reason is written to `vim.lsp.log.get_filename()`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.cpp;
  enable = cfg.enable && lang.enable;

  # ── The name → package maps ────────────────────────────────────────────
  #
  # `servers` is an enum in `../options/lang.nix`, so a wrong server name is
  # already a build error. `grammars`, `formatters` and `linters` are `str`, and
  # closing *that* hole is this file's job: every name below resolves to a
  # concrete package or throws. Without these maps `formatters =
  # [ "clang_formatt" ]` would evaluate clean and format nothing.

  # The valid grammar names are exactly what the configured nvim-treesitter can
  # build — a real map, and one that cannot go stale against the pin.
  grammarPackages = config.plugins.treesitter.package.builtGrammars;

  formatterPackages = {
    clang_format = pkgs.clang-tools;
  };

  linterPackages = {
    clangtidy = pkgs.clang-tools;
    cppcheck = pkgs.cppcheck;
  };

  resolve =
    option: table: name:
    table.${name} or (throw ''
      cvim.lang.cpp.${option}: "${name}" is not a name modules/lang/cpp.nix knows.
      Known ${option}: ${lib.concatStringsSep ", " (lib.attrNames table)}.
      A name this module cannot map to a package would configure a tool that is
      never installed, so it is refused here rather than at first use.
    '');

  # `resolve` fires when its result is *forced*, and that is not the same thing
  # as "always". `formatters` and `linters` reach `extraPackagesAfter`, which
  # the wrapper always forces, so a bad name there throws. `grammars` reach
  # `plugins.treesitter.grammarPackages`, which nothing forces while the editor
  # layer has treesitter off — so a bogus grammar name evaluated perfectly clean
  # and built a derivation. Measured, not reasoned about.
  #
  # Assertions are forced by `build.package` on every build, so they do not
  # depend on anyone consuming the value. `resolve` stays as the value-path
  # guard; this is the one that always runs.
  nameAssertions =
    option: table: known: names:
    map (name: {
      assertion = table ? ${name};
      message = ''
        cvim.lang.cpp.${option}: "${name}" is not a name modules/lang/cpp.nix knows.
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

  # nixpkgs would throw about `clang-tools` on a system it does not build for;
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
          cvim.lang.cpp.servers: "${name}" has no package on ${pkgs.stdenv.hostPlatform.system}.
          Set cvim.lang.cpp.toolchain = "devshell" to configure it without shipping a binary.
        '';
      }) lang.servers
      ++
        nameAssertions "grammars" grammarPackages
          "Valid grammars are the parsers the configured nvim-treesitter can build."
          lang.grammars
      ++ nameAssertions "formatters" formatterPackages "Known formatters: clang_format." lang.formatters
      ++ nameAssertions "linters" linterPackages "Known linters: clangtidy, cppcheck." lang.linters;

    lsp.servers = lib.genAttrs lang.servers (_: {
      enable = true;
      # `null` means cvim ships nothing and the server runs only from $PATH.
      package = lib.mkIf (!ships) null;
      # Suffixed onto $PATH, so the clangd that matches the project's compile
      # database wins over cvim's.
      packageFallback = !prefix;
    });

    plugins.treesitter.grammarPackages = map (resolve "grammars" grammarPackages) lang.grammars;

    # clangd covers objc, objcpp and cuda as well, but `cvim.lang.cpp` declares
    # C and C++ and this file does not quietly widen that.
    #
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
    # `formatters_by_ft.cpp = [ ]` would be present in the evaluated config and
    # absent from the generated Lua. Writing it would be a claim this module
    # cannot keep.
    #
    # Leaving the key out equals "never linted" only because nvim-lint's own
    # `M.linters_by_ft` is empty upstream — read from the plugin source for
    # `c` and `cpp`, not inferred from the mechanism. Where nvim-lint does ship a
    # default for a filetype, omitting the key leaves that default live.
    plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) {
      c = lang.formatters;
      cpp = lang.formatters;
    };
    plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) {
      c = lang.linters;
      cpp = lang.linters;
    };

    extraPackages = lib.mkIf (ships && prefix) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && !prefix) toolPackages;
  };
}
