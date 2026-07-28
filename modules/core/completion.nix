# Completion — blink.cmp, snippets, and the Neovim-API type source
#
# empty:   no LSP attached and no buffer words — the menu simply does not open. Typing is unaffected.
# partial: LSP still starting — the menu shows buffer/path/snippet items and gains LSP items when it attaches; no error, no empty popup.
# error:   a source that throws is dropped by blink and the remaining sources still populate the menu.
#
# HOSTILE DEFAULT, DISARMED — `fuzzy.prebuilt_binaries.download`. Upstream
# defaults this to `true`, and blink's downloader resolves its write target
# from the plugin's OWN directory (`debug.getinfo` → `root_dir/target/release`,
# lua/blink/cmp/fuzzy/download/files.lua:11-14). Under Nix that directory is a
# read-only store path, so a download attempt is a write INTO THE STORE — the
# silent-write class the design law forbids, in the one place a plugin is most
# likely to do it. The nixpkgs build already ships libblink_cmp_fuzzy, so
# turning the downloader off costs nothing and converts a would-be store write
# into a loud, visible fallback.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
in
{
  config = lib.mkIf cfg.enable {
    plugins = {
      blink-cmp = {
        enable = true;
        settings = {
          # Blink's own `default` preset leaves `<Tab>` as snippet-jump-only,
          # so the insert menu is accepted with `<C-y>` and Tab falls through
          # to indent. ZT reads a visible menu as "Tab takes this one", which
          # is what `super-tab` binds: accept the selection, or jump the
          # snippet when one is active. `<C-n>`/`<C-p>` still navigate.
          keymap.preset = "super-tab";

          # The `:` line. blink takes it over by default
          # (config/modes/cmdline.lua) and its `cmdline` preset already puts
          # accept on `<Tab>`, which is the same reflex `super-tab` gives the
          # insert menu — so the takeover stays and the keymap is left alone.
          #
          # Two of its defaults are cut. `buffer` in `sources` offers words
          # from the file you are editing as command-line candidates, so typing
          # `:e` proposes prose; only `cmdline` belongs on the `:` line. Ghost
          # text writes a grey preview into the line before any key is pressed,
          # which reads as text you typed. Both are pure surprise, and neither
          # is load-bearing for completing a command.
          cmdline = {
            sources = [ "cmdline" ];
            completion.ghost_text.enabled = false;
          };

          fuzzy = {
            implementation = "prefer_rust";
            prebuilt_binaries.download = false;
          };

          sources.default = [
            "lsp"
            "path"
            "snippets"
            "buffer"
          ];
        };
      };

      # The snippet corpus `sources.snippets` reads from. Without it that
      # source is present but always empty.
      friendly-snippets.enable = true;

      # Feeds a Lua language server's workspace.library so `vim.*` and the
      # Neovim API resolve, and ships its own blink completion source
      # (lua/lazydev/integrations/blink.lua).
      #
      # Supports BOTH lua_ls and emmylua_ls — `supported_clients = { "lua_ls",
      # "emmylua_ls" }` in lua/lazydev/lsp.lua:6 — so it does not constrain
      # which Lua server the lang layer ships. It is inert until one of them
      # attaches: that is a value dependency on the LSP layer, not a
      # correctness one, and not a defect to be "fixed" here.
      lazydev.enable = true;
    };
  };
}
