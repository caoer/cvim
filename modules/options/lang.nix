# `cvim.lang` — Per-language toolchains.
#
# One `cvim.lang.<language>` block per language, twelve of them, every one the
# same six options generated from one `mkLang`. The shape cannot drift between
# languages because there is only one copy of it. A language module
# (`modules/lang/<language>.nix`) reads its own block and nothing else.
#
# ## Why `servers` is an enum and the tool lists are not
#
# nixvim's `lsp.servers` is a freeform attrset. `lsp.servers.gopsl.enable =
# true` evaluates green, builds green, and configures nothing — the plan's §7
# freeform failure class, arriving through a misspelled attribute name rather
# than a misspelled setting. The server name is the one field this file can
# close, so `servers` is an `enum`: a wrong name is a build error that prints
# the valid values.
#
# `grammars`, `formatters` and `linters` stay `str`. Enumerating them for
# twelve languages would make this file a bottleneck for the two units that do
# not own it, and the check belongs one level down anyway: **each language
# module maps every name it accepts to a concrete package**, so an unknown name
# throws there. That map is the contract, not a convenience — a module that
# skips it re-opens the same hole one layer lower.
#
# ## Why lists rather than `nullOr`
#
# The house rule at the top of `default.nix` asks for `null` wherever "unset"
# and "explicitly nothing" are different answers. For these four lists they are
# not: `[ ]` already says "nothing", and it says it in a way a module can act on
# without a second branch. So `[ ]` is how you turn a tool class off —
# `cvim.lang.markdown.linters = [ ]` is §6 row 12, spelled directly. `false`
# turns a whole language off, and `toolchain = "devshell"` turns off shipping
# binaries without turning off the configuration. Nothing here is unturnoffable.
#
# ## Defaults
#
# Per D4. The `default` profile enables the languages actually written on this
# machine; `java`, `csharp`, `cpp` and `rust` are off everywhere and come back
# only through host-side `extendModules`. The `server` profile enables none of
# the twelve — that is what the profile is for — and `cvim.lang.enable` in
# `profiles.nix` turns the area off above them as well. Both levels move,
# because a server host that re-enables the area to get one language should get
# that one language, not the workstation's eight.
#
# `nix` is the only language whose *server* changes with the profile: `nixd`
# costs 538 MB of closure against `nil_ls`'s 88 MB (measured, aarch64-darwin),
# which is worth it on the machine that writes Nix and absurd on a box that
# occasionally reads it.
#
# Rows marked *(8b)* / *(8c)* are declared here because this file has one
# writer, but the languages belong to those units. They change their defaults
# by asking this file's owner, not by editing it.
{ config, lib, ... }:
let
  inherit (lib) mkOption types;

  cfg = config.cvim;

  # `null` profile means "no cascade", so it keeps the declared defaults, which
  # are the workstation's. Only `"server"` moves them.
  onServer = cfg.profile == "server";

  mkLang =
    {
      # Prose name, used in the generated descriptions.
      language,
      # Every server this language may be driven by. Position carries no
      # meaning. Adding a value is a one-line edit by this file's owner.
      knownServers,
      # What `servers` defaults to. A list rather than a choice because `web`
      # runs three servers at once while `nix` picks one of two.
      servers,
      grammars,
      formatters ? [ ],
      linters ? [ ],
      # Whether a workstation enables this language. A `server` never does.
      workstation ? true,
    }:
    {
      enable = mkOption {
        type = types.bool;
        default = !onServer && workstation;
        defaultText = lib.literalMD "`${lib.boolToString workstation}` on a workstation, `false` on `server`";
        example = false;
        description = ''
          Whether to configure ${language}.

          Off means cvim adds no grammar, no server, no formatter and no linter
          for ${language} — not that it hides a configured one. The whole area
          also hangs off `cvim.lang.enable`, so a `server` build has to turn
          both back on to get ${language} back.
        '';
      };

      grammars = mkOption {
        type = types.listOf types.str;
        default = grammars;
        example = [ ];
        description = ''
          Tree-sitter grammars to install for ${language}. `[ ]` installs none,
          which leaves ${language} on Vim's regex highlighting rather than
          leaving it unhighlighted.

          The `lang` layer contributes grammars; the `editor` layer owns the
          treesitter plugin itself.
        '';
      };

      servers = mkOption {
        type = types.listOf (types.enum knownServers);
        default = servers;
        example = [ ];
        description = ''
          Language servers to enable for ${language}. `[ ]` configures none,
          which is how you keep the grammar and the formatter without the
          server.

          Restricted to ${
            lib.concatMapStringsSep ", " (s: "`${s}`") knownServers
          } on purpose: `lsp.servers` is freeform, so an unchecked name here
          would evaluate clean and silently attach nothing.
        '';
      };

      formatters = mkOption {
        type = types.listOf types.str;
        default = formatters;
        example = [ ];
        description = ''
          `conform` formatters for ${language}, in the order conform should try
          them. `[ ]` means ${language} is never formatted by cvim.

          These are the explicit list `conform` needs: its `autoInstall`
          defaults to `false`, so a name omitted here is a tool that does not
          exist rather than one that is fetched on demand.
        '';
      };

      linters = mkOption {
        type = types.listOf types.str;
        default = linters;
        example = [ ];
        description = ''
          `nvim-lint` linters for ${language}. `[ ]` means ${language} is never
          linted, which is a real answer — see §6 row 12, where a linter that
          is not installed pops an ENOENT error on every write.

          Explicit for the same reason as `formatters`: `lint`'s `autoInstall`
          also defaults to `false`.
        '';
      };

      toolchain = mkOption {
        type = types.enum [
          "prefer-devshell"
          "closure"
          "devshell"
        ];
        default = "prefer-devshell";
        example = "devshell";
        description = ''
          Where ${language}'s binaries come from. cvim configures the editor
          side; this decides who supplies the compiler.

          - `"prefer-devshell"` — cvim ships them, and a project devshell's
            copies win by being earlier on `PATH` (`packageFallback = true`).
            The editor works in a bare directory, and a project that pins its
            own toolchain gets the one it pinned.
          - `"closure"` — cvim's copies always win. For a language where a
            version mismatch breaks the editor worse than it helps.
          - `"devshell"` — cvim ships nothing (`package = null`). ${language}
            works only inside a devshell that supplies the binaries. This keeps
            a closure small without giving up the configuration.
        '';
      };
    };

  languages = {
    go = mkLang {
      language = "Go";
      knownServers = [ "gopls" ];
      servers = [ "gopls" ];
      grammars = [
        "go"
        "gomod"
        "gosum"
        "gowork"
      ];
      formatters = [ "gofmt" ];
    };

    typescript = mkLang {
      language = "TypeScript and JavaScript";
      # `typescript-tools` is a plugin, not an `lsp.servers` entry, and that is
      # deliberate: it must not appear in the expected-servers signal, because
      # it is not expected to attach until you ask for it (§6 row 2).
      knownServers = [
        "typescript-tools"
        "ts_ls"
        "vtsls"
      ];
      servers = [ "typescript-tools" ];
      grammars = [
        "typescript"
        "tsx"
        "javascript"
        "jsdoc"
      ];
      formatters = [ "prettier" ];
    };

    nix = mkLang {
      language = "Nix";
      knownServers = [
        "nixd"
        "nil_ls"
      ];
      # The one profile-sensitive server choice — 538 MB against 88 MB.
      servers = if onServer then [ "nil_ls" ] else [ "nixd" ];
      grammars = [ "nix" ];
      formatters = [ "nixfmt" ];
      linters = [ "statix" ];
    };

    lua = mkLang {
      language = "Lua";
      # Both are lazydev.nvim's `supported_clients`; anything else leaves that
      # plugin inert. See `modules/lang/lua.nix` for which one ships and why.
      knownServers = [
        "lua_ls"
        "emmylua_ls"
      ];
      servers = [ "lua_ls" ];
      grammars = [
        "lua"
        "luadoc"
      ];
      formatters = [ "stylua" ];
    };

    # (8b)
    python = mkLang {
      language = "Python";
      knownServers = [
        "basedpyright"
        "pyright"
        "ruff"
        "pylsp"
      ];
      servers = [
        "basedpyright"
        "ruff"
      ];
      grammars = [ "python" ];
      formatters = [ "ruff_format" ];
      linters = [ "ruff" ];
    };

    # (8b)
    bash = mkLang {
      language = "Bash";
      knownServers = [ "bashls" ];
      servers = [ "bashls" ];
      grammars = [ "bash" ];
      formatters = [ "shfmt" ];
      linters = [ "shellcheck" ];
    };

    # (8b)
    markdown = mkLang {
      language = "Markdown";
      knownServers = [
        "marksman"
        "harper_ls"
      ];
      servers = [ "marksman" ];
      grammars = [
        "markdown"
        "markdown_inline"
      ];
      # `ccc_mdformat` is cvim's own formatter, threaded in as `_module.args`.
      formatters = [ "ccc_mdformat" ];
      # §6 row 12: markdown linters stay off. Not an oversight — the linters
      # were not installed and popped an ENOENT dialog on every write.
      linters = [ ];
    };

    # (8b)
    web = mkLang {
      language = "CSS, HTML and JSON";
      knownServers = [
        "cssls"
        "html"
        "jsonls"
        "eslint"
        "tailwindcss"
        "biome"
      ];
      # Three servers, one package (`vscode-langservers-extracted`).
      servers = [
        "cssls"
        "html"
        "jsonls"
      ];
      grammars = [
        "css"
        "html"
        "json"
      ];
      formatters = [ "prettier" ];
    };

    # (8c) — off everywhere; `extendModules` is how a host asks for it.
    java = mkLang {
      language = "Java";
      knownServers = [ "jdtls" ];
      servers = [ "jdtls" ];
      grammars = [ "java" ];
      workstation = false;
    };

    # (8c)
    csharp = mkLang {
      language = "C#";
      knownServers = [
        "omnisharp"
        "csharp_ls"
      ];
      servers = [ "omnisharp" ];
      grammars = [ "c_sharp" ];
      workstation = false;
    };

    # (8c)
    cpp = mkLang {
      language = "C and C++";
      knownServers = [ "clangd" ];
      servers = [ "clangd" ];
      grammars = [
        "c"
        "cpp"
      ];
      formatters = [ "clang_format" ];
      workstation = false;
    };

    # (8c)
    rust = mkLang {
      language = "Rust";
      knownServers = [ "rust_analyzer" ];
      servers = [ "rust_analyzer" ];
      grammars = [ "rust" ];
      formatters = [ "rustfmt" ];
      workstation = false;
    };
  };
in
{
  options.cvim.lang = {
    enable = mkOption {
      type = types.bool;
      default = true;
      example = false;
      description = ''
        Per-language toolchains: grammars, servers, formatters, and linters
        for the languages actually written on this host.

        This is the heavy area. The `server` profile turns it off, which is the
        difference between a remote text editor and a workstation build.

        This is the area gate. Each language underneath has its own `enable`,
        and both have to be on for a language to be configured.
      '';
    };
  }
  // languages;
}
