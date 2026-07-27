# fff.nvim — the fast file finder (Rust-backed, frecency-ranked).
{ config, lib, ... }:
let
  cfg = config.cvim.picker;
in
{
  config = lib.mkIf cfg.enable {
    plugins.fff = {
      enable = true;

      settings = {
        # §6 row 1. fff's base_path defaults to `vim.fn.getcwd()`, and its Lua
        # layer is the ONLY binding that defaults this to true — the Rust C
        # ABI, Python and Node bindings all default it false
        # (crates/fff-c/src/ffi_types.rs, crates/fff-python/src/finder.rs).
        # Start nvim from $HOME with it on and fff indexes the whole home tree
        # into a resident in-memory index: measured 2026-07-25 on ZT's mac at
        # 387,511 files, 1.03 GiB RSS, 73 GiB of reads, still scanning after
        # 11.5h.
        #
        # The flag is a pre-flight refusal in the picker constructor, not a
        # walk filter (crates/fff-core/src/file_picker.rs:866), so `false`
        # turns that silent gigabyte into a loud error at the moment the
        # mistake is made.
        #
        # This lives on the freeform `settings.*` surface: a typo here
        # evaluates green and silently leaves the scan ON. It is verified at
        # runtime, not at eval — see the capture referenced in
        # ./default.nix's header.
        enable_home_dir_scanning = false;

        # Same refusal, one directory up. fff already defaults this false
        # (lua/fff/conf.lua:223), so this line pins a default rather than
        # changing one — deliberately, because row 1 is the receipt for what
        # happens when a default in this exact struct is trusted and later
        # differs from what you assumed.
        enable_fs_root_scanning = false;
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>ff";
        action.__raw = "function() require('fff').find_files() end";
        options.desc = "Find file (fff, frecency-ranked)";
      }
      {
        mode = "n";
        key = "<leader>fG";
        action.__raw = "function() require('fff').scan_files() end";
        options.desc = "Rescan file index (fff)";
      }
    ];
  };
}
