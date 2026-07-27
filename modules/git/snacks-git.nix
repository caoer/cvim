# snacks git entry points — lazygit, gitbrowse, and the GitHub CLI.
#
# Sole owner of `plugins.snacks.settings.lazygit`, `.gitbrowse` and `.gh`.
# The picker layer owns `.picker` / `.explorer` and the ui layer owns
# `.image` / `.dashboard` / `.notifier`; nix merges the attrsets, so the three
# layers never collide.
#
# None of these three is in snacks' event-driven setup table (`bigfile`,
# `image`, `quickfile`, `indent`, `explorer`, `words`, `dashboard`, `scroll`,
# `input`, `scope`, `picker`). They are pure on-demand calls, so nothing here
# runs until a keymap below is pressed. That is also why no `enabled = true`
# appears: nothing reads `.enabled` for these modules, so writing it would be
# a setting that looks load-bearing and is not.
{ config, lib, ... }:
let
  cfg = config.cvim.git;
in
{
  config = lib.mkIf cfg.enable {
    # Both binaries are hard dependencies of the keymaps below, declared here
    # rather than inherited from the ambient shell. `lazygit` absent means
    # `<leader>gg` opens a terminal that exits immediately; `gh` absent means
    # `<leader>gi` renders an empty list. Neither failure says why.
    dependencies = {
      lazygit.enable = true;
      gh.enable = true;
    };

    plugins.snacks = {
      enable = true;

      settings.lazygit = {
        # snacks writes a lazygit theme file derived from the LIVE highlight
        # groups every time the float opens, so lazygit follows a dark<->light
        # appearance flip with no baked hexes on our side. The write target is
        # `stdpath("cache")/lazygit-theme.yml` — under `$XDG_CACHE_HOME`, a
        # real writable path, never a store path.
        configure = true;

        # `nvim-remote` makes lazygit's `e` open the file in THIS neovim
        # instead of nesting a second one inside the float. Upstream default,
        # pinned because the alternative is a nested editor you cannot exit.
        config.os.editPreset = "nvim-remote";
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>gg";
        action.__raw = "function() Snacks.lazygit() end";
        options.desc = "lazygit";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>gb";
        action.__raw = "function() Snacks.gitbrowse() end";
        options.desc = "Open in browser (repo, file, or selection)";
      }
      # The only two bindings in this layer that reach the network, and both
      # only when pressed. `gh` talks to api.github.com; on a host with
      # restricted egress they fail with the CLI's own error and nothing else
      # in the layer notices.
      {
        mode = "n";
        key = "<leader>gi";
        action.__raw = "function() Snacks.gh.issue() end";
        options.desc = "GitHub issues";
      }
      {
        mode = "n";
        key = "<leader>gP";
        action.__raw = "function() Snacks.gh.pr() end";
        options.desc = "GitHub pull requests";
      }
    ];
  };
}
