# `cvim.picker` — Finding things.
{ lib, ... }:
{
  options.cvim.picker.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      Finding things: the picker, the file explorer, and the diagnostics
      list.
    '';
  };

  options.cvim.picker.yazi.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    example = false;
    description = ''
      The yazi file explorer, and with it the `yazi` binary.

      `false` is a supported shape, not a placeholder: the rest of the layer
      — snacks.picker, fff, trouble — keeps working without it, and
      `<leader>e` / `<leader>E` are simply not bound. Turn it off where the
      closure matters more than the explorer does: the plugin carries the
      `yazi` binary and its transitive ffmpeg-headless, which U12 measured
      at 358,933,912 bytes on x86_64-linux — the second-largest single
      lever in the server profile, after the language toolchains.

      Has no effect unless `cvim.picker.enable` is also true.
    '';
  };
}
