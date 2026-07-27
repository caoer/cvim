# Column guide — smartcolumn, which draws `colorcolumn` only when it is earned.
#
# A permanent colorcolumn is visual noise in a file that never approaches the
# limit. smartcolumn's default scope is the whole file: the column appears if any
# line in the buffer crosses the boundary, and stays hidden otherwise. Verified
# by reading `&colorcolumn` out of the running editor — a file whose longest line
# was 11 columns reported it empty, and a file with a 139-column line reported
# `80`.
#
# markdown, text and help are in smartcolumn's default `disabled_filetypes`, so
# prose gets no column guide even when it is long. That is the right default for
# prose that wraps, and it was confirmed rather than assumed: a 148-column
# markdown line still reported `&colorcolumn` empty.
#
# Editor-surface states:
#   empty   — no line crosses the boundary: no column drawn, which is the whole
#             point of the plugin rather than a degraded state.
#   partial — a disabled filetype gets no column regardless of line length.
#   error   — none reachable; the plugin only ever sets a window option.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.smartcolumn.enable) {
    plugins.smartcolumn = {
      enable = true;
      settings = lib.optionalAttrs (cfg.smartcolumn.column != null) {
        colorcolumn = toString cfg.smartcolumn.column;
      };
    };
  };
}
