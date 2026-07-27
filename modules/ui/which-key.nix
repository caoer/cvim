# Keymap hints — which-key, with the buffer jumps kept out of the popup.
#
# `<leader>1` through `<leader>9` are nine bindings that mean one thing, and left
# visible they push the mnemonic groups off the popup. They stay bound and stay
# discoverable through `:map`; they are only hidden from the hint window.
#
# Verified at runtime, because a spec that did nothing would look identical at
# eval: the nine jumps are registered with their descriptions (read back from
# `nvim_get_keymap`), a control binding added under the same prefix DOES appear in
# the popup, and none of the nine appear beside it. So the popup renders, and the
# spec is what is keeping them out of it.
#
# Editor-surface states:
#   empty   — a prefix with nothing visible under it renders no popup at all,
#             rather than an empty frame. Observed: with only the hidden jumps
#             bound, the leader popup does not appear.
#   partial — more entries than rows: which-key paginates rather than truncating.
#   error   — a malformed spec entry is which-key's own startup error; it does not
#             silently drop the whole spec.
{ config, lib, ... }:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.whichKey.enable) {
    plugins.which-key = {
      enable = true;
      settings.spec =
        map (n: {
          __unkeyed-1 = "<leader>${toString n}";
          hidden = true;
        }) (lib.range 1 9)
        # Named groups — without these the popup shows anonymous "+N keymaps"
        # where khanelivim showed named groups, which reads as missing keys
        # even when the bindings exist (U13 day-1 drive). Names only label
        # prefixes that have bindings; which-key drops empty ones.
        ++ map
          (g: {
            __unkeyed-1 = "<leader>${g.k}";
            group = g.name;
          })
          [
            { k = "a"; name = "AI Assistant"; }
            { k = "b"; name = "Buffers"; }
            { k = "f"; name = "Find"; }
            { k = "g"; name = "Git"; }
            { k = "j"; name = "JSON"; }
            { k = "l"; name = "LSP"; }
            { k = "s"; name = "SOPS"; }
            { k = "S"; name = "Sessions"; }
            { k = "t"; name = "Tools"; }
            { k = "u"; name = "UI/UX"; }
            { k = "x"; name = "Diagnostics"; }
            { k = "y"; name = "Yank"; }
            { k = "z"; name = "Language"; }
          ];
    };
  };
}
