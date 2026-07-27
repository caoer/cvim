# Profile cascade: `cvim.profile` picks a shape, the shape sets area defaults.
#
# A profile only ever writes `mkDefault`, so picking a profile never costs you
# the ability to override one option inside it. `null` is a real profile value:
# it means "no cascade — every area keeps the default it declares".
{ config, lib, ... }:
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
  };
}
