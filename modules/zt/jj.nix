# Jujutsu — `<leader>j` group over the jj CLI.
#
# ZT runs jj on his daily repos and asked for the group back on the U13 day-1
# drive. There is no jj plugin worth its provenance yet, so this drives the
# CLI directly: read commands open in a snacks float (interactive = false so
# the window survives process exit); describe takes its message through
# vim.ui.input rather than nesting an $EDITOR inside a terminal inside nvim.
#
# `<leader>jv` (JSON Graph Explorer, zt/plugins.nix) predates this group and
# stays — same cohabitation the old editor had.
#
# Editor-surface states:
#   empty   — outside a jj repo every command shows jj's own "not a jj repo"
#             error text in the float; nothing crashes.
#   partial — none: jj is in extraPackages, so the binary is closure-carried.
#   error   — a failing jj command shows its stderr in the float, loud.
{ config, lib, pkgs, ... }:
let
  cfg = config.cvim.editor;

  jterm = key: desc: cmd: {
    mode = "n";
    key = "<leader>j${key}";
    action.__raw = ''
      function()
        Snacks.terminal(${cmd}, { interactive = false })
      end
    '';
    options = {
      desc = desc;
      silent = true;
    };
  };
in
{
  config = lib.mkIf cfg.enable {
    extraPackages = [ pkgs.jujutsu ];

    keymaps = [
      (jterm "j" "jj status" ''{ "jj", "st" }'')
      (jterm "l" "jj log" ''{ "jj", "log" }'')
      (jterm "d" "jj diff" ''{ "jj", "diff" }'')
      (jterm "n" "jj new" ''{ "jj", "new" }'')
      (jterm "p" "jj git push" ''{ "jj", "git", "push" }'')
      (jterm "f" "jj git fetch" ''{ "jj", "git", "fetch" }'')
      {
        mode = "n";
        key = "<leader>je";
        action.__raw = ''
          function()
            vim.ui.input({ prompt = "jj describe -m " }, function(msg)
              if msg and msg ~= "" then
                Snacks.terminal({ "jj", "describe", "-m", msg }, { interactive = false })
              end
            end)
          end
        '';
        options = {
          desc = "jj describe (message)";
          silent = true;
        };
      }
    ];
  };
}
