# FIXTURE — never imported. Read as TEXT by the guard's self-test. The paths
# below name nothing that exists; only the text is ever looked at.
#
# The BYPASS: the same invisible-plugin violation as `fires.nix`, split across
# two files so that neither one trips a per-file AND. This file holds the
# condition and no plugin config. The file it pulls in holds plugin config and
# no condition. Both halves are clean; the plugin is still absent from every
# config the CI lint evaluates.
#
# The guard's self-test asserts the detector flags THIS file — matching a
# platform predicate inside the `imports` statement itself, not merely
# somewhere in the file. `imports-quiet.nix` is the arm that keeps that
# distinction honest.
{
  lib,
  pkgs,
  ...
}:
{
  imports = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [ ./darwin-plugins.nix ];
}
