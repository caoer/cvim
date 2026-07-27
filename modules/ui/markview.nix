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
#   partial — at 80 columns a wide table renders inside the window and a long
#             line gets neovim's own `@@@` continuation marker; nothing overlaps.
#   error   — no treesitter parser for the buffer's language means the code-block
#             body renders unhighlighted inside a still-correct block frame.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.markview.enable) {
    plugins.markview = {
      enable = true;
      settings.preview.icon_provider = "mini";
    };
  };
}
