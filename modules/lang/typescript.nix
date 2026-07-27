# `lang/typescript` — TypeScript and JavaScript. On demand, never on filetype.
#
# Ships the `typescript`/`tsx`/`javascript`/`jsdoc` grammars, `prettier`, and
# `typescript-tools` **loaded only when asked for** — `:TsStart` or
# `<leader>zz`.
#
# ## Why this file is shaped so defensively (§6 row 2)
#
# `typescript-tools`' `setup()` calls `vim.lsp.enable` unconditionally, and its
# `root_dir` falls back to `.git`. On 2026-07-14 a stray `.js` opened inside a
# large repo made tsserver index the entire tree: it filled the system-wide
# file table (`ENFILE`), then V8 ran out of memory and `SIGBUS`-crashed
# unrelated processes on ZT's machine. Opening a TypeScript file must therefore
# start nothing at all.
#
# The mechanism is `lazy = true` with **no `ft`**. Verified in lz.n's own
# source rather than assumed — `lua/lz/n/handler/lazy.lua` is a handler "for
# plugins that have `lazy` set to true without any other lazy-loading
# mechanisms configured", and `:h lz.n.PluginSpecHandlers` documents
# `{lazy?} (boolean)` as "Lazy-load manually, e.g. using `trigger_load`".
#
# `ft = [ ]` is NOT equivalent and is the trap: lz.n eager-loads a spec that
# has no trigger handler at all, which is the incident again by a different
# route.
#
# ## The guard for "no lazy provider" lives in `modules/core/lazy.nix`, not here
#
# All of the above is inert without a lazy-loading provider, and nixvim only
# *warns* about that — a warning does not fail a build. This module used to
# carry its own assertion for it. It no longer does, for two reasons.
#
# The first is that the assertion was WRONG about the mechanism. It claimed
# that with no provider typescript-tools becomes a start plugin whose `setup()`
# runs at startup and attaches tsserver to every buffer. It does not:
# `lib/plugins/mk-neovim-plugin.nix` routes `setup()` into the lz.n spec
# whenever `lazyLoad.enable` is true and writes it to init.lua only when that
# is false, so with no provider **the plugin never loads and `setup()` never
# runs**. The real failure is no TypeScript server at all, silently — the
# opposite symptom, and a reader debugging from the old text would hunt for
# something loading too early and find nothing loading at all.
#
# The second is that `modules/core/lazy.nix` already asserts this correctly and
# generally, for every plugin declaring a lazy spec rather than for this one,
# and it names typescript-tools and §6 row 2 in its message. Keeping a local
# copy meant both fired together in a single error, so a reader had to
# adjudicate between two authoritative accounts of one failure before acting —
# which is worse than either alone. Verified: with the provider forced off,
# `modules/core/lazy.nix` catches this module's configuration on its own.
#
# ## `typescript-tools` is deliberately NOT an `lsp.servers` entry
#
# It is a plugin that manages its own client, so it never appears in
# `config.lsp.servers` and therefore never reaches the expected-servers signal.
# That is correct rather than incidental: a `.ts` buffer with nothing attached
# is the intended resting state, and the statusline must not report it as a
# server that failed to attach.
#
# ## Editor-surface states
#
# - empty   — a `.ts`/`.js` buffer before `:TsStart`: grammar highlighting and
#             formatting work, no LSP client, no diagnostics, and no indicator.
#             This is the normal state, not a degraded one.
# - partial — after `:TsStart` in a tree with no `tsconfig.json`: the client
#             attaches in single-file mode; cross-file resolution is absent
#             while completion and hover work.
# - error   — `:TsStart` with no `node` on `PATH`: the client fails to spawn
#             and nvim reports it once, in `:messages` and as a notification.
#             The buffer stays editable and nothing retries in a loop.
#
# ## Hostile-defaults review
#
# `typescript-tools.nvim` (pmizio), nixpkgs `typescript-tools-nvim`, not
# vendored. Its settings surface greps dirty on exactly the class that caused
# the incident — it watches and indexes a project tree, and picks that tree
# with a `.git` fallback. That is not disabled here because it is what a
# TypeScript language server does; it is made *opt-in* instead, which is the
# only fix that actually bounds it. `separate_diagnostic_server` (default true)
# spawns a second tsserver, doubling the file handles the incident exhausted —
# left at its default only because the server no longer starts on its own.
# No telemetry, no auto-update, no network fetch.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.lang;
  lang = cfg.typescript;

  # Name → package. `formatters`/`linters` are `str` in the option surface, so
  # an unknown name has to throw here or it silently formats nothing.
  formatterPackages = {
    prettier = pkgs.prettier;
  };
  linterPackages = { };

  lookup =
    what: table: name:
    table.${name}
      or (throw "cvim.lang.typescript.${what}: unknown name '${name}'. Known: ${lib.concatStringsSep ", " (lib.attrNames table)}");

  toolPackages = lib.unique (
    map (lookup "formatters" formatterPackages) lang.formatters
    ++ map (lookup "linters" linterPackages) lang.linters
  );

  shipsBinaries = lang.toolchain != "devshell";
  devshellWins = lang.toolchain == "prefer-devshell";

  # What typescript-tools needs to actually spawn a server: the runtime and
  # `tsserver.js` itself.
  serverTools = [
    pkgs.nodejs
    pkgs.typescript
  ];

  # The filetypes typescript-tools covers. Stated here because conform and
  # nvim-lint are keyed by filetype and no other source supplies that mapping.
  # This is NOT a restatement of a server's filetype table — the expected-
  # servers signal resolves those from `vim.lsp.config`, and typescript-tools
  # is deliberately not one of its servers.
  filetypes = [
    "typescript"
    "typescriptreact"
    "javascript"
    "javascriptreact"
  ];
