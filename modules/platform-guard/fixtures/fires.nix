# FIXTURE — never imported. Read as TEXT by the guard's self-test.
#
# The violation the guard exists to catch: a platform-conditional block that
# declares a plugin with a `lazyLoad` spec. On `x86_64-linux` this block does
# not exist, so the CI lint evaluates a config in which the plugin is simply
# absent and reports green.
#
# The guard's self-test asserts that the detector flags THIS file. That is the
# permanently-live version of "an unfired assertion is indistinguishable from
# an absent one" — a planted violation the detector must keep finding, rather
# than a green tree we hope it would have caught.
{
  lib,
  pkgs,
  ...
}:
{
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    plugins.which-key = {
      enable = true;
      lazyLoad.settings.event = "VeryLazy";
    };
  };
}
