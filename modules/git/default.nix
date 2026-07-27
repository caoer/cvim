# The `git` layer
#
# Signs, diffs, conflict resolution, repository browsing.
#
# Implements `cvim.git.*`, declared in `../options/git.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# Ships: gitsigns (signs, hunk staging, blame), diffview (diff review, file
# history, AND merge-conflict resolution), snacks lazygit / gitbrowse / gh.
# Three candidates were evaluated and rejected by ZT on 2026-07-27 — see the
# U6 card for the evidence behind each:
#
#   git-conflict  unbuildable. nixpkgs marks it unfree because the upstream
#                 repo carries no LICENCE file at all. diffview's merge tool
#                 binds the same vocabulary, so nothing is lost.
#   hunk.nvim     an EXTERNAL difftool driver. Its whole surface is
#                 `:DiffEditor <left> <right>`, meant to be launched by
#                 `git difftool -t hunk` via a gitconfig cvim cannot write.
#                 Unreachable from inside the editor.
#   git-worktree  its only UI is a telescope extension, and cvim ships
#                 snacks.picker. Also 3 of the 5 options nixvim exposes for
#                 it are silent no-ops against the shipped 2.1.0.
#
# All bindings live under `<leader>g`. The conventional gitsigns prefix
# `<leader>h` is NOT available: U9b binds `<leader>h/j/k/l` to window
# navigation, so a hunk binding there would tax every window-left with a
# `timeoutlen` wait. `]c` / `[c` keep their builtin diff-mode meaning through
# an explicit passthrough.
#
# Editor-surface states — each verified in a running editor on aarch64-darwin
# against a disposable scratch repo, never a live one. Captures under
# results/captures/u6/ in the session directory:
#
#   empty    A directory that is no git repository at all: the layer is
#            silent. gitsigns sets no `b:gitsigns_status_dict` and no
#            `g:gitsigns_head`, draws no signs, and writes NOTHING to
#            `:messages` — measured as zero message lines against a control
#            that deliberately raised one, so the silence is a reading and
#            not an absence of instrument. `:DiffviewOpen` prints one line,
#            "Not a repo (or any parent), or no supported VCS adapter!", and
#            opens no tab (`tabpagenr("$")` stays 1).
#            [state-a-not-a-repo.ansi, state-a-diffview-not-a-repo.ansi]
#
#   partial  Two shapes, both distinguishable and neither an error.
#            A repo with no commits: gitsigns attaches and reports `gitdir`
#            and `root` with `head = ""` — so a statusline consuming the
#            branch renders empty, not a failure. No signs, because
#            `attach_to_untracked = false`. [state-b1-repo-no-commits.ansi]
#            A repo mid-conflict: the conflict markers themselves render as
#            ordinary add/change hunks in the gutter, and `:DiffviewOpen`
#            opens the 3-way merge tool — "Conflicts (1)", `U a.txt`, with
#            OURS / LOCAL / THEIRS side by side. `<leader>co` resolves the
#            conflict and the markers disappear.
#            [state-b2-conflict-buffer.ansi, state-b2-diffview-merge-tool.ansi,
#             state-b2-conflict-resolved-ours.ansi]
#
#   error    The "git binary absent" state is STRUCTURALLY UNREACHABLE here,
#            not merely unobserved: `dependencies.git.enable` puts git in the
#            closure. Measured by launching with `PATH=/nonexistent` — git,
#            lazygit and gh all still resolved to store paths and gitsigns
#            attached normally. [state-c1-empty-ambient-path.ansi]
#            An unreachable remote is equally a non-event, because nothing in
#            this layer polls one. gitsigns and diffview issue no `fetch`,
#            `push` or `ls-remote` anywhere in their source, and gitbrowse
#            builds its URL from `git remote -v` locally — verified against
#            an origin that does not exist, which produced the correct URL
#            and no network call. The only two bindings that reach the
#            network are `<leader>gi` / `<leader>gP`, and only when pressed.
#            [state-c2-hunk-staged-unreachable-remote.ansi]
#
# Narrow pane (80x24, SSH reality): both of diffview's panels ship a FIXED
# size that does not survive it — 35 of 80 columns for the file panel, 16 of
# 24 rows for the file history panel. Both are made to follow the terminal in
# ./diffview.nix. After the change the file panel takes 22 columns, leaving
# ~28 per diff side, and no rendered line exceeds 80 columns.
# [state-h-diffview-80x24.ansi]
{
  imports = [
    ./gitsigns.nix
    ./diffview.nix
    ./snacks-git.nix
  ];
}
