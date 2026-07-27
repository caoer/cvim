# `cvim.lang.csharp` — omnisharp or csharp-ls, the `c_sharp` grammar.
#
# Off on every profile, `default` included (D4). A host asks for it back
# through `extendModules`; until one does, this file contributes nothing to any
# closure. Both gates have to be on: `cvim.lang.enable` and
# `cvim.lang.csharp.enable`.
#
# ## Two servers, and the platform hole between them
#
# `omnisharp` is the default: nixpkgs' `omnisharp-roslyn` carries its own .NET
# runtime, so the server starts without a dotnet SDK on the host. `csharp_ls` is
# the lighter alternative and does need `dotnet` on `$PATH`.
#
# `csharp-ls` is marked `badPlatforms = [ "aarch64-darwin" ]` in nixpkgs. On an
# Apple-silicon Mac, `servers = [ "csharp_ls" ]` therefore cannot ship a binary.
# The assertion below says so in terms of the option that asked, and names the
# way out (`toolchain = "devshell"`), instead of letting nixpkgs throw about a
# package the user never mentioned. This is the one place in the 8c set where
# the answer genuinely differs per system.
#
# No dotnet SDK is shipped. Building, restoring and running tests are the
# project's business; `toolchain = "prefer-devshell"` is how it supplies them.
#
# ## Hostile defaults — what happens the moment a `.cs` buffer opens
#
# Provenance: `omnisharp-roslyn` and `csharp-ls` from nixpkgs on nixvim's pin
# (both upstream releases); the behaviour is nvim-lspconfig's bundled
# `lsp/omnisharp.lua` and `lsp/csharp_ls.lua`. No vendored plugin, so no
# `rev`/`hash` of our own to pin.
#
# omnisharp, on open:
#
#   - loads the whole solution through MSBuild, not just the open file.
#     `MsBuild.LoadProjectsOnDemand` is left at upstream's `nil`, which means
#     off, which means every project in the solution is loaded. Turning it on
#     would be faster and would silently truncate reference lists, so it stays
#     as upstream ships it.
#   - reads `.editorconfig` for formatting, naming and analyzer settings
#   - `DotNet:enablePackageRestore=false` is already in upstream's `cmd`, so
#     opening a file does **not** hit the network for NuGet packages
#   - `Sdk.IncludePrereleases = true` — upstream's choice, left alone
#   - roslyn analyzers, import completion and decompilation support are all left
#     at `nil`, i.e. off
#   - `--hostPID` is passed, so the server exits when neovim does
#
# csharp_ls, on open: `AutomaticWorkspaceInit = true` in `init_options`, so it
# locates and loads the nearest `.sln`, `.slnx` or `.csproj` from the root
# directory without being asked. Its `cmd` is started with `cwd` set to the
# project root for exactly that reason.
#
# Neither server writes outside the project and its own temporary directories;
# neither reports telemetry.
#
# This file adds no plugin. That is a decision, not an omission: the language is
# one server and one grammar, so there is nothing to defer, no `lazyLoad` spec
# to be inert while `plugins.lz-n` is off, and no `setup()` that could write a
# global the layer never declared.
#
# `omnisharp-extended-lsp.nvim` is not added either, for the same reason
# `nvim-jdtls` is not: upstream names it as the way to make `go_to_definition`
# reach decompiled sources, and that is a plugin decision for a host that
# actually writes C#, not for a module that is off everywhere.
#
# ## Editor-surface states
#
# empty    Off, or `servers = [ ]`: nothing attaches, `require("cvim.lsp")
#          .status()` answers `none`, and a `.cs` buffer is text plus grammar.
# partial  Both servers enabled and only one attaches — the one state in this
#          module that is reachable without a host adding anything, because
#          `csharp` is the only 8c language with two servers to choose from.
# error    The server binary is missing from `$PATH` (`toolchain = "devshell"`
#          outside a devshell): nothing is drawn, no dialog opens, `status()`
#          counts it missing, and the reason is written to
#          `vim.lsp.log.get_filename()`.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.csharp;
  enable = cfg.enable && lang.enable;

  # ── The name → package maps ────────────────────────────────────────────
  #
  # `servers` is an enum in `../options/lang.nix`, so a wrong server name is
  # already a build error. `grammars`, `formatters` and `linters` are `str`, and
  # closing *that* hole is this file's job: every name below resolves to a
  # concrete package or throws. Without these maps `formatters = [ "csharpierr" ]`
  # would evaluate clean and format nothing.

  # The valid grammar names are exactly what the configured nvim-treesitter can
  # build — a real map, and one that cannot go stale against the pin.
  grammarPackages = config.plugins.treesitter.package.builtGrammars;

  # Empty by default: both servers format C# themselves, through the LSP.
  formatterPackages = {
    csharpier = pkgs.csharpier;
  };

  # nvim-lint ships no C# linter on this pin, so every name is unknown and the
  # map is empty rather than absent. An empty map still throws, with the list of
  # known names being the empty list — which is the honest answer.
  linterPackages = { };

  resolve =
    option: table: name:
    table.${name} or (throw ''
      cvim.lang.csharp.${option}: "${name}" is not a name modules/lang/csharp.nix knows.
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
        cvim.lang.csharp.${option}: "${name}" is not a name modules/lang/csharp.nix knows.
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

  # This is the assertion that earns its keep in this module: `csharp_ls` has no
  # aarch64-darwin build, and without this the failure arrives as a nixpkgs
  # throw about a package name the user never typed.
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
          cvim.lang.csharp.servers: "${name}" has no package on ${pkgs.stdenv.hostPlatform.system}.
          Set cvim.lang.csharp.toolchain = "devshell" to configure it without shipping a binary.
        '';
      }) lang.servers
      ++
        nameAssertions "grammars" grammarPackages
          "Valid grammars are the parsers the configured nvim-treesitter can build."
          lang.grammars
      ++ nameAssertions "formatters" formatterPackages "Known formatters: csharpier." lang.formatters
      ++
        nameAssertions "linters" linterPackages
          "nvim-lint ships no C# linter on this pin, so no name is valid here."
          lang.linters;

    lsp.servers = lib.genAttrs lang.servers (_: {
      enable = true;
      # `null` means cvim ships nothing and the server runs only from $PATH.
      package = lib.mkIf (!ships) null;
      # Suffixed onto $PATH, so a project's own server wins over cvim's.
      packageFallback = !prefix;
    });

    plugins.treesitter.grammarPackages = map (resolve "grammars" grammarPackages) lang.grammars;

    # Only written when non-empty, and that is not tidiness.
    #
    # nixvim's `toLuaObject` DROPS empty values, so `formatters_by_ft.cs = [ ]`
    # — which is the default here, because both servers format through the LSP —
    # is present in the evaluated config and absent from the generated
    # `init.lua`. Writing it would be a claim this module cannot keep.
    #
    # There is a second reason, and it is the sharper one. Both of these options
    # take their default only while *no* module defines them, and
    # `lintersByFt`'s default is a non-empty table (vale for markdown, jsonlint
    # for json, and more). A `cs = [ ]` definition would silently delete that
    # whole table for every other filetype in the distro. `[ ]` means this
    # module contributes no entry — it does not mean it reaches across and
    # clears someone else's.
    #
    # Omitting the key is only equivalent to "unlinted" because nvim-lint ships
    # no default for `cs`. That is verified per filetype, not assumed from the
    # mechanism: markdown/vale is the counter-example where the same omission
    # leaves an upstream default live.
    plugins.conform-nvim.settings.formatters_by_ft = lib.optionalAttrs (lang.formatters != [ ]) {
      cs = lang.formatters;
    };
    plugins.lint.lintersByFt = lib.optionalAttrs (lang.linters != [ ]) { cs = lang.linters; };

    extraPackages = lib.mkIf (ships && prefix) toolPackages;
    extraPackagesAfter = lib.mkIf (ships && !prefix) toolPackages;
  };
}
