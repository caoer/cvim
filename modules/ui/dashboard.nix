# Startup screen — snacks.dashboard.
#
# ZT chose this over mini-starter on 2026-07-27 for the look, knowing the costs;
# see decisions/u4a-dashboard.md in the session directory. The banner and the keys
# menu are what he approved, so the header is left at snacks' default.
#
# TWO THINGS HERE ARE LOAD-BEARING AND LOOK OPTIONAL.
#
# First, `sections`. snacks' default preset is { header, keys, startup }, and its
# `startup` section calls `require("lazy.stats")` with no guard
# (snacks/dashboard.lua:1095). cvim has no lazy.nvim, so the default
# preset throws E5108 on every startup — observed, not theorised. Naming the
# sections explicitly and omitting `startup` is the entire fix. Do not "simplify"
# this back to the default.
#
# Second, `notifier.enabled = false`. snacks' setup does
#   opts[k].enabled = opts[k].enabled == nil or opts[k].enabled
# over every key in opts, so mentioning a snacks module is the same act as
# enabling it, and absence means ON rather than OFF for anything named. This layer
# owns the `notifier` key (the picker layer owns `picker` and `explorer`) and
# deliberately does not use it: notifications go through noice + nvim-notify in
# notifications.nix, and two notification backends would fight over vim.notify.
# The `false` is the mechanism that keeps it off, not a comment about intent.
#
# `image` is deliberately not mentioned here — image.nix owns that key, as the
# unit decisions/u4a-snacks-image.md deferred to. Naming it here would enable
# it outside that module's gate.
#
# The picker-backed keys are conditional on `cvim.picker.enable` because they call
# `Snacks.dashboard.pick`, which needs a picker from the picker layer. Four of
# snacks' eight default keys are wrong for cvim, so the list is rewritten rather
# than inherited: `Config` opened the config directory nixvim removes from
# runtimepath and `Lazy` is meaningless here. `Restore Session` was dropped for
# needing a session manager cvim did not ship; core/sessions.nix ships one now
# (U13 daily-drive), so the key is back, gated on that layer.
#
# Editor-surface states:
#   empty   — no recent files and no picker: the banner and the unconditional keys
#             still render; the dashboard never renders as a blank buffer.
#   partial — picker layer disabled: the picker-backed keys are absent rather than
#             present-and-broken. If a picker call ever does fail,
#             `Snacks.dashboard.pick` ends in `Snacks.notify.error("No picker
#             found …")` — loud, not silent (dashboard.lua:773).
#   error   — opening a file argument skips the dashboard entirely, which is
#             snacks' own behaviour and not a failure.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
  pickerKeys = config.cvim.picker.enable;
  sessionKey = config.cvim.editor.enable;
in
{
  config = lib.mkIf (cfg.enable && cfg.dashboard.enable) {
    plugins.snacks = {
      enable = true;

      settings = {
        notifier.enabled = false;

        dashboard = {
          enabled = true;

          sections = [
            { section = "header"; }
            {
              section = "keys";
              gap = 1;
              padding = 1;
            }
          ];

          preset.keys =
            lib.optionals pickerKeys [
              {
                icon = " ";
                key = "f";
                desc = "Find File";
                action = ":lua Snacks.dashboard.pick('files')";
              }
              {
                icon = " ";
                key = "g";
                desc = "Find Text";
                action = ":lua Snacks.dashboard.pick('live_grep')";
              }
              {
                icon = " ";
                key = "r";
                desc = "Recent Files";
                action = ":lua Snacks.dashboard.pick('oldfiles')";
              }
            ]
            ++ lib.optionals sessionKey [
              {
                icon = " ";
                key = "s";
                desc = "Restore Session";
                action = ":lua require('persistence').load()";
              }
            ]
            ++ [
              {
                icon = " ";
                key = "n";
                desc = "New File";
                action = ":ene | startinsert";
              }
              {
                icon = " ";
                key = "q";
                desc = "Quit";
                action = ":qa";
              }
            ];
        };
      };
    };
  };
}
