# LSP and diagnostic keymaps.
#
# Split by what the binding needs to be useful, which is not the same split as
# "LSP or not":
#
#   lsp.keymaps  bind buffer-locally on LspAttach. Everything here is
#                meaningless without a server, so it should not exist on
#                buffers that have none.
#   keymaps      bind globally. Diagnostics come from linters as well as
#                servers, so these have to work on a buffer no server ever
#                attached to.
#
# Neovim 0.11+ already binds the LSP verbs it considers core — `grn` rename,
# `gra` code action, `grr` references, `gri` implementation, `grt` type
# definition, `gO` document symbols, `<C-S>` signature help in insert, and
# `]d`/`[d`/`]D`/`[D` for diagnostic motion. Those are deliberately NOT
# redefined here: rebinding a default to the same action only creates a second
# place to keep it correct. What follows is what neovim leaves unbound, plus
# ZT's `<leader>l` cluster.
#
# Every keymap carries a `desc`. U12 asserts this mechanically.
{ config, lib, ... }:
let
  cfg = config.cvim.lsp;

  # Prefer trouble's list when the picker layer supplied it, fall back to the
  # builtin lists when it did not. `plugins.trouble` belongs to the picker
  # layer, and the `server` profile is a real configuration that may not carry
  # it — so this degrades rather than errors, and never hard-requires the
  # module. Testing the command rather than `require` keeps this correct
  # whether trouble is eager or lazily loaded.
  diagnosticsList = scope: ''
    function()
      if vim.fn.exists(":Trouble") == 2 then
        vim.cmd("Trouble diagnostics toggle${lib.optionalString (scope == "buffer") " filter.buf=0"}")
      else
        vim.diagnostic.${if scope == "buffer" then "setloclist" else "setqflist"}()
      end
    end
  '';

  # Peek — inspect a definition or the reference set without leaving the
  # buffer. ZT gated the picker layer onto trouble's LSP modes for this and
  # rejected glance, so the modes are trouble's; the keys are this layer's.
  #
  # Same degradation rule as the lists: without trouble these jump using the
  # builtin, which is a worse experience but a working one. A peek key that
  # errors on a picker-less host would be a regression, not a feature.
  peek = mode: bufAction: ''
    function()
      if vim.fn.exists(":Trouble") == 2 then
        vim.cmd("Trouble ${mode} toggle")
      else
        vim.lsp.buf.${bufAction}()
      end
    end
  '';
in
{
  config = lib.mkIf cfg.enable {
    lsp.keymaps = [
      {
        key = "K";
        lspBufAction = "hover";
        options.desc = "Hover documentation";
      }
      {
        key = "gd";
        lspBufAction = "definition";
        options.desc = "Go to definition";
      }
      {
        key = "gD";
        lspBufAction = "declaration";
        options.desc = "Go to declaration";
      }
      {
        # Restart is hand-rolled because nvim-lspconfig no longer ships ANY
        # user command — no `:LspRestart`, no `:LspStart`, no `:LspInfo`. It
        # became a pure provider of `vim.lsp.config` defaults. `:LspRestart`
        # here would have evaluated clean and raised E492 on first press.
        #
        # Two measured facts shape the implementation. Stopping is not enough
        # on its own, and re-calling `vim.lsp.enable(name, true)` does NOT
        # bring the server back on an already-open buffer — it re-registers
        # the FileType autocmd and leaves existing buffers unattached. Firing
        # `FileType` again is what actually re-attaches, because that is the
        # event `vim.lsp.enable` hangs its attachment off.
        key = "<leader>lR";
        action.__raw = ''
          function()
            local bufnr = vim.api.nvim_get_current_buf()
            local clients = vim.lsp.get_clients({ bufnr = bufnr })
            if #clients == 0 then
              vim.notify("No language server attached to this buffer", vim.log.levels.WARN)
              return
            end

            local names = {}
            for _, client in ipairs(clients) do
              names[#names + 1] = client.name
              client:stop()
            end

            -- Wait for the stop to land rather than guessing a sleep; a
            -- re-fired FileType while the old client is still up is a no-op.
            vim.wait(2000, function()
              return #vim.lsp.get_clients({ bufnr = bufnr }) == 0
            end, 50)

            if vim.api.nvim_buf_is_valid(bufnr) then
              vim.api.nvim_exec_autocmds("FileType", { buffer = bufnr })
            end
            vim.notify("Restarted: " .. table.concat(names, ", "))
          end
        '';
        options.desc = "Restart language servers (buffer)";
      }
      {
        # `:checkhealth vim.lsp` is neovim's own report — attached clients,
        # their root dirs, capabilities and log path. It replaced `:LspInfo`.
        key = "<leader>li";
        action = "<CMD>checkhealth vim.lsp<CR>";
        options.desc = "Language server info";
      }
      {
        # Peek keys are `<leader>lp`/`<leader>lP` rather than a `g`-prefix
        # pair. A `gp`-prefixed peek would shadow vim's own `gp`/`gP` — paste
        # and leave the cursor after the pasted text — costing a working
        # builtin and adding a timeout delay to every use of it. `<leader>lp`
        # is also what ZT already presses for "preview definition" today.
        key = "<leader>lp";
        action.__raw = peek "lsp_definitions" "definition";
        options.desc = "Peek definition";
      }
      {
        key = "<leader>lP";
        action.__raw = peek "lsp_references" "references";
        options.desc = "Peek references";
      }
      {
        # Buffer-local so one noisy file can be quietened without losing hints
        # everywhere. Works regardless of `cvim.lsp.inlayHints`, which only
        # decides the starting state.
        key = "<leader>lh";
        action.__raw = ''
          function()
            local enabled = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
            vim.lsp.inlay_hint.enable(not enabled, { bufnr = 0 })
          end
        '';
        options.desc = "Toggle inlay hints (buffer)";
      }
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>ld";
        action.__raw = "function() vim.diagnostic.open_float({ scope = 'line' }) end";
        options.desc = "Line diagnostics";
      }
      {
        mode = "n";
        key = "<leader>lq";
        action.__raw = diagnosticsList "buffer";
        options.desc = "Diagnostics list (buffer)";
      }
      {
        mode = "n";
        key = "<leader>lQ";
        action.__raw = diagnosticsList "workspace";
        options.desc = "Diagnostics list (workspace)";
      }
      {
        # Buffer-local mute. The `zt` layer disables markdown diagnostics
        # wholesale; this is the same act, chosen per buffer at runtime.
        mode = "n";
        key = "<leader>lt";
        action.__raw = ''
          function()
            local enabled = vim.diagnostic.is_enabled({ bufnr = 0 })
            vim.diagnostic.enable(not enabled, { bufnr = 0 })
          end
        '';
        options.desc = "Toggle diagnostics (buffer)";
      }
    ];
  };
}
