# diffview — reviewing diffs, file history, and resolving merge conflicts.
#
# This layer ships NO dedicated conflict plugin, and diffview is the reason.
# git-conflict.nvim was the plan's candidate; nixpkgs marks it unfree because
# the upstream repo carries no LICENCE file at all, so `nix build` refuses it
# outright. diffview's merge-tool already binds the same vocabulary inside a
# 3-way layout — `]x` / `[x` to walk conflicts, `<leader>co` / `ct` / `cb` /
# `ca` to choose ours / theirs / base / all, and the capitalised variants for
# the whole file. ZT ruled drop on 2026-07-27; see the U6 card.
#
# Those conflict bindings are diffview's own buffer-local defaults. They are
# not repeated below, because re-declaring them here would put two owners on
# one binding and both would drift.
{ config, lib, ... }:
let
  cfg = config.cvim.git;
in
{
  config = lib.mkIf cfg.enable {
    plugins.diffview = {
      enable = true;

      # Both panels ship a FIXED size, and both of them are the width- and
      # height-sensitive surface in this layer. Measured at 80x24, which is
      # the SSH reality:
      #
      #   file panel          35 of 80 columns — 44% of the terminal, leaving
      #                       ~21 columns per diff side. Not enough to read a
      #                       line of code, let alone compare two.
      #   file history panel  16 of 24 rows — leaving 6 rows of diff under it.
      #
      # `win_config` accepts a function and diffview re-evaluates it on open
      # and on resize (`vim.is_callable(self.config_producer)`, ui/panel.lua),
      # so these follow the terminal instead of pinning one size. The wide
      # values are upstream's; only the narrow branch is new.
      settings = {
        file_panel.win_config.__raw = ''
          function()
            return {
              type = "split",
              position = "left",
              width = vim.o.columns < 100 and 22 or 35,
            }
          end
        '';

        file_history_panel.win_config.__raw = ''
          function()
            return {
              type = "split",
              position = "bottom",
              height = vim.o.lines < 30 and 10 or 16,
            }
          end
        '';
      };

      # diffview's icon lookup is LAZY — `get_file_icon` pcalls
      # `require("nvim-web-devicons")` on the first file entry it draws, and
      # when that fails it emits a warning long enough to trigger the
      # `Press ENTER` prompt. Measured: a blocking prompt on the first
      # `:DiffviewOpen` of every session with no icon provider present.
      #
      # The ui layer supplies one (mini.icons with `mockDevIcons`), but it is
      # gated on `cvim.ui.enable` and `cvim.ui.icons.enable`, so this layer
      # cannot assume it. The check is deferred to `VimEnter` rather than run
      # here, because at setup time the provider's own registration may not
      # have run yet — the answer would be a race, and the losing side is a
      # build that silently has no icons.
      luaConfig.post = ''
        vim.api.nvim_create_autocmd("VimEnter", {
          once = true,
          desc = "diffview: disable file icons when no provider registered",
          callback = function()
            if not pcall(require, "nvim-web-devicons") then
              require("diffview.config").get_config().use_icons = false
            end
          end,
        })
      '';
    };

    # All three are leader-prefixed, and the middle two are the reason this
    # note exists. Bare `gh` and `gH` are real vim builtins — Select mode,
    # charwise and linewise. Binding them directly would shadow working
    # motions AND add a `timeoutlen` wait to every remaining use of `g`,
    # because vim would have to see whether a second key follows. cnixvim
    # binds all three leader-prefixed (zt-extras.nix:237-239); the plan's
    # `<leader>gd / gh / gH` shorthand reads as if only the first carries the
    # leader, and it does not.
    keymaps = [
      {
        mode = "n";
        key = "<leader>gd";
        action = "<cmd>DiffviewOpen<cr>";
        options.desc = "Diffview: working tree";
      }
      {
        mode = "n";
        key = "<leader>gh";
        action = "<cmd>DiffviewFileHistory %<cr>";
        options.desc = "Diffview: file history (current file)";
      }
      {
        mode = "n";
        key = "<leader>gH";
        action = "<cmd>DiffviewFileHistory<cr>";
        options.desc = "Diffview: file history (branch)";
      }
      {
        mode = "n";
        key = "<leader>gq";
        action = "<cmd>DiffviewClose<cr>";
        options.desc = "Diffview: close";
      }
    ];
  };
}
