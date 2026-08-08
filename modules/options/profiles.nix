# Profile cascade: `cvim.profile` picks a shape, the shape sets area defaults.
#
# A profile only ever writes `mkDefault`, so picking a profile never costs you
# the ability to override one option inside it. `null` is a real profile value:
# it means "no cascade — every area keeps the default it declares".
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim;
in
{
  options.cvim.profile = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.enum [
        "default"
        "server"
      ]
    );
    default = null;
    example = "server";
    description = ''
      Which shape of cvim to build.

      - `"default"` — the workstation editor: every area on.
      - `"server"` — a comfortable remote editor: no language toolchains, so
        the closure stays small enough to ship to small hosts.
      - `null` — no cascade. Every area keeps its own declared default; use
        this when you are composing the areas yourself.

      The `lab` package is `"default"` plus the scratch layer in `lab/`; it is
      not a profile, because nothing in `lab/` may ever reach a real build.
    '';
  };

  # Servers get a text editor, not a toolchain host. `lang` carries the heavy
  # closures and is the reason the `server` shape exists at all.
  #
  # This is the cascade's seed, not its final form: each area that needs a
  # different server default adds its row here.
  config = lib.mkIf (cfg.profile == "server") {
    cvim.lang.enable = lib.mkDefault false;

    # Image rendering carries mermaid-cli + imagemagick, measured at 479 MiB
    # (decisions/u4a-snacks-image.md) — the same closure-size reason cnixvim
    # force-disabled snacks.image on its server profile.
    cvim.ui.image.enable = lib.mkDefault false;

    # These three rows hold the SAME 1.21 GB of clang/llvm/apple-sdk, so any one
    # of them alone reads near zero and only the combination moves. Together they
    # take aarch64-darwin `server` from 2,261,694,280 B to 761,696,608 B.
    # Arms, hashes and the retainer graph: results/darwin-server-closure.md.
    #
    # git is here because nixvim's LUALINE module declares `dependencies = ["git"]`
    # for its branch component — `cvim.git.enable = false` cannot remove it.
    # gitMinimal keeps that component working and drops git-p4's python3 shebang
    # and git-cvsserver's perl shebang, which are the only reason a text editor
    # retains an Apple SDK.
    dependencies.git.package = lib.mkDefault pkgs.gitMinimal;

    # Remote-plugin providers for languages this profile does not ship. python3
    # pulls apple-sdk directly; ruby pulls clang. Nothing in cvim uses either.
    withPython3 = lib.mkDefault false;
    withRuby = lib.mkDefault false;

    # CLOSURE ROW — 358,933,912 B on x86_64-linux (884,335,464 -> 1,243,269,376
    # with it back on). Full report: results/u12-closure-startup.md.
    #
    # nixvim's yazi module declares `dependencies = [ "yazi" ]`, so enabling
    # the plugin is what puts the yazi binary on the closure.
    #
    # This sheds the explorer, not the picker: snacks.picker, fff and trouble
    # are untouched, and `<leader>e` / `<leader>E` are simply not bound.
    #
    # The unit was briefed that this row was worth 1.845 GB, 1.472 GB of it a
    # clang+llvm pair retained by ffmpeg. That is cnixvim's number and it does
    # not transfer: cvim's yazi pulls `ffmpeg-headless`, and `nix path-info -r`
    # over the yazi-on closure returns ZERO clang or llvm paths. Do not restore
    # the larger figure from the brief.
    cvim.picker.yazi.enable = lib.mkDefault false;

    # CLOSURE ROW — 79,687,560 B, measured as a byte delta on a built
    # x86_64-linux closure (884,335,464 -> 804,647,904).
    #
    # `waylandSupport` defaults to `lib.meta.availableOn hostPlatform
    # pkgs.wayland`: true on linux, false on darwin. It puts wl-clipboard and
    # its dependency chain in the wrapper's PATH so neovim's built-in clipboard
    # autodetection can find them.
    #
    # cvim never reaches that autodetection. `modules/zt/clipboard.nix` assigns
    # `vim.g.clipboard` unconditionally — pbcopy on a local mac, OSC 52 plus a
    # tmux buffer everywhere else — so the wl-clipboard binaries are present
    # and unreachable on every linux build.
    #
    # This is NOT the trim the session already tried and measured as a no-op.
    # `clipboard.providers = mkForce { }` sets an option, reads back exactly
    # what was written, and moves zero bytes, because the injection happens in
    # the nixpkgs wrapper rather than in the module. `waylandSupport` is the
    # wrapper's own switch, which is why it moves the closure and the other
    # one cannot.
    waylandSupport = lib.mkDefault false;

    # UX ROW — deliberately NOT a closure row, and not to be sold as one.
    #
    # A startup banner costs a screenful of scrollback every time you open a
    # remote editor to change one line. The whole UI area is 35.6 MiB against
    # yazi's 359 MB, so nothing here is about bytes; claiming otherwise is how
    # a cascade fills up with rows that move nothing.
    cvim.ui.dashboard.enable = lib.mkDefault false;
  };

  # NOT A ROW, AND DELIBERATELY SO — bufferline stays on `server`.
  #
  # U12 was chartered to cut the closure, so "does a remote editor need a tab
  # bar" is exactly the question it asks, and the honest-looking answer is
  # yes-we-can-drop-it. Two reasons it is wrong here, one measured and one
  # structural.
  #
  # MEASURED: turning the whole `ui` area off on `server` is worth
  # 16,811,824 B — 2.2 % of the closure, against 1,137,231,104 B for `lang`
  # and 358,933,912 B for yazi. bufferline alone is a fraction of that. The UI
  # area is not where the bytes are.
  #
  # STRUCTURAL, and this is the one that would not have been noticed:
  # `termguicolors = true` reaches cvim ONLY as a side effect of nixvim's
  # bufferline module (`plugins/by-name/bufferline/default.nix:211`, a plain
  # definition, not even `mkDefault`). No cvim file asks for it. §6 row 3 —
  # zero baked theme hexes — was signed off on evidence that only means
  # anything under truecolor. So dropping bufferline would move the ground
  # under an audited row, and every option-level check would still pass,
  # because `termguicolors` would go ABSENT rather than wrong.
  #
  # If a later pass does gate bufferline, declare `termguicolors` explicitly
  # in that profile. Do not inherit it from a plugin you are removing.

  # NOT A ROW, recorded so nobody goes looking for one: the treesitter grammar
  # floor. `plugins.treesitter.grammarPackages` defaults to nixvim's
  # `allGrammars` — 326 grammars, ~267 MB — and with `cvim.lang.enable = false`
  # no lang module defines it, so the nixvim default would go live on exactly
  # the profile whose purpose is a small closure. The floor is defined in
  # `modules/core/treesitter.nix` instead, because the unit that turns
  # treesitter on owns its resting cost, and `server` inherits it with no
  # cascade entry. A row here would also be wrong mechanically:
  # `grammarPackages` is a `listOf`, so a plain definition would ADD to core's
  # floor rather than replace it, and shrinking it from here would need
  # `mkForce`.
}
