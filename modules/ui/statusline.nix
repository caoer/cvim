# Statusline — lualine, taking its palette from the live tokyonight palette.
#
# `theme = "auto"` is the whole colour mechanism. lualine ships no tokyonight
# theme of its own, so tokyonight's `lua/lualine/themes/tokyonight.lua` wins;
# that file reads the live palette with `style` unset, which follows
# `&background` and therefore OSC 11. lualine re-runs its own `setup()` on
# `ColorScheme` and on `OptionSet background` through an autocmd it registers
# itself, so a live appearance flip restyles this line with no glue from us.
# That is why there is no hex literal below and no `ColorScheme` handler.
#
# Truncation is chosen, not inherited. lualine has no priority system and no
# flexible components: nothing degrades this line for you. Every breakpoint
# below is an explicit `cond` or `fmt` against `vim.o.columns`, and with
# `globalstatus = true` that is the terminal width regardless of how the window
# is split. At 80 columns:
#
#   mode          shown, abbreviated to 3 characters (`NORMAL` -> `NOR`)
#   branch        shown, name capped at 12 characters with a trailing ellipsis
#   filename      shown, relative path; leading directories compress to their
#                 first letter, then the whole string is capped to the budget
#   diagnostics   shown, never truncated — it is the signal, and it renders
#                 nothing at all when the buffer is clean
#   lsp           shown, counts only; server names appear from 100 columns
#   filetype      hidden below 100 columns
#   progress      shown
#   location      shown, never truncated
#
# 48 is the reserve: the columns everything other than the filename needs at
# its widest. Both filename stages spend `columns - 48`.
#
# Deliberately absent:
#   encoding, fileformat — utf-8 and unix are the always-case here. They cost
#     about 12 columns to say nothing, and those columns are the filename's.
#   diff — lualine's built-in diff spawns `git diff` on BufEnter and
#     BufWritePost. The no-spawn wiring is gitsigns, which is Unit 6 and not in
#     the closure yet, so this ships without it rather than shipping a
#     component that renders nothing and cannot be verified. When U6 lands:
#     `{ __unkeyed-1 = "diff"; source.__raw = "function() return vim.b.gitsigns_status_dict end"; }`
#     A function `source` is also what stops lualine registering the spawn
#     autocmds at all.
#
# The `lsp` component reads Unit 7's `cvim.lsp` module, which answers "which
# servers were expected for this filetype, and which of them attached". A
# statusline cannot derive that: `vim.lsp.get_clients` reports only what did
# attach. Four states, rendered four ways, never collapsed —
#
#   none      cvim configures no server for this filetype. Renders nothing.
#             This is the normal answer, and it is the answer for EVERY
#             filetype until U8a ships the first server.
#   ok        everything expected attached. `lsp <names>`, section colour.
#   partial   some attached, some did not. `lsp 1/2`, DiagnosticWarn.
#   missing   none of the expected servers attached. `lsp 0/2`, DiagnosticWarn.
#
# Two traps this component is built around:
#
#   The require is guarded. The `server` profile can build with
#   `cvim.lsp.enable = false`, and then `cvim.lsp` is simply absent. That is a
#   degrade path, not an error, so it renders nothing.
#
#   `plugins.lspconfig` is a HARD DEPENDENCY of the signal, not just a source
#   of server definitions: `vim.lsp.config.<name>.filetypes` is nil without it,
#   so every filetype answers `none` forever. Dropping lspconfig as a closure
#   optimisation gives a green build, a clean eval, and a permanently silent
#   indicator. This comment is the only place that failure announces itself.
#
# Attach is asynchronous, so a healthy buffer honestly reports `missing` for a
# moment after opening. The fix is the `LspAttach`/`LspDetach` autocmd below,
# which redraws when the truth changes. It is deliberately NOT a debounce: a
# guessed grace period is too short for a slow server and pointless for a fast
# one, and it converts a visible flicker into a statusline that is confidently
# wrong for N milliseconds on every file open.
#
# The autocmd is used rather than lualine's `refresh.events`, because
# `refresh.events` REPLACES the default list rather than extending it —
# measured against the shipped plugin, not inferred: setting it to
# `{ LspAttach, LspDetach }` leaves exactly those two and drops all ten
# defaults, including `ModeChanged` and `CursorMoved`. That would freeze every
# other component while looking correct on LSP. Same shape as lz.n's
# after-option, which replaces where the author assumed it appends — and which
# CI grep-lints for that reason. An autocmd touches no defaults.
#
# Editor-surface states:
#   empty   — no file open: filename reads `[No Name]`, branch and diagnostics
#             render nothing, mode and location still hold the line.
#   partial — a component's data source is absent (no repo, no diagnostics):
#             that component renders as nothing, never as an error or a stale
#             value. The line closes up around it.
#   error   — a component's Lua raises: lualine catches it and reports it
#             through `:LualineNotices` rather than tearing down the line.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf cfg.enable {
    # Attach is async, so the `lsp` component's answer changes without any
    # keystroke. lualine's default refresh events do not include these two, and
    # setting `refresh.events` would replace them rather than add to them.
    autoCmd = [
      {
        event = [
          "LspAttach"
          "LspDetach"
        ];
        callback.__raw = ''
          function()
            require("lualine").refresh()
          end
        '';
        desc = "Redraw the statusline when an LSP client attaches or detaches";
      }
    ];

    plugins.lualine = {
      enable = true;

      settings = {
        options = {
          # A theme name, not a palette. See the header — this is the entire
          # day/night path.
          theme = "auto";

          # The 80x24 baseline, and the single highest-leverage setting here.
          # Without it a horizontal split at 80 columns gives each statusline
          # about 38 columns and starves every component; with it every
          # component sees the full terminal width. It also makes
          # `vim.o.columns` the right number for every breakpoint below.
          globalstatus = true;
        };

        sections = {
          lualine_a = [
            {
              __unkeyed-1 = "mode";
              # Three characters keeps every mode distinct — VIS, V-L, V-B,
              # V-R, S-L, S-B all survive — while giving the filename back up
              # to six columns.
              fmt = ''
                function(name)
                  if vim.o.columns >= 90 then
                    return name
                  end
                  return name:sub(1, 3)
                end
              '';
            }
          ];

          lualine_b = [
            {
              __unkeyed-1 = "branch";
              # Below 60 columns the branch is the first thing worth losing:
              # you already know what you checked out, and you do not know
              # where the cursor is.
              cond.__raw = ''
                function()
                  return vim.o.columns >= 60
                end
              '';
              # Branch names are unbounded. `u4b-statusline` is 14 columns of
              # an 80-column line, and CI branches are worse.
              fmt = ''
                function(name)
                  if vim.o.columns >= 120 then
                    return name
                  end
                  local len = vim.fn.strchars(name)
                  if len <= 12 then
                    return name
                  end
                  return vim.fn.strcharpart(name, 0, 11) .. "…"
                end
              '';
            }
          ];

          lualine_c = [
            {
              __unkeyed-1 = "filename";
              # Relative to the cwd. The path is what disambiguates
              # `default.nix` from the other eleven `default.nix` files.
              path = 1;
              # Stage one, lualine's own: compress leading directories to
              # their first letter (`modules/ui/x.nix` -> `m/u/x.nix`) until
              # the whole string fits `columns - 48`. It never touches the
              # basename, so this alone can still overflow.
              shorting_target = 48;
              # Stage two, the hard cap: keep the tail, which carries the
              # basename and the extension. Without this a single long
              # filename pushes `location` off the right edge and neovim
              # truncates the line wherever it happens to land.
              fmt = ''
                function(name)
                  local budget = math.max(12, vim.o.columns - 48)
                  local len = vim.fn.strchars(name)
                  if len <= budget then
                    return name
                  end
                  return "…" .. vim.fn.strcharpart(name, len - budget + 1)
                end
              '';
            }
          ];

          lualine_x = [
            {
              __unkeyed-1 = "diagnostics";
              # `nvim_diagnostic` is every namespace, so linter output counts
              # here exactly like LSP output. `coc` is in lualine's default
              # list and cvim will never ship coc.
              sources = [ "nvim_diagnostic" ];
            }
            {
              # Unit 7's expected-servers signal. See the header for the four
              # states and why none of them may be folded into another.
              __unkeyed-1.__raw = ''
                function()
                  local ok, cvim_lsp = pcall(require, "cvim.lsp")
                  if not ok then
                    return ""
                  end
                  local s = cvim_lsp.status()
                  if s.state == "none" then
                    return ""
                  end
                  local wide = vim.o.columns >= 100
                  if s.state == "ok" then
                    if wide then
                      return "lsp " .. table.concat(s.attached, " ")
                    end
                    return "lsp"
                  end
                  local text = ("lsp %d/%d"):format(#s.expected - #s.missing, #s.expected)
                  if wide then
                    local names = {}
                    for _, entry in ipairs(s.missing) do
                      names[#names + 1] = entry.name
                    end
                    text = text .. " " .. table.concat(names, " ")
                  end
                  -- A highlight group, not a colour. It follows the appearance
                  -- for the same reason everything else on this line does.
                  return "%#DiagnosticWarn#" .. text
                end
              '';
            }
            {
              __unkeyed-1 = "filetype";
              # Mostly restates the extension the filename already shows.
              # First to go when the line gets tight.
              cond.__raw = ''
                function()
                  return vim.o.columns >= 100
                end
              '';
            }
          ];

          lualine_y = [
            {
              __unkeyed-1 = "progress";
              cond.__raw = ''
                function()
                  return vim.o.columns >= 70
                end
              '';
            }
          ];

          lualine_z = [ "location" ];
        };
      };
    };
  };
}
