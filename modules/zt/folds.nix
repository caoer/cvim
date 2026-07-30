# Fold policy — treesitter expr folds by default, marker folds ({{{ }}}) as a
# buffer-sticky opt-in, and the `zT` toggle between them.
#
# empty:   a filetype without a treesitter grammar folds to nothing — the
#          foldexpr returns 0 for every line, so the file reads flat. A
#          marker-opted buffer with no `{{{`/`}}}` markers likewise reads
#          flat. Verified: results/captures/u9a/u9a-folds-toml-marker.ansi.
# partial: only what the grammar exposes as foldable nodes folds. In marker
#          buffers only balanced pairs fold; an unclosed `{{{` folds to end of
#          file — vim's marker semantics, not a defect introduced here.
# error:   `zT` in a buffer with no visible window, or after the buffer is
#          wiped, is a silent no-op — the re-assert autocmd drops out on the
#          `nvim_buf_is_valid` and `bufwinid == -1` guards rather than raising.
#
# THE DEFAULT IS THIS FILE'S TO STATE. The lsp layer refuses to touch folds
# (modules/lsp/default.nix), which is correct — but cnixvim's folding WAS
# exactly that khanelivim clobber, so dropping the clobber without a stated
# replacement left every code buffer on foldmethod=manual: za/zc dead, folding
# "gone" (ZT, 2026-07-30). The replacement is the behavior the previous
# runtime had, housed in the fold layer instead of the LSP layer: expr folds
# via vim.treesitter.foldexpr(), open on entry (foldlevel 99), for every
# buffer that does not opt into markers.
#
# LSP foldexpr (`v:lua.vim.lsp.foldexpr()`) is deliberately NOT layered on
# top, though khanelivim upgraded to it per-client on LspAttach. One fold
# source means the editor default and the zT toggle's "treesitter" arm are
# the same thing rather than approximately the same thing, and no autocmd
# has to arbitrate which foldexpr a window is currently on. Revisit only if
# a language's folds are visibly wrong under its grammar.
#
# foldtext is empty — the 0.10+ transparent form: a closed fold renders its
# first line with normal syntax highlighting under the Folded background,
# which is the light version of what fold plugins ship. Marker buffers keep
# classic foldtext(); its "+-- N lines: title ---" summary is the point of
# markers.
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
    # The editor-wide default. The marker path overrides these per window;
    # foldlevelstart puts a window back at "open" when a non-marker buffer
    # replaces a collapsed marker one in the same window.
    opts = {
      foldmethod = "expr";
      foldexpr = "v:lua.vim.treesitter.foldexpr()";
      foldtext = "";
      foldlevel = 99;
      foldlevelstart = 99;
    };

    # `w:zt_marker_window` marks windows whose fold options THIS file wrote.
    # foldmethod is window-local, so a window that showed a marker buffer
    # would hand `marker` to the next buffer it shows. The restore autocmd
    # undoes only our own writes — a buffer whose modeline sets marker folds
    # carries no window mark and is left alone.
    extraConfigLuaPre = ''
      function _G.zt_apply_marker_folds(collapse)
        vim.wo.foldmethod = "marker"
        vim.wo.foldtext = "foldtext()"
        if collapse then vim.wo.foldlevel = 0 end
        vim.w.zt_marker_window = true
      end

      function _G.zt_apply_default_folds()
        vim.wo.foldmethod = "expr"
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldtext = ""
        vim.w.zt_marker_window = nil
      end

      function _G.zt_toggle_foldmethod()
        if vim.b.zt_marker_folds then
          vim.b.zt_marker_folds = nil
          _G.zt_apply_default_folds()
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
      {
        # Restore the default when a NON-marker buffer enters a window whose
        # fold options we set to marker (see the w:zt_marker_window note).
        event = [ "BufWinEnter" ];
        callback.__raw = ''
          function(args)
            local bufnr = args.buf
            if not (bufnr and vim.api.nvim_buf_is_valid(bufnr)) then return end
            if vim.b[bufnr].zt_marker_folds then return end
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(bufnr) then return end
              local win = vim.fn.bufwinid(bufnr)
              if win == -1 then return end
              if not vim.w[win].zt_marker_window then return end
              vim.api.nvim_win_call(win, function()
                _G.zt_apply_default_folds()
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
