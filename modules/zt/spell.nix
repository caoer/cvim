# Spelling: the curated dictionary, and a spellfile `zg` can actually write.
#
# The word list is ported from the committed nix source in cnixvim
# (`modules/zt-extras.nix`, the "Spell dictionary" section) and from nowhere
# else. The live `~/.config/nvim/spell/` file is deliberately NOT a source: it
# accumulates whatever was ever typed into it, including — plausibly —
# fragments of a secret added by a stray `zg`. The committed source is the only
# trusted origin, so it is not diffed against the live file either.
#
# WRITABILITY IS THE POINT, not a nicety. cnixvim put the store path FIRST in
# 'spellfile', and `zg` writes to the first entry — into the nix store, which
# is read-only. It also compiles a sibling `.spl`, which fails there for the
# same reason. That is the silent-write failure class the plan names, so the
# layout here is inverted:
#
#   1. $XDG_STATE_HOME/nvim/spell/en.utf-8.add       user's, `zg` target
#   2. $XDG_STATE_HOME/nvim/spell/cvim.en.utf-8.add  ours, refreshed from nix
#
# Both are under `stdpath("state")`, which resolves `$XDG_STATE_HOME` on both
# darwin and linux and falls back to `~/.local/state`. Neither is a store path,
# so vim can compile `.spl` for both. The managed file is refreshed only when
# its content differs, so the `.spl` is not invalidated on every launch.
#
# Editor-surface states:
#   empty    Fresh state dir — the user file is created empty and the managed
#            file is written from nix. `zg` works on the first launch.
#   partial  Managed file present but stale (dictionary changed in nix): it is
#            rewritten in place; the user's own file is never touched.
#   error    An unwritable state dir is reported once via `vim.notify` at WARN
#            rather than failing silently, and 'spellfile' is left at vim's
#            default. This is the "fail loudly" half of the runtime-writes rule.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.utilities;

  words = [
    "Backend"
    "backend"
    "frontend"
    "Frontend"
    "config"
    "configs"
    "Tailscale"
    "tailscale"
    "https"
    "API"
    "APIs"
    "async"
    "await"
    "boolean"
    "stylesheet"
    "kubernetes"
    "kubectl"
    "nginx"
    "postgres"
    "PostgreSQL"
    "redis"
    "Redis"
    "TypeScript"
    "JavaScript"
    "localhost"
    "enum"
    "enums"
    "namespace"
    "middleware"
    "middlewares"
    "auth"
    "OAuth"
    "JSON"
    "yaml"
    "YAML"
    "dockerfile"
    "Dockerfile"
    "websocket"
    "GraphQL"
    "terraform"
    "Terraform"
    "workflow"
    "workflows"
    "repo"
    "repos"
    "microservice"
    "microservices"
    "Homebrew"
    "Tmux"
    "WezTerm"
    "Cheatsheet"
    "frontmatter"
    "callouts"
  ];

  dictionary = pkgs.writeText "cvim-spell-en.utf-8.add" (lib.concatMapStrings (w: w + "\n") words);
in
{
  config = lib.mkIf cfg.enable {
    opts = {
      # Spell checking off by default; `spelloptions = "camel"` means that when
      # it IS switched on, camelCase words are split into their parts rather
      # than reported wholesale as misspellings.
      spell = false;
      spelloptions = "camel";
    };

    extraConfigLua = ''
      -- stdpath("state") honours $XDG_STATE_HOME on both platforms and falls
      -- back to ~/.local/state. Never a store path — see this file's header.
      local spelldir = vim.fn.stdpath("state") .. "/spell"

      if vim.fn.isdirectory(spelldir) == 0 then
        vim.fn.mkdir(spelldir, "p")
      end

      if vim.fn.isdirectory(spelldir) == 0 or vim.fn.filewritable(spelldir) ~= 2 then
        vim.notify(
          "cvim: spell directory is not writable, `zg` will not persist: " .. spelldir,
          vim.log.levels.WARN
        )
      else
        local user_file = spelldir .. "/en.utf-8.add"
        local managed_file = spelldir .. "/cvim.en.utf-8.add"

        -- The user's own additions. Created once, never rewritten.
        if vim.fn.filereadable(user_file) == 0 then
          vim.fn.writefile({}, user_file)
        end

        -- Ours. Refreshed only on a real change, so vim does not recompile the
        -- sibling .spl on every launch.
        local shipped = vim.fn.readfile("${dictionary}")
        local current = vim.fn.filereadable(managed_file) == 1 and vim.fn.readfile(managed_file) or nil
        if not current or table.concat(current, "\n") ~= table.concat(shipped, "\n") then
          vim.fn.writefile(shipped, managed_file)
        end

        -- User file FIRST: `zg` writes to the first entry in 'spellfile'.
        vim.opt.spellfile = { user_file, managed_file }
      end
    '';
  };
}
