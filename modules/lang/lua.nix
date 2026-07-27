# `lang/lua` — Lua.
#
# Ships the `lua`/`luadoc` grammars, `lua_ls`, and `stylua`.
#
# ## Why `lua_ls` and not `emmylua_ls`
#
# The constraint first: it has to be one of exactly those two. `lazydev.nvim`
# — shipped by the editing-core unit, not this one — declares
# `M.supported_clients = { "lua_ls", "emmylua_ls" }` and is **inert until one
# of them attaches**. Any third Lua server would leave another unit's plugin
# evaluating clean, building green and contributing nothing.
#
# lazydev supports both equally, so it is neutral here and is not an argument
# for either. The decision rests on maturity, with closure as a weak second:
#
# | server        | version | aarch64-darwin | x86_64-linux |
# |---------------|---------|----------------|--------------|
# | `lua_ls`      | 3.18.2  |  21.5 MB       |  70.4 MB     |
# | `emmylua_ls`  | 0.24.0  |  66.7 MB       |  80.7 MB     |
#
# `lua_ls` is the reference implementation at a long-stable major version,
# against a pre-1.0 Rust reimplementation. That is the reason. **The closure
# argument is deliberately demoted**: it looks decisive on darwin (45 MB apart)
# and nearly vanishes on linux (10.3 MB apart), so quoting the darwin gap as if
# it generalised would be the same platform-scoping error the plan already made
# once with the server-closure target. Lua is a workstation language and the
# workstation here is darwin, so the smaller number is real — it is just not
# what carries the decision.
#
# Both stay in `cvim.lang.lua.servers`' enum, so reversing this is one line.
#
# `lazydev` itself is NOT configured here — it is a blink-cmp completion source
# and belongs to the editing core. This file ships the server it needs.
#
# ## Editor-surface states
#
# - empty   — a `.lua` file outside any project: `lua_ls` attaches with only
#             its bundled stdlib definitions. Neovim's own `vim.*` API does not
#             resolve until lazydev feeds `workspace.library`, which is the
#             editing core's job; the absence shows as "undefined field" hints,
#             not as a failure to attach.
# - partial — server attached, `stylua` absent from `PATH` under
#             `toolchain = "devshell"`: editing and diagnostics work, and a
#             format request reports that no formatter is available rather than
#             silently leaving the buffer unchanged.
# - error   — a syntax error: `lua_ls` reports it as a diagnostic at the span
#             and continues serving the rest of the file.
#
# ## Hostile-defaults review
#
# `lua-language-server` (LuaLS, in nixpkgs, not vendored) indexes its
# *workspace* — the directory it is opened in — which is what makes completion
# work and is bounded by the project, not by `$HOME`. It is not the fff class,
# which walked the home directory by default. Grepping its settings surface for
# the scan/watch/poll/index/network/telemetry class finds `telemetry.enable`,
# which upstream defaults to `false` and prompts on first run; the nixpkgs
# build ships that default unchanged and nothing here turns it on. No
# auto-update and no auto-save. `stylua` is a one-shot process on the buffer.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.lua;

  # Name → package. `formatters`/`linters` are `str` in the option surface, so
  # an unknown name has to throw here or it silently formats nothing.
  formatterPackages = {
    stylua = pkgs.stylua;
  };
  linterPackages = {
    luacheck = pkgs.luaPackages.luacheck;
  };

  lookup =
    what: table: name:
    table.${name}
      or (throw "cvim.lang.lua.${what}: unknown name '${name}'. Known: ${lib.concatStringsSep ", " (lib.attrNames table)}");

  toolPackages = lib.unique (
    map (lookup "formatters" formatterPackages) lang.formatters
    ++ map (lookup "linters" linterPackages) lang.linters
  );

  shipsBinaries = lang.toolchain != "devshell";
  devshellWins = lang.toolchain == "prefer-devshell";

  serverPackages = {
    lua_ls = pkgs.lua-language-server;
    emmylua_ls = pkgs.emmylua-ls;
  };

  mkServer = name: {
    ${name} = {
      enable = true;
      package = if shipsBinaries then serverPackages.${name} else null;
      packageFallback = devshellWins;
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
          lua = lang.formatters;
        };

        plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) {
          lua = lang.linters;
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
