# Treesitter — syntax, indent, and the sticky-context header
#
# empty:   a filetype with no grammar gets Neovim's regex syntax; nothing errors, highlighting is just plainer.
# partial: grammar present but a query missing — that construct stays unhighlighted, the rest of the buffer is fine.
# error:   a stale node range during a re-parse would spam the decoration provider; the bounds guard below turns that into one skipped frame.
#
# §6 ROW 9 — the bounds guard. This is one of exactly three things carried over
# from cnixvim, and it is carried because it has an incident behind it rather
# than because cnixvim had it.
#
# Upstream bug neovim/neovim#38303 (root #37091): the highlighter's decoration
# provider can read a node's byte range via nvim_buf_get_text BEFORE the tree
# re-parses after a buffer edit — classically `dd` in a larger file. The stale
# range is out of bounds, nvim_buf_get_text throws, and the editor spams
#   Error in decoration provider ... (ns=nvim.treesitter.highlighter): Index out of bounds
# Core catches it and self-corrects on the next redraw, so the damage is noise
# rather than corruption — but it is continuous noise. The bug is present on
# stable and nightly alike, so there is no version to move to.
#
# `vim.treesitter.get_node_text` is the single Lua entry point the highlighter
# and injection-language resolution both call, and internal callers resolve it
# at call time — so wrapping it here makes an out-of-bounds read return "" for
# that one stale frame instead of throwing. Remove once #38303 lands bounds
# checks upstream.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins = {
      treesitter = {
        enable = true;
        settings = {
          highlight.enable = true;
          indent.enable = true;
        };

        # THE CORE GRAMMAR FLOOR — and the reason it must exist here.
        #
        # nixvim's `grammarPackages` defaults to `allGrammars`: 326 grammars,
        # roughly 267 MB. The lang layer narrows it, but only when it is
        # enabled — with `cvim.lang.enable = false` NO module defines the
        # option, the nixvim default goes live, and the SERVER profile ships
        # all 326. That is the one profile whose entire purpose is a small
        # closure. Measured on this branch before this list existed: default
        # 326, server 326.
        #
        # The floor belongs to core rather than to the lang layer or to
        # profiles.nix, because core is what enables treesitter: the unit that
        # turns a feature on owns its resting cost. `grammarPackages` is a
        # `listOf`, so these merge with the per-language definitions the lang
        # modules add rather than fighting them.
        #
        # What is in it: the grammars the editor needs for its OWN operation
        # and for files you open regardless of whether any language toolchain
        # is installed. A server with no lang layer still edits configs, shell
        # scripts, notes and git messages — that is what a "comfortable remote
        # editor" has to cover.
        grammarPackages = with config.plugins.treesitter.package.builtGrammars; [
          # Neovim's own surface: config, help, and treesitter queries
          lua
          vim
          vimdoc
          query
          # cvim is a Nix project, and the fleet's configs are Nix
          nix
          # Ubiquitous on every host
          bash
          # Notes, READMEs, agent output
          markdown
          markdown_inline
          # The config formats that are most of remote editing
          json
          yaml
          toml
          # Git workflow, plus regex highlighting embedded in other grammars
          regex
          diff
          gitcommit
          git_rebase
          gitignore
        ];
      };

      # The sticky header showing which function/class the top of the window is
      # inside. Earns its place in files longer than a screen, which is most of
      # them.
      treesitter-context.enable = true;
    };

    # Runs before any plugin setup, so the wrapper is in place before the
    # highlighter can call through it.
    extraConfigLuaPre = ''
      do
        local ts = vim.treesitter
        if ts and type(ts.get_node_text) == "function" and not ts.__bounds_guarded then
          local orig = ts.get_node_text
          vim.g.ts_bounds_guard_catches = 0
          ts.get_node_text = function(...)
            local ok, res = pcall(orig, ...)
            if ok then
              return res
            end
            vim.g.ts_bounds_guard_catches = (vim.g.ts_bounds_guard_catches or 0) + 1
            return ""
          end
          ts.__bounds_guarded = true
        end
      end
    '';
  };
}
