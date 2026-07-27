# gitsigns — the sign column, hunk staging, and blame.
#
# Prefix note: the conventional gitsigns prefix is `<leader>h`, and it is NOT
# available here. U9b binds `<leader>h/j/k/l` to window navigation
# (modules/zt/keymaps.nix), so a `<leader>hs` here would not merely collide —
# it would tax every single window-left with a `timeoutlen` wait while vim
# looked for a second key. Everything git lives under `<leader>g` instead,
# which no other unit binds.
#
# `]c` / `[c` keep their builtin meaning. Both are real diff-mode motions, so
# the mappings below fall through to the builtin whenever `&diff` is set and
# only navigate gitsigns hunks outside it. Binding them bare would have cost
# the motion inside diffview's own diff buffers — this layer's other half.
{ config, lib, ... }:
let
  cfg = config.cvim.git;
in
{
  config = lib.mkIf cfg.enable {
    # gitsigns spawns `git` for every attach, blame and diff. nixvim's module
    # declares git as a plugin dependency, and this line is what turns that
    # declaration into a package on the wrapper's PATH. Without it the binary
    # is inherited from the ambient shell — which works on ZT's mac and is
    # exactly the failure U5 shipped and fixed for `rg`/`fd`.
    dependencies.git.enable = true;

    plugins.gitsigns = {
      enable = true;

      settings = {
        # Pinned upstream defaults, not decoration: the module header claims a
        # sign-column gutter and no background blame, and a claim resting on
        # an unstated default rests on nothing.
        signcolumn = true;
        numhl = false;
        linehl = false;
        word_diff = false;

        # Blame is on demand (`<leader>gB`), never ambient. `current_line_blame`
        # runs a blame on BufEnter/CursorMoved/CursorMovedI behind a 1000ms
        # timer of gitsigns' own — one `git blame` subprocess per cursor
        # settle, for a decoration nobody asked for. `<leader>gt` toggles it
        # on for the session when you do want it.
        current_line_blame = false;

        # The gitdir watcher stays ON, and it is the reason signs survive a
        # branch switch made outside the editor. It is one `uv.new_fs_event`
        # on `.git/HEAD` per cwd plus one per attached buffer's gitdir —
        # local inotify/kqueue only. gitsigns issues no `fetch`, `push` or
        # `ls-remote` anywhere in its source, so this costs nothing on a host
        # with restricted egress.
        watch_gitdir = {
          enable = true;
          follow_files = true;
        };

        # Both upstream defaults, pinned because they bound the work. 40000
        # lines is where gitsigns stops diffing a file, and untracked files
        # get no signs — so a fresh file shows an empty gutter rather than
        # every line marked added.
        max_file_length = 40000;
        attach_to_untracked = false;

        # Worth knowing before you read the gutter as stale: after staging a
        # hunk its sign does NOT disappear. gitsigns moves it to a separate
        # `gitsigns_signs_staged` namespace under `GitSignsStagedChange`, so
        # the same glyph stays put in a different colour. Measured on the
        # shipped build by diffing the ANSI — staged renders 70;124;123 and
        # unstaged 179;246;192, two distinct RGB values, so the two states
        # are legible rather than merely different in theory.
      };
    };

    keymaps =
      let
        # `]c` and `[c` are diff-mode builtins. Inside a diff — which includes
        # every diffview buffer — run the builtin; outside one, walk hunks.
        navHunk = direction: ''
          function()
            if vim.wo.diff then
              vim.cmd.normal({ "${if direction == "next" then "]c" else "[c"}", bang = true })
            else
              require("gitsigns").nav_hunk("${direction}")
            end
          end
        '';
      in
      [
        {
          mode = "n";
          key = "]c";
          action.__raw = navHunk "next";
          options.desc = "Next git hunk (or diff change)";
        }
        {
          mode = "n";
          key = "[c";
          action.__raw = navHunk "prev";
          options.desc = "Previous git hunk (or diff change)";
        }

        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>gs";
          action = "<cmd>Gitsigns stage_hunk<cr>";
          options.desc = "Stage hunk (or selection)";
        }
        {
          mode = [
            "n"
            "v"
          ];
          key = "<leader>gr";
          action = "<cmd>Gitsigns reset_hunk<cr>";
          options.desc = "Reset hunk (or selection)";
        }
        {
          mode = "n";
          key = "<leader>gS";
          action = "<cmd>Gitsigns stage_buffer<cr>";
          options.desc = "Stage buffer";
        }
        {
          mode = "n";
          key = "<leader>gR";
          action = "<cmd>Gitsigns reset_buffer<cr>";
          options.desc = "Reset buffer";
        }
        {
          mode = "n";
          key = "<leader>gu";
          action = "<cmd>Gitsigns undo_stage_hunk<cr>";
          options.desc = "Undo stage hunk";
        }
        {
          mode = "n";
          key = "<leader>gp";
          action = "<cmd>Gitsigns preview_hunk<cr>";
          options.desc = "Preview hunk";
        }
        {
          mode = "n";
          key = "<leader>gB";
          action.__raw = ''function() require("gitsigns").blame_line({ full = true }) end'';
          options.desc = "Blame line (full)";
        }
        {
          mode = "n";
          key = "<leader>gL";
          action = "<cmd>Gitsigns blame<cr>";
          options.desc = "Blame file (side window)";
        }
        {
          mode = "n";
          key = "<leader>gt";
          action = "<cmd>Gitsigns toggle_current_line_blame<cr>";
          options.desc = "Toggle inline blame";
        }
      ];
  };
}
