# FIXTURE — never imported. Read as TEXT by the guard's self-test.
#
# The NEAR-MISS: `hostPlatform` interpolated into an assertion MESSAGE, in a
# file that also declares plugin config. This shape is correct and must never
# be flagged.
#
# It is not hypothetical. Four real modules have exactly it —
# `modules/lang/{java,cpp,rust,csharp}.nix` — and all four are right. A
# `git grep hostPlatform` over `modules/` returns five hits and ONLY ONE is a
# condition; sizing this guard off that five is wrong by four.
#
# So the detector keys on the CONDITION, not on the token, and this fixture is
# the arm that proves it. A guard proven only against `fires.nix` cannot tell
# "correct" from "always fails" — both halves are asserted on every build.
#
# TWO shapes live here, because the detector has two discriminators and one
# fixture per discriminator is the only way to keep both honest:
#
#   `interpolated` is the shape the four modules use today. Removing `${…}`
#   antiquotations is what keeps it quiet.
#
#   `sys` is the same value bound in a `let` and used as a VALUE — no
#   antiquotation to remove, so interpolation-stripping does nothing for it.
#   Only matching a BOOLEAN predicate (`hostPlatform.is*`, `stdenv.is*`, a
#   comparison against `.system`) rather than the bare token keeps it quiet.
#
# Measured: with only the first shape present, regressing the detector to a
# plain `hostPlatform` token match left this fixture green and the regression
# shipped silently. The second shape is what makes that regression red.
{
  lib,
  pkgs,
  ...
}:
let
  sys = pkgs.stdenv.hostPlatform.system;
in
{
  config = {
    plugins.which-key = {
      enable = true;
      lazyLoad.settings.event = "VeryLazy";
    };

    assertions = [
      {
        assertion = true;
        message = ''
          cvim.lang.example.servers: "gopls" has no package on ${pkgs.stdenv.hostPlatform.system}.
          Set cvim.lang.example.toolchain = "devshell" to configure it without shipping a binary.
        '';
      }
      {
        assertion = true;
        message = "cvim.lang.example: nothing to ship on " + sys + ".";
      }
    ];
  };
}
