# Color literals — oklch-color-picker.nvim, which paints them in the buffer
# and edits them in a graphical picker.
#
# One plugin, two surfaces. Every `#6c7086`, `rgb()`, `hsl()`, `oklch()` and
# hex literal is highlighted in its own color while editing, and `<leader>tc`
# opens the value under the cursor in a native picker window. The picker works
# in Oklch space, where dragging one channel holds perceived lightness steady —
# the property that makes "nudge this statusline gray" a one-axis edit instead
# of a hue hunt. With no color under the cursor the same key opens the picker
# empty and inserts the choice at the cursor (`fallback_open`).
#
# THE DOWNLOADER IS OFF, AND THAT IS THE NIX WIRING. Upstream resolves its two
# Rust artifacts — the picker app and a parser cdylib — by downloading GitHub
# release binaries into stdpath("data") at runtime. A nix-built editor must not
# depend on a mutable binary in the home directory, and does not need to: the
# nixpkgs `oklch-color-picker` package ships both artifacts, and nixvim's pin
# holds it at 2.3.4 — the exact version this plugin's downloader.lua expects,
# because nixpkgs updates the pair together. So:
#
#   app     `utils.exec` is set to the store path before setup(). That field is
#           the plugin's own resolution cache (utils.lua: executable_full_path
#           returns it first, before looking in stdpath("data")). It is internal
#           API, so a plugin bump that renames it degrades loudly rather than
#           silently: the pick reports "Picker executable not found at <data
#           dir>" and highlighting is untouched.
#   parser  `package.cpath` gains the store lib dir before setup(). cargo names
#           the cdylib `libparser_lua_module.dylib` on darwin and `.so` on
#           linux; BOTH patterns are appended unconditionally, so this module
#           carries no platform condition (platform-guard) and the dead pattern
#           costs one failed stat per require.
#   off     `auto_download = false` is what disables the downloader; with it
#           false the version files in stdpath("data") are never consulted.
#
# The parser is load-bearing for highlighting, not an accelerator: highlight.lua
# refuses to enable at all when the library fails to load ("Couldn't load
# parser library", ERROR — read the on_downloaded callback). There is no Lua
# fallback. That is why the cpath line sits beside setup() rather than being an
# optimization to add later.
#
# Eager, like the rest of this layer (see ./default.nix): highlighting must
# attach to the first buffer, and the plugin's own setup defers its heavy work
# behind autocmds — measured by upstream at <0.01 ms per no-color edit.
#
# Editor-surface states:
#   empty   — a buffer with no color literals gets no extmarks and the plugin
#             is invisible. Not an error.
#   partial — no display (plain SSH): highlighting works; a pick spawns the app,
#             which exits nonzero, and the plugin logs that at DEBUG — the key
#             appears to do nothing. Raise log_level when diagnosing this.
#   error   — exec path wrong (plugin bump renamed the cache field): reported
#             through the plugin's log on pick, not a traceback, and not at
#             startup. Parser failed to load: "Couldn't load parser library"
#             at ERROR on startup, highlighting stays off, the pick still works.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.ui;
  app = pkgs.oklch-color-picker;
in
{
  config = lib.mkIf (cfg.enable && cfg.colorPicker.enable) {
    extraPlugins = [ pkgs.vimPlugins.oklch-color-picker-nvim ];

    extraConfigLua = ''
      do
        -- Store paths instead of the runtime downloader; see the header.
        require("oklch-color-picker.utils").exec = "${app}/bin/oklch-color-picker"
        package.cpath = package.cpath
          .. ";${app}/lib/lib?.dylib"
          .. ";${app}/lib/lib?.so"
        require("oklch-color-picker").setup({
          auto_download = false,
        })
      end
    '';

    keymaps = [
      {
        mode = "n";
        key = "<leader>tc";
        action.__raw = ''
          function()
            require("oklch-color-picker").pick_under_cursor({ fallback_open = {} })
          end
        '';
        options = {
          desc = "Color picker (edit under cursor, or insert)";
          silent = true;
        };
      }
    ];
  };
}
