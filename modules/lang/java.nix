# `cvim.lang.java` — jdtls, the `java` grammar.
#
# Off on every profile, `default` included (D4). A host asks for it back
# through `extendModules`; until one does, this file contributes nothing to any
# closure. Both gates have to be on: `cvim.lang.enable` and
# `cvim.lang.java.enable`.
#
# ## The JDK question
#
# nixpkgs' `jdt-language-server` hard-codes a JDK path into its launcher rather
# than searching `$PATH`, so the server starts with no Java on the host at all.
# It compiles with its own bundled ecj, so completion and diagnostics work
# without a project JDK too. cvim therefore ships no JDK: a project that needs
# a specific one supplies it, which is what `toolchain = "prefer-devshell"`
# means here.
#
# No `nvim-jdtls`. Upstream is explicit that the full jdtls feature set needs
# it, and equally explicit that diagnostics, completion, imports, gotos and
# formatting work without it. Those are what a language that is off by default
# owes its user. `nvim-jdtls` is a plugin with its own lifecycle, and adding one
# is a decision for whoever actually writes Java on a host, not for this file.
#
# ## The workspace directory — the one thing cvim overrides
#
# jdtls does not have a memory-resident index; it writes an Eclipse workspace to
# disk and reuses it. Upstream's bundled config puts that under
# `vim.fn.stdpath("cache")`. cvim moves it to `vim.fn.stdpath("state")`, per the
# house rule that runtime writes go to `$XDG_STATE_HOME` or fail loudly, and
# because a cleared cache costs a full re-index of every project.
#
# This is the only freeform `lsp.servers.*.config.*` value in the module, and
# freeform values evaluate clean when they are wrong. It is verified by opening
# a Java file and reading the running client's `cmd` back, not by eval.
#
# ## Hostile defaults — what happens the moment a `.java` buffer opens
#
# Provenance: `jdt-language-server` from nixpkgs on nixvim's pin (the Eclipse
# JDT.LS project); the behaviour is nvim-lspconfig's bundled `lsp/jdtls.lua`. No
# vendored plugin, so no `rev`/`hash` of our own to pin.
#
# On open:
#
#   - a JVM starts, and jdtls builds a full Eclipse workspace for the project —
#     the heaviest on-open cost of any language in the distro
#   - that workspace is written under `$XDG_STATE_HOME/nvim/jdtls/workspace/`,
#     one subdirectory per project root, and it persists between sessions
#   - `root_markers` includes `.git`, so a stray `.java` file inside any
#     repository indexes that whole repository
#   - `JDTLS_JVM_ARGS` from the environment is forwarded as `--jvm-arg=` flags,
#     the documented hook for e.g. a lombok javaagent. cvim sets nothing there.
#
# No network access and no telemetry: Maven and Gradle dependency resolution
# happens only if the project's own build files ask for it.
#
# This file adds no plugin. That is a decision, not an omission: the language is
# one server and one grammar, so there is nothing to defer, no `lazyLoad` spec
# to be inert while `plugins.lz-n` is off, and no `setup()` that could write a
# global the layer never declared.
#
# ## Editor-surface states
#
# empty    Off, or `servers = [ ]`: nothing attaches, `require("cvim.lsp")
#          .status()` answers `none`, and a `.java` buffer is text plus grammar.
# partial  Needs two expected servers on one filetype; cvim configures one, so
#          this state is reachable only if a host adds a second.
# error    `jdtls` missing from `$PATH` (`toolchain = "devshell"` outside a
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
  lang = cfg.java;
  enable = cfg.enable && lang.enable;

  # ── The name → package maps ────────────────────────────────────────────
  #
  # `servers` is an enum in `../options/lang.nix`, so a wrong server name is
  # already a build error. `grammars`, `formatters` and `linters` are `str`, and
  # closing *that* hole is this file's job: every name below resolves to a
  # concrete package or throws. Without these maps `formatters =
  # [ "google-java-formatt" ]` would evaluate clean and format nothing.

  # The valid grammar names are exactly what the configured nvim-treesitter can
  # build — a real map, and one that cannot go stale against the pin.
  grammarPackages = config.plugins.treesitter.package.builtGrammars;

  # Empty by default: jdtls formats Java itself, through the LSP. These are for
  # a host that would rather not use it.
  formatterPackages = {
    google-java-format = pkgs.google-java-format;
  };

  linterPackages = {
    checkstyle = pkgs.checkstyle;
  };

  resolve =
    option: table: name:
    table.${name} or (throw ''
      cvim.lang.java.${option}: "${name}" is not a name modules/lang/java.nix knows.
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
        cvim.lang.java.${option}: "${name}" is not a name modules/lang/java.nix knows.
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

  # nixpkgs would throw about `jdt-language-server` on a system it does not
  # build for; this throws about the option that asked for it, and names the way
  # out.
  packageAvailable =
    name:
    let
      p = config.lsp.servers.${name}.package;
    in
    p == null || (p.meta.available or true);

  # Upstream's `cmd`, with the workspace moved out of the cache directory. The
  # shape has to stay a function: jdtls needs `-data` computed from the resolved
  # root, which is only known once a buffer has one.
  jdtlsCmd = lib.nixvim.mkRaw ''
    function(dispatchers, config)
      local data_dir = vim.fs.joinpath(vim.fn.stdpath("state"), "jdtls", "workspace")
      if config.root_dir then
        data_dir = vim.fs.joinpath(data_dir, vim.fn.fnamemodify(config.root_dir, ":p:h:t"))
      end

      local cmd = { "jdtls", "-data", data_dir }
      for arg in string.gmatch(os.getenv("JDTLS_JVM_ARGS") or "", "%S+") do
        cmd[#cmd + 1] = "--jvm-arg=" .. arg
      end

      return vim.lsp.rpc.start(cmd, dispatchers, {
        cwd = config.cmd_cwd,
        env = config.cmd_env,
        detached = config.detached,
      })
    end
  '';
in
{
  config = lib.mkIf enable {
    assertions =
      map (name: {
        assertion = packageAvailable name;
        message = ''
          cvim.lang.java.servers: "${name}" has no package on ${pkgs.stdenv.hostPlatform.system}.
          Set cvim.lang.java.toolchain = "devshell" to configure it without shipping a binary.
        '';
      }) lang.servers
      ++
        nameAssertions "grammars" grammarPackages
          "Valid grammars are the parsers the configured nvim-treesitter can build."
          lang.grammars
      ++
        nameAssertions "formatters" formatterPackages "Known formatters: google-java-format."
          lang.formatters
      ++ nameAssertions "linters" linterPackages "Known linters: checkstyle." lang.linters;

    lsp.servers = lib.genAttrs lang.servers (name: {
      enable = true;
      # `null` means cvim ships nothing and the server runs only from $PATH.
      package = lib.mkIf (!ships) null;
      # Suffixed onto $PATH, so a project's own jdtls wins over cvim's.
      packageFallback = !prefix;
      config = lib.mkIf (name == "jdtls") { cmd = jdtlsCmd; };
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
    # `formatters_by_ft.java = [ ]` would be present in the evaluated config and
    # absent from the generated Lua. Writing it would be a claim this module
    # cannot keep.
    #
    # Leaving the key out equals "never linted" only because nvim-lint's own
    # `M.linters_by_ft` is empty upstream — read from the plugin source for
    # `java`, not inferred from the mechanism. Where nvim-lint does ship a
    # default for a filetype, omitting the key leaves that default live.
    plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) {
      java = lang.formatters;
    };
    plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) { java = lang.linters; };

    extraPackages = lib.mkIf (ships && prefix) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && !prefix) toolPackages;
  };
}