in
{
  config = lib.mkIf (cfg.enable && lang.enable) (
    lib.mkMerge [
      {
        plugins.treesitter.grammarPackages = map (
          g: config.plugins.treesitter.package.builtGrammars.${g}
        ) lang.grammars;

        plugins.conform-nvim.settings.formatters_by_ft = lib.mkIf (lang.formatters != [ ]) (
          lib.genAttrs filetypes (_: lang.formatters)
        );

        plugins.lint.lintersByFt = lib.mkIf (lang.linters != [ ]) (
          lib.genAttrs filetypes (_: lang.linters)
        );
      }

      # Both attributes are defined unconditionally, with the unused one
      # empty. Choosing the attribute NAME with an `if` instead makes this
      # module's shape depend on `config`, and nixvim's top level is freeform —
      # that is an infinite recursion, not a style preference.
      {
        extraPackages = lib.optionals (shipsBinaries && !devshellWins) toolPackages;
        extraPackagesAfter = lib.optionals (shipsBinaries && devshellWins) toolPackages;
      }

      (lib.mkIf (lib.elem "typescript-tools" lang.servers) {
        plugins.typescript-tools = {
          enable = true;
          lazyLoad = {
            enable = true;
            # `lazy = true` and deliberately no `ft`. Do not add one.
            settings.lazy = true;
          };
        };

        # typescript-tools runs `tsserver.js` on node; both have to exist or
        # `:TsStart` loads the plugin and then throws "Cannot find tsserver
        # executable in local project nor global npm installation". Shipping
        # only nodejs is not enough, and the failure lands at `:TsStart`, not
        # at build — it was found by running the command, not by reading this.
        #
        # `tsserver_path` is deliberately NOT set. Read against the shipped
        # `tsserver_provider.lua:140-190`, resolution runs:
        #   1. `tsserver_path` config              <- would always win
        #   2. <root>/node_modules/typescript      <- the project's own
        #   ...
        #   8. exepath("tsserver") + lib/node_modules/typescript
        #      (an explicit "resolve tsserver in Nix store" branch)
        # Setting (1) would pin every project to cvim's TypeScript version.
        # Putting the package on PATH instead lands at (8), so a project's own
        # TypeScript still wins at (2) — `packageFallback` semantics arriving
        # through the plugin's own search order rather than a second mechanism.
        extraPackages = lib.optionals (shipsBinaries && !devshellWins) serverTools;
        extraPackagesAfter = lib.optionals (shipsBinaries && devshellWins) serverTools;

        # Loading the plugin is NOT enough to attach the buffer you are looking
        # at. `setup()` calls `vim.lsp.enable`, which REGISTERS a `FileType`
        # autocmd rather than replaying it — so buffers already open when you
        # run `:TsStart` are never visited, the call reports success, and
        # nothing happens. Verified: without the replay below, `:TsStart` on an
        # open `.ts` buffer left `vim.lsp.get_clients` empty after 30s.
        #
        # cnixvim's version of this command claims "attaches js/ts buffers".
        # On this pin that claim is false, which is why it is not ported.
        userCommands.TsStart = {
          command.__raw = ''
            function()
              require("lz.n").trigger_load("typescript-tools.nvim")

              -- The replay MUST be scheduled, not immediate. `trigger_load`
              -- returns before typescript-tools has registered its own
              -- `FileType` handler — its setup defers — so replaying inline
              -- fires into a handler that does not exist yet and attaches
              -- nothing. `vim.schedule` callbacks run FIFO, so queueing here
              -- lands us after the plugin's own deferred setup.
              --
              -- Found by verifying interactively: inline replay attached in a
              -- headless run and NEVER attached in a real tmux pane, and a
              -- second manual replay attached every time. The headless pass
              -- was a timing accident, not a working mechanism.
              vim.schedule(function()
                local want = ${
                  "{ " + lib.concatMapStringsSep ", " (f: ''["${f}"] = true'') filetypes + " }"
                }
                local n = 0
                for _, b in ipairs(vim.api.nvim_list_bufs()) do
                  if vim.api.nvim_buf_is_loaded(b) and want[vim.bo[b].filetype] then
                    vim.api.nvim_exec_autocmds("FileType", { buffer = b })
                    n = n + 1
                  end
                end
                vim.notify(("typescript-tools: started, replayed FileType on %d buffer(s)"):format(n))
              end)
            end
          '';
          desc = "Start the TypeScript language server on demand";
        };

        # `<leader>` is whatever `mapleader` is when this binds. cvim sets no
        # mapleader today, so this currently lands on `\zz`; the editor core
        # owns that global. `:TsStart` is the binding-independent entry point
        # and is what the incident gate is verified through.
        keymaps = [
          {
            mode = "n";
            key = "<leader>zz";
            action = "<cmd>TsStart<cr>";
            options = {
              desc = "Start TypeScript LSP";
              silent = true;
            };
          }
        ];
      })
    ]
  );
}
