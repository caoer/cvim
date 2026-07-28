# `<leader>uC` — pick a colorscheme with live preview, and keep the pick.
#
# The schemes come from `theme.nix`; this file is only the runtime switch. What
# it adds over snacks' own `colorschemes` picker is one line of state: the
# chosen name in `stdpath("state")/cvim-colorscheme`, re-applied at the next
# start. Without it every restart throws the choice away, which on a nix-built
# editor reads as "the theme cannot be changed" — the config is a read-only
# store path, so there is nowhere else for a runtime preference to live.
#
# STATE, NOT CONFIG, AND THAT IS THE DIVISION. `stdpath("state")` is per-machine
# and outside the store; the nix tree still owns which schemes EXIST and which
# one a fresh machine starts on. Delete the file (`<leader>uR`) and the editor is
# exactly what the flake says it is.
#
# WHY THE RESTORE RUNS FROM `extraConfigLua`. nixvim applies the configured
# scheme as `extraConfigVim` — `vim.cmd([[colorscheme tokyonight]])`, line ~238
# of the generated init.lua — while `extraConfigLua` lands around line 1700.
# Later means the restore wins; earlier would mean the default overwrote it.
# Both are before the first redraw, so there is no flash of the default theme.
# Read the order out of the built init.lua before moving this.
#
# The confirm handler is snacks' own (picker/config/sources.lua:126) plus the
# write. `picker.preview.state.colorscheme = nil` is load-bearing and looks like
# bookkeeping: the preview restores the pre-picker scheme when the window
# closes, and clearing it is what tells the preview the choice is now permanent.
# Dropping that line makes every confirm appear to do nothing.
#
# WHAT A PICK COSTS. The list holds family names and variant names side by side
# — `kanagawa` and `kanagawa-lotus` — and they are not the same choice. A family
# name keeps `theme.nix`'s terminal-follow; a variant name pins that appearance
# and leaves `&background` where it was. Verified: picking `kanagawa-lotus` in a
# dark terminal loads the light palette and holds it across the restart.
# `<leader>uR` is the way back.
#
# Editor-surface states:
#   empty   — no state file: nothing is applied and tokyonight from theme.nix
#             stands. This is a fresh machine, and it is not an error.
#   partial — the persisted scheme is not installed, e.g. a rebuild dropped the
#             plugin: `pcall` catches E185, `vim.notify` names the scheme and the
#             file, and the nix default stands. The file is deliberately NOT
#             deleted — a rebuild that puts the plugin back restores the pick,
#             and a silent delete would lose it permanently.
#   error   — the state directory is unwritable: the scheme is still applied to
#             the running editor and only the write is reported as a warning.
#             Losing persistence must not cost the user the pick they just made.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
  pickerOn = config.cvim.picker.enable;

  # One expression, both call sites. Written as lua rather than resolved in nix
  # because `stdpath("state")` is a runtime path — baking a build-time answer
  # would pin one machine's home directory into the store.
  stateFile = ''vim.fn.stdpath("state") .. "/cvim-colorscheme"'';

  # `theme.nix` forces this; reading it back keeps the reset target in one place.
  # The fallback is only reachable if this module is ever ungated from
  # `theme.enable`.
  defaultScheme = if config.colorscheme == null then "default" else config.colorscheme;
in
{
  config = lib.mkIf (cfg.enable && cfg.theme.enable && pickerOn) {
    extraConfigLua = ''
      do
        local file = ${stateFile}
        if vim.uv.fs_stat(file) then
          local name = (vim.fn.readfile(file, "", 1)[1] or ""):gsub("%s+$", "")
          if name ~= "" and not pcall(vim.cmd.colorscheme, name) then
            vim.notify(
              "colorscheme " .. name .. " is not installed — keeping ${defaultScheme}."
                .. " <leader>uR clears " .. file,
              vim.log.levels.WARN
            )
          end
        end
      end
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>uC";
        action.__raw = ''
          function()
            Snacks.picker.colorschemes({
              confirm = function(picker, item)
                picker:close()
                if not item then
                  return
                end
                picker.preview.state.colorscheme = nil
                vim.schedule(function()
                  if not pcall(vim.cmd.colorscheme, item.text) then
                    vim.notify("colorscheme " .. item.text .. " failed to load", vim.log.levels.ERROR)
                    return
                  end
                  local file = ${stateFile}
                  if not pcall(vim.fn.writefile, { item.text }, file) then
                    vim.notify(
                      "set " .. item.text .. " for this session; could not write " .. file,
                      vim.log.levels.WARN
                    )
                  end
                end)
              end,
            })
          end
        '';
        options = {
          desc = "Colorscheme (kept across restarts)";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>uR";
        action.__raw = ''
          function()
            local file = ${stateFile}
            if vim.uv.fs_stat(file) and vim.fn.delete(file) ~= 0 then
              vim.notify("could not delete " .. file, vim.log.levels.ERROR)
              return
            end
            vim.cmd.colorscheme("${defaultScheme}")
            vim.notify("colorscheme reset to ${defaultScheme} — following the terminal")
          end
        '';
        options = {
          desc = "Reset colorscheme (follow terminal)";
          silent = true;
        };
      }
    ];
  };
}
