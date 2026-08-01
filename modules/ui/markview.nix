# Markup rendering — markview, for reading markdown in the editor.
#
# `icon_provider = "mini"` points markview at the icon set this layer already
# ships rather than letting it load a second one. It is a declared option, so a
# typo is a build error rather than a silent fallback.
#
# Rendering is decoration only: headings, checkboxes, blockquotes, tables and
# fenced-code labels are drawn with extmarks and the buffer text is never
# rewritten. Colours come from the colorscheme, so the render follows an
# appearance flip — verified by capture, where the markdown body changes colour
# between night and day while the plain-text layout stays byte-identical.
#
# Editor-surface states:
#   empty   — a file with no markup gets no decorations at all: a plain text
#             buffer measured zero extmarks, so markview adds nothing rather than
#             adding an empty overlay.
#   partial — at 80 columns a wide table is fitted to the window by
#             markview-smart-tables (columns shrink, cells word-wrap, borders
#             intact); a long prose line soft-wraps as plain text.
#   error   — no treesitter parser for the buffer's language means the code-block
#             body renders unhighlighted inside a still-correct block frame.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.ui;

  # Vendored from ZT's fork, not upstream: upstream is small and low-traffic,
  # so the fork is the review gate — a version bump means re-reading the diff
  # there first, never tracking upstream HEAD blind. The fork + rev are
  # documented in the llm-wiki as a source. Pure Lua, no build step.
  markview-smart-tables = pkgs.vimUtils.buildVimPlugin {
    pname = "markview-smart-tables-nvim";
    version = "unstable-2026-06-22";
    src = pkgs.fetchFromGitHub {
      owner = "caoer";
      repo = "markview-smart-tables.nvim";
      rev = "01134a5bf48f1b7abe27b26a6b89262685bb309f";
      hash = "sha256-wDJY9+tQBZEFbzqUouITxjbLKLtHqm6mcRLxkVLIa+M=";
    };
    doCheck = false;
    meta.homepage = "https://github.com/caoer/markview-smart-tables.nvim";
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.markview.enable) {
    plugins.markview = {
      enable = true;
      settings.preview.icon_provider = "mini";

      # The full Obsidian surface — wikilinks, embeds, block refs, tags,
      # highlights, extended checkbox states, callouts, footnotes — ships
      # enabled at the pinned version; verified by extmark count on a file
      # exercising each one. The preset is the one piece that is opt-in: it
      # recolours callout lines to Obsidian's palette. `__raw` because a
      # preset is a lua call, not data.
      settings.markdown.block_quotes.__raw = ''require("markview.presets").block_quotes.obsidian'';

      # Deltas from the plugin defaults, settled live in
      # docs/markview-style.md. Everything the doc shows and this file does
      # not set — code block style "block", rounded table borders, list
      # wrap — is the default already.
      settings.markdown.list_items.shift_width = 2;
      settings.markdown.tables.strict = true;

      # Wide tables under 'wrap': stock markview bails when a wrapped table
      # is ≥90% of the window (renderers/markdown.lua, its own comment reads
      # "BUG, wrap breaks table rendering") — inline virt_text is positioned
      # by buffer column, and soft-wrap breaks at raw columns, so the borders
      # cannot survive a wrapped line. markview-smart-tables takes over the
      # table renderer: tables that fit keep the stock render, oversized ones
      # are re-emitted as virtual lines over the concealed source — columns
      # shrink widest-first, cells word-wrap, borders reuse the `parts`/`hl`
      # theme above. Fit options stay at the plugin defaults (wrap_width 0.9,
      # wrap_minwidth 5), so no setup() call.
      settings.renderers.markdown_table.__raw = ''
        function(buffer, item)
          require("markview-smart-tables").render(buffer, item)
        end
      '';

      # A fitted table is fully virtual, so the cursor is invisible while on
      # it. Hybrid mode is the escape hatch: in normal mode the node under
      # the cursor shows raw markdown — navigable, editable — and re-renders
      # on leave. "n" is the only mode where this can apply: markview's
      # default preview.modes is n/no/c, and insert already shows raw.
      settings.preview.hybrid_modes = [ "n" ];
    };

    extraPlugins = [ markview-smart-tables ];

    # How far markview lightens `Normal`'s background per element — lower is
    # dimmer. These are globals, not settings: markview reads them off `vim.g`
    # when it computes its highlight groups, so they survive the day/night
    # flip. markview's own dark branch is 0.15 / 0.15 / 0.2.
    globals = {
      markview_alpha = 0.02;
      markview_code_alpha = 0.02;
      markview_inline_code_alpha = 0.01;
    };

    # The shipped settings as data, for a session that has been experimenting.
    #
    # `markview.setup()` only ever merges (`vim.tbl_deep_extend "force"`), so
    # calling it again cannot take a style back out — the way home is to clear
    # `spec.config` and re-apply what the build passed. `docs/markview-style.md`
    # is where that is spelled as a runnable block.
    #
    # Generated from the EVALUATED attrs rather than from the literal above, so
    # a host that overrides `plugins.markview.settings` through `extendModules`
    # resets to its own config and not to cvim's. A table pasted into the doc
    # instead would be wrong the first time either one changed.
    extraFiles."lua/cvim/markview.lua".text = ''
      --- What cvim configured markview with.
      ---
      --- Generated by modules/ui/markview.nix. Do not edit.
      return {
        settings = ${lib.nixvim.toLuaObject config.plugins.markview.settings},
      }
    '';
  };
}
