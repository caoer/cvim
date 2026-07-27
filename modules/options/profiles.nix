# Profile cascade: `cvim.profile` picks a shape, the shape sets area defaults.
#
# A profile only ever writes `mkDefault`, so picking a profile never costs you
# the ability to override one option inside it. `null` is a real profile value:
# it means "no cascade — every area keeps the default it declares".
#
# ## Each profile states its WHOLE shape, not its diff from the other
#
# Both profiles name every area, including the ones they leave on. The rows
# that agree with an area's declared default are inert today — proven by drv
# hash, not by reading: adding them left `packages.<sys>.default` on the same
# derivation on all three systems. They are here because a profile that lists
# only its differences stops being true the moment an area changes its own
# declared default. `"default"` promises "every area on"; that promise has to
# be written down somewhere, or the next area to land default-off silently
# breaks it on a green build.
#
# ## Rows are evidence-driven, and closure rows are not the same kind as UX rows
#
# Every closure row below carries the byte delta that justifies it, measured by
# building the closure with and without the row on a real x86_64-linux builder.
# An option read back is not evidence: it tells you what was written, not what
# left the closure. Full report: `results/u12-closure-startup.md`.
#
#   cvim.lang (area + the 8 workstation languages)   1,137,231,104 B
#   cvim.picker.yazi                                   358,933,912 B
#   waylandSupport                                      79,687,560 B
#   withRuby                                            43,403,720 B
#
# THESE SUPERSEDE THE NUMBERS THE UNIT WAS BRIEFED WITH, which came from
# cnixvim and do not transfer to cvim:
#
#   - yazi was briefed at 1.845 GB / 66.9 % of the closure, of which 1.472 GB
#     was a clang+llvm pair retained by an ffmpeg built `--enable-cuda-llvm`.
#     cvim's yazi pulls `ffmpeg-headless`, which has no such pair: the yazi-on
#     closure contains ZERO clang or llvm paths, and yazi costs 359 MB. It is
#     still the second-largest lever and the row still stands — the reason
#     given for it does not.
#   - the language toolchains were briefed as "an eighth" of the closure and
#     explicitly not the lever. On cvim they are the LARGEST lever by 3x.
#
# Neither correction was found by re-reading the brief; both came from building
# the two closures and subtracting.
#
# Not every row is a closure row. The dashboard row is UX and is labelled as
# such, because a UX row sold as bytes is how a cascade acquires rows nobody
# can defend.
{ config, lib, ... }:
let
  inherit (lib) mkDefault mkIf mkMerge;

  cfg = config.cvim;

  # The eight areas, in one list, so the two profiles cannot disagree about
  # which areas exist. A name with no `cvim.<name>.enable` behind it is an
  # eval error naming the option, which is the failure we want: a profile that
  # silently skips an area is the whole class this unit exists to catch.
  areas = [
    "ai"
    "editor"
    "git"
    "lang"
    "lsp"
    "picker"
    "ui"
    "utilities"
  ];

  # `mkDefault true` for each named area. Areas a profile overrides are left
  # out of the call rather than merged over: two definitions at the same
  # priority is a conflict, not an override.
  gatesOn = names: {
    cvim = lib.genAttrs names (_: {
      enable = mkDefault true;
    });
  };
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
      - `"server"` — a comfortable remote editor: every area on except the
        language toolchains, and without the file explorer, so the closure
        stays small enough to ship to small hosts.
      - `null` — no cascade. Every area keeps its own declared default; use
        this when you are composing the areas yourself.

      The `lab` package is `"default"` plus the scratch layer in `lab/`; it is
      not a profile, because nothing in `lab/` may ever reach a real build.
    '';
  };

  config = mkMerge [
    # ---- default: the workstation ------------------------------------------
    (mkIf (cfg.profile == "default") (gatesOn areas))

    # ---- server: the small-host remote editor -------------------------------
    (mkIf (cfg.profile == "server") (mkMerge [
      (gatesOn (lib.subtractLists [ "lang" ] areas))

      {
        # CLOSURE ROW — 1,137,231,104 B, the largest lever in the profile.
        #
        # Servers get a text editor, not a toolchain host.
        #
        # MEASURING THIS ROW HAS A TRAP, and the first attempt fell in it.
        # Flipping the area gate alone produces a BYTE-IDENTICAL closure —
        # same store path, not merely the same size. Every language's own
        # `enable` also defaults false on `server` (`options/lang.nix` reads
        # the profile), so turning the area back on enables no language and
        # the measurement reads as "this row is worth nothing". The number
        # above is the area gate plus the eight languages a workstation
        # actually has.
        #
        # The two levels are deliberate: a server host that re-enables the
        # area to get one language gets that one language, not the
        # workstation's eight.
        cvim.lang.enable = mkDefault false;

        # CLOSURE ROW — 358,933,912 B (884,335,464 -> 1,243,269,376 with it
        # back on), the second-largest lever.
        #
        # nixvim's yazi module declares `dependencies = [ "yazi" ]`, so
        # enabling the plugin is what puts the yazi binary on the closure.
        #
        # This sheds the explorer, not the picker: snacks.picker, fff and
        # trouble are untouched, and `<leader>e` / `<leader>E` are simply not
        # bound.
        #
        # The unit was briefed that this row was worth 1.845 GB, 1.472 GB of
        # it a clang+llvm pair retained by ffmpeg. That is cnixvim's number
        # and it does not transfer: cvim's yazi pulls `ffmpeg-headless`, and
        # `nix path-info -r` over the yazi-on closure returns ZERO clang or
        # llvm paths. Do not restore the larger figure from the brief.
        cvim.picker.yazi.enable = mkDefault false;

        # CLOSURE ROW — 79,687,560 B, measured as a byte delta on a built
        # x86_64-linux closure (884,335,464 -> 804,647,904).
        #
        # `waylandSupport` defaults to `lib.meta.availableOn hostPlatform
        # pkgs.wayland`: true on linux, false on darwin. It puts wl-clipboard
        # and its dependency chain in the wrapper's PATH so neovim's built-in
        # clipboard autodetection can find them.
        #
        # cvim never reaches that autodetection. `modules/zt/clipboard.nix`
        # assigns `vim.g.clipboard` unconditionally — pbcopy on a local mac,
        # OSC 52 plus a tmux buffer everywhere else — so the wl-clipboard
        # binaries are present and unreachable on every linux build.
        #
        # This is NOT the trim the session already tried and measured as a
        # no-op. `clipboard.providers = mkForce { }` sets an option, reads
        # back exactly what was written, and moves zero bytes, because the
        # injection happens in the nixpkgs wrapper rather than in the module.
        # `waylandSupport` is the wrapper's own switch, which is why it moves
        # the closure and the other one cannot.
        waylandSupport = mkDefault false;

        # CLOSURE ROW — 43,403,720 B, measured the same way.
        #
        # The ruby remote-plugin provider. cvim ships no ruby remote plugin on
        # any profile, so this is dead weight rather than a capability being
        # given up; nixvim simply defaults `withRuby` to true.
        #
        # Taken here and not globally ON PURPOSE. It is equally unused on
        # `default`, and moving it to a global default would shed the same
        # bytes there — but that changes the workstation artifact, which
        # belongs to whoever owns the editor core, not to the profile cascade.
        # Recorded as a finding rather than taken quietly.
        withRuby = mkDefault false;

        # UX ROW — deliberately NOT a closure row, and not to be sold as one.
        #
        # A startup banner costs a screenful of scrollback every time you open
        # a remote editor to change one line. The whole UI area is 35.6 MiB
        # against yazi's 1.845 GB, so nothing here is about bytes; claiming
        # otherwise is how a cascade fills up with rows that move nothing.
        cvim.ui.dashboard.enable = mkDefault false;
      }
    ]))
  ];

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
