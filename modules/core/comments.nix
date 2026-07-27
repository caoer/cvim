# Comments — `gc` toggling and TODO highlighting
#
# empty:   a buffer with no TODO-style keywords shows no highlights; `gc` still works on any filetype with a known commentstring.
# partial: a filetype whose treesitter grammar is absent falls back to Neovim's own commentstring — `gc` still comments, just without context awareness.
# error:   none reachable; a filetype with no commentstring at all leaves the line untouched rather than corrupting it.
#
# §6 ROW 6 — ts-comments, and the pin that is NO LONGER NEEDED.
#
# The row reads "ts-comments pinned ≥ 426303d until nixpkgs carries it". The
# condition has been met, so the pin is not carried.
#
# History: nixpkgs' ts-comments (2025-10-28) read `vim.opt.comments._info` to
# detect the default `comments` setting. `_info` was dropped from vim.opt option
# objects in Neovim 0.12, so every `gc` died with "attempt to index field
# '_info'". cnixvim pinned upstream 426303d, which switches to
# `nvim_get_option_info2`, and left a note to drop the pin once nixpkgs passed
# 2026-06-29.
#
# nixpkgs now ships ts-comments at rev a59d6092 (1.5.0-unstable-2026-06-29),
# and the fix is present in it — verified by reading the shipped source, not by
# comparing version strings:
#
#   lua/ts-comments/comments.lua:12
#   local opt = vim.api.nvim_get_option_info2("comments", { ... })
#
# So carrying an overrideAttrs pin here would pin cvim to an OLDER tree than
# nixpkgs already provides, for a bug that is fixed in both. The row is
# satisfied structurally — the crashing code is absent from the shipped
# plugin — and confirmed behaviourally with `gcc` in a running 0.12.4 editor.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins = {
      # Treesitter-aware commentstring: correct `gc` inside JSX, embedded Lua
      # in Vimscript, and the other places a single per-filetype commentstring
      # gets it wrong.
      ts-comments.enable = true;

      # Highlights TODO/FIXME/HACK/NOTE and makes them searchable. Note it
      # ships `:TodoTelescope`-style commands that need a picker — those belong
      # to the picker layer and are not wired here.
      todo-comments.enable = true;
    };
  };
}
