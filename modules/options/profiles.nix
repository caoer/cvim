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
# The bytes in a `server` build are not where the plan assumed. Measured on a
# real linux builder (`results/u12-linux-server-closure-breakdown.md`), against
# the 2.757 GB x86_64-linux baseline:
#
#   yazi                       1.845 GB   66.9 %
#   LSP / language toolchains  0.344 GB   12.5 %
#
# So the two closure rows below are not equal partners, and neither is the
# third row a closure row at all. Each is labelled with what it is, because a
# UX row sold as bytes is how a cascade acquires rows nobody can defend.
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
        # CLOSURE ROW — 0.344 GB of the 2.757 GB linux baseline (12.5 %).
        #
        # Servers get a text editor, not a toolchain host. This is the area
        # gate; each language underneath also defaults off on `server`
        # (`options/lang.nix` reads the profile for its own declared
        # defaults), so a host that turns this area back on for one language
        # gets that one language and not the workstation's eight.
        #
        # It is NOT the lever this profile lives or dies by. Dropping every
        # LSP and keeping yazi lands at 2.413 GB — 3x the target. The row
        # below is the lever.
        cvim.lang.enable = mkDefault false;

        # CLOSURE ROW — 1.845 GB of the 2.757 GB linux baseline (66.9 %), and
        # a BINDING PRECONDITION of this profile rather than a preference.
        #
        # nixvim's yazi module declares `dependencies = [ "yazi" ]`, so
        # enabling the plugin is what puts the yazi binary on the closure.
        # 1.472 GB of yazi's 1.845 GB is a clang+llvm pair that ffmpeg
        # retains because nixpkgs builds it `--enable-cuda-llvm` on linux and
        # `--disable-cuda-llvm` on darwin — that single flag is 92.5 % of the
        # linux-versus-darwin gap.
        #
        # This sheds the explorer, not the picker: snacks.picker, fff and
        # trouble are untouched, and `<leader>e` / `<leader>E` are simply not
        # bound. Verified by byte delta on a built closure, never by reading
        # the option back — see the report for the numbers.
        cvim.picker.yazi.enable = mkDefault false;

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
