# Leader-surface parity — the khanelivim muscle-memory keys that need no new
# plugin. Quit/write cluster, comment toggle, command history, the buffers
# group (bufferline is already here), and a curated toggles group.
#
# Scope rule: ONLY bindings whose backing feature already ships. Groups that
# need a plugin cvim does not carry (debug, harpoon, REPL, test, ...) are a
# ZT-gated decision, not a key binding — do not add them here.
#
# Sourced from the old runtime's keymap dump (U13 day-1 drive), curated rather
# than copied: khanelivim's 67-entry toggle tree collapses to the dozen that
# earn daily use; window-nav <leader>hjkl stays dropped (ZT's own decision,
# arrows carry it); <leader>ww (save) already matches the old w-group shape.
#
# Editor-surface states:
#   empty   — every binding acts on the current buffer/editor state; with
#             nothing to act on (no buffer, no diagnostics) each is a no-op or
#             its feature's own message, never an error.
#   partial — ui layer disabled: the buffers group is absent rather than
#             present-and-broken (BufferLine commands would not exist).
#   error   — a toggle that reads state it cannot write (e.g. inlay hints with
#             no LSP attached) reports through vim.notify, not a traceback.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
  bufferKeys = config.cvim.ui.enable && config.cvim.ui.bufferline.enable;
  pickerKeys = config.cvim.picker.enable;

  toggleMap = key: desc: fn: {
    mode = "n";
    key = "<leader>u${key}";
    action.__raw = ''
      function()
        ${fn}
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
    keymaps = [
      # ── quit / write cluster (khanelivim singles, verbatim) ───────────────
      {
        mode = "n";
        key = "<leader>q";
        action = "<cmd>confirm quit<cr>";
        options = {
          desc = "Quit";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>Q";
        action = "<cmd>quit!<cr>";
        options = {
          desc = "Force quit";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>W";
        action = "<cmd>write!<cr>";
        options = {
          desc = "Force write";
          silent = true;
        };
      }

      # ── comment toggle — remaps the gc operator khanelivim style ──────────
      {
        mode = "n";
        key = "<leader>/";
        action = "gcc";
        options = {
          desc = "Toggle comment line";
          silent = true;
          remap = true;
        };
      }
      {
        mode = "x";
        key = "<leader>/";
        action = "gc";
        options = {
          desc = "Toggle comment selection";
          silent = true;
          remap = true;
        };
      }
    ]
    ++ lib.optionals pickerKeys [
      {
        mode = "n";
        key = "<leader>:";
        action.__raw = ''
          function()
            Snacks.picker.command_history()
          end
        '';
        options = {
          desc = "Command History";
          silent = true;
        };
      }
    ]
    # ── buffers group — bufferline's own operations ─────────────────────────
    ++ lib.optionals bufferKeys [
      {
        mode = "n";
        key = "<leader>b[";
        action = "<cmd>BufferLineCyclePrev<cr>";
        options = {
          desc = "Previous buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>b]";
        action = "<cmd>BufferLineCycleNext<cr>";
        options = {
          desc = "Next buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bc";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options = {
          desc = "Close all buffers but current";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bp";
        action = "<cmd>BufferLinePick<cr>";
        options = {
          desc = "Pick Buffer";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bP";
        action = "<cmd>BufferLineTogglePin<cr>";
        options = {
          desc = "Pin buffer toggle";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>bd";
        action = "<cmd>bdelete<cr>";
        options = {
          desc = "Delete buffer";
          silent = true;
        };
      }
    ]
    # ── toggles group — curated from khanelivim's 67 ────────────────────────
    ++ [
      (toggleMap "w" "Toggle wrap" "vim.wo.wrap = not vim.wo.wrap")
      (toggleMap "s" "Toggle spell" "vim.wo.spell = not vim.wo.spell")
      (toggleMap "l" "Toggle line numbers" "vim.wo.number = not vim.wo.number")
      (toggleMap "r" "Toggle relative numbers" "vim.wo.relativenumber = not vim.wo.relativenumber")
      (toggleMap "c" "Toggle conceal" "vim.wo.conceallevel = vim.wo.conceallevel == 0 and 2 or 0")
      (toggleMap "d" "Buffer Diagnostics toggle" ''
        local buf = vim.api.nvim_get_current_buf()
        local on = vim.diagnostic.is_enabled({ bufnr = buf })
        vim.diagnostic.enable(not on, { bufnr = buf })
        vim.notify("Buffer diagnostics " .. (on and "off" or "on"))
      '')
      (toggleMap "D" "Global Diagnostics toggle" ''
        local on = vim.diagnostic.is_enabled()
        vim.diagnostic.enable(not on)
        vim.notify("Diagnostics " .. (on and "off" or "on"))
      '')
      (toggleMap "h" "Toggle Inlay Hints" ''
        local on = vim.lsp.inlay_hint.is_enabled({})
        vim.lsp.inlay_hint.enable(not on)
        vim.notify("Inlay hints " .. (on and "off" or "on"))
      '')
      (toggleMap "b" "Toggle dark/light background"
        ''vim.o.background = vim.o.background == "dark" and "light" or "dark"''
      )
    ];
  };
}
