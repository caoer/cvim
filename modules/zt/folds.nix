# Marker folds ({{{ }}}) and the `zT` fold-method toggle.
#
# One buffer-sticky switch instead of two merged fold systems. `toml` and
# `yaml` opt in on FileType; every other buffer starts on whatever the editor
# default is and flips with `zT`.
#
# empty:   a buffer with no `{{{`/`}}}` markers folds to nothing — foldmethod
#          is "marker" and every line sits at foldlevel 0, so the file reads
#          flat. Verified: results/captures/u9a/u9a-folds-toml-marker.ansi.
# partial: only balanced marker pairs fold. An unclosed `{{{` folds to end of
#          file — vim's marker semantics, not a defect introduced here.
# error:   `zT` in a buffer with no visible window, or after the buffer is
#          wiped, is a silent no-op — the re-assert autocmd drops out on the
#          `nvim_buf_is_valid` and `bufwinid == -1` guards rather than raising.
#
# The re-assert autocmd exists because a fold-method owner that force-sets
# `foldmethod=expr` on BufWinEnter/LspAttach (cnixvim inherited exactly that
# from khanelivim's lsp.nix) runs async, after modelines and FileType. It is
# deliberately kept even though cvim's own lsp layer is specified not to
# clobber: it makes "marker folds survive an LSP attach" true regardless of
# what the lsp layer does later.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLuaPre = ''
      function _G.zt_apply_marker_folds(collapse)
        vim.wo.foldmethod = "marker"
        vim.wo.foldtext = "foldtext()"
        if collapse then vim.wo.foldlevel = 0 end
      end

      function _G.zt_toggle_foldmethod()
        if vim.b.zt_marker_folds then
          vim.b.zt_marker_folds = nil
          vim.wo.foldmethod = "expr"
          vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
          vim.wo.foldlevel = 99
          vim.notify("folds: treesitter")
        else
          vim.b.zt_marker_folds = true
          _G.zt_apply_marker_folds(true)
          vim.notify("folds: marker {{{ }}}")
        end
      end
    '';

    autoCmd = [
      {
        # toml/yaml default to marker folds; any buffer can flip with zT.
        event = [ "FileType" ];
        pattern = [
          "toml"
          "yaml"
        ];
        callback.__raw = "function(args) vim.b[args.buf].zt_marker_folds = true end";
      }
      {
        # Re-assert AFTER any async fold-method owner has had its turn.
        event = [
          "FileType"
          "BufWinEnter"
          "LspAttach"
        ];
        callback.__raw = ''
          function(args)
            local bufnr = args.buf
            if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end
            if not vim.b[bufnr].zt_marker_folds then return end
            local collapse = args.event == "FileType"
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(bufnr) then return end
              local win = vim.fn.bufwinid(bufnr)
              if win == -1 then return end
              vim.api.nvim_win_call(win, function()
                _G.zt_apply_marker_folds(collapse)
              end)
            end)
          end
        '';
      }
    ];

    keymaps = [
      {
        mode = "n";
        key = "zT";
        action.__raw = "function() _G.zt_toggle_foldmethod() end";
        options = {
          desc = "Toggle fold method (marker/treesitter)";
          silent = true;
        };
      }
    ];
  };
}
