# yazi.nvim — the file explorer, in a floating window.
#
# This layer's only explorer. snacks.explorer is explicitly disabled in
# ./snacks-picker.nix; see the comment there for why that `false` matters.
{ config, lib, ... }:
let
  cfg = config.cvim.picker;
in
{
  config = lib.mkIf cfg.enable {
    plugins.yazi = {
      enable = true;

      # Every yazi setting is left at its upstream default on purpose. The
      # hostile-defaults grep over yazi.nvim 13.9.0's settings surface for
      # scan|watch|poll|index|auto.?(save|write|update)|network|telemetry
      # returned exactly one hit, `yazi_floating_window_zindex` — a window
      # stacking order, not a behaviour. Nothing here needs correcting.
      #
      # `open_for_directories` stays false (upstream default): flipping it
      # makes yazi hijack every `nvim <dir>` invocation, which is a change to
      # how the editor starts, not a picker-layer concern.
      settings = { };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>e";
        action = "<cmd>Yazi<cr>";
        options.desc = "Explorer at current file (yazi)";
      }
      {
        mode = "n";
        key = "<leader>E";
        action = "<cmd>Yazi cwd<cr>";
        options.desc = "Explorer at cwd (yazi)";
      }
    ];
  };
}
