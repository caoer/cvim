# Text objects, surround, pairs, and indentation
#
# empty:   a buffer with no matching text object — the operator simply does nothing and the buffer is unchanged.
# partial: a filetype without a treesitter grammar loses mini.ai's function/class targets but keeps its bracket and quote ones.
# error:   none reachable; every module here is an editing operator, so a miss is a no-op rather than a failure.
#
# ZT gated this set on 2026-07-27 (decisions/u3-mini-module-set.md). All five
# mini modules ship. The measured input that made it a taste question rather
# than a budget one: mini.nvim is ONE package (v0.18.0), so five modules cost
# exactly what one costs and U12 should expect no closure saving from trimming
# them.
#
# `s` BELONGS TO FLASH, so mini.surround lives on `gs` — the same split
# khanelivim uses (gsa/gsd/gsr…). The previous "s claimed twice, they coexist"
# note was wrong in a way the lab could not see: flash creates no default
# keymaps, so the "coexistence" was mini.surround's s-prefix plus its bare-`s`
# <Nop> guard, and the designed flash jump never existed. Found on ZT's first
# daily-drive day (U13). Accepted consequence unchanged: plain `s`
# (substitute-char) is shadowed by the flash binding; `cl` does the same thing.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;

  # Filetypes the house indent must NOT touch: their hard tabs are mandated by
  # the format or its formatter, not chosen by taste. A space-indented Makefile
  # fails with `missing separator`, and gofmt rewrites Go back on every save —
  # so overriding these produces broken files, not differently-styled ones.
  #
  # Sourced by reading every runtime ftplugin that issues `setlocal
  # noexpandtab` in the Neovim this build ships (0.12.4). It is a snapshot, not
  # a derived value: a Neovim bump can add one, and the symptom is a file whose
  # tool rejects it. `man` is on the list because it is a rendered view.
  tabMandated = [
    "changelog"
    "flexwiki"
    "gdscript"
    "go"
    "gomod"
    "hare"
    "haredoc"
    "idris2"
    "make"
    "man"
    "scdoc"
  ];

  tabMandatedLua = lib.concatMapStringsSep ", " (ft: "[${builtins.toJSON ft}] = true") tabMandated;
in
{
  config = lib.mkIf cfg.enable {
    plugins.mini = {
      enable = true;
      modules = {
        # Treesitter-aware `a`/`i` text objects plus next/last variants
        # (`cin(` = change in NEXT parens). Purely additive — it extends the
        # existing a/i motions rather than rebinding anything.
        ai = { };

        # `gsaiw"` to wrap, `gsd"` to delete, `gsr"'` to replace. The `gs`
        # prefix (not mini's default `s`) is what frees `s` for flash — see
        # the header note. `gS` (splitjoin, below) is a distinct key.
        surround = {
          mappings = {
            add = "gsa";
            delete = "gsd";
            find = "gsf";
            find_left = "gsF";
            highlight = "gsh";
            replace = "gsr";
            update_n_lines = "gsn";
          };
        };

        # Auto-closes brackets and quotes as you type.
        pairs = { };

        # vim-unimpaired-style `[`/`]` navigation pairs: `[b`/`]b` buffers,
        # `[d`/`]d` diagnostics, `[c`/`]c` comments, and around a dozen more.
        bracketed = { };

        # `gS` toggles a single-line construct to multi-line and back. Earns
        # its place in nix attrsets, Go structs and JSON.
        splitjoin = { };
      };
    };

    # Indentation. ZT's call on his first daily-drive week: ONE Tab width
    # everywhere, chosen here, rather than a width guessed per buffer.
    #
    # vim-sleuth used to own this and is now gone. It was doing its job — but
    # its job made `<Tab>` a variable: it set `softtabstop=-1` and a per-file
    # `shiftwidth`, so Tab moved 2 columns in a .nix file and 4 in the justfile.
    # A key whose width depends on the buffer cannot be typed by reflex, and
    # that is what a daily driver needs from Tab. Adapting to foreign repos is
    # the accepted cost.
    #
    # Neovim's editorconfig support is BUILT IN and nixvim enables it by
    # default (`editorconfig.enable`, modules/editorconfig.nix), so a repo that
    # states its own style in `.editorconfig` still overrides these. That is
    # the deliberate escape hatch left in place of sleuth's guessing: declared
    # style is honoured, undeclared style is ours. The reliance is stated so a
    # later unit does not disable it believing it unused.
    #
    # `softtabstop = -1` means "follow shiftwidth", so the values cannot drift
    # apart: change `shiftwidth` and Tab, `>>` and `<<` all follow.
    #
    # `tabstop` is deliberately ABSENT and left at Neovim's 8. It is a global,
    # and the tab-mandated filetypes below inherit whatever it holds — setting
    # it to 2 here rendered Go and Makefile tabs 2 columns wide, which is the
    # one visible change those files were promised they would not get. The
    # house `tabstop = 2` is applied buffer-locally in the autocmd instead.
    opts = {
      expandtab = true;
      shiftwidth = 2;
      softtabstop = -1;
    };

    # `opts` above is only the baseline. Neovim ships 42 runtime ftplugins that
    # `setlocal` their own indentation, and a FileType autocmd runs AFTER them,
    # so markdown would still hand you 4 spaces without this. Re-applying the
    # values buffer-locally is what makes the width one number instead of 42.
    autoGroups.cvim_indent.clear = true;

    autoCmd = [
      {
        event = [ "FileType" ];
        group = "cvim_indent";
        desc = "Re-apply the house indent over the runtime ftplugin defaults";
        callback.__raw = ''
          function(args)
            local buf = args.buf
            local mandated = { ${tabMandatedLua} }

            -- Hard-tab format. It still needs normalising, not just skipping:
            -- the global `shiftwidth = 2` and `softtabstop = -1` reach here
            -- too, and under `noexpandtab` they make Tab insert two SPACES
            -- into a file whose tool demands a tab. Zero for both means one
            -- indent level is exactly one tab, `tabstop` columns wide, which
            -- is what `go.vim` and `make.vim` already set for themselves.
            -- `tabstop` is left untouched so gdscript keeps its 4 and man its 8.
            if mandated[vim.bo[buf].filetype] then
              vim.bo[buf].expandtab = false
              vim.bo[buf].shiftwidth = 0
              vim.bo[buf].softtabstop = 0
              return
            end

            vim.bo[buf].expandtab = true
            vim.bo[buf].shiftwidth = 2
            vim.bo[buf].tabstop = 2
            vim.bo[buf].softtabstop = -1
          end
        '';
      }
    ];
  };
}
