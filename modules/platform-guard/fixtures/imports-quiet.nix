# FIXTURE — never imported. Read as TEXT by the guard's self-test. The paths
# below name nothing that exists; only the text is ever looked at.
#
# The NEAR-MISS for the import rule: an UNCONDITIONAL `imports` list in a file
# that also carries a platform condition, somewhere else, for something else.
# This shape is correct and must never be flagged.
#
# It is `modules/zt/codesign.nix` — the one system-conditional block in the
# tree, `mkIf … isDarwin` carrying `extraConfigLua` and nothing else — with an
# import list added. Fourteen files under `modules/` define `imports` and every
# one is unconditional, so a file-scoped AND of "has imports" and "has a
# platform condition" would flag any of them the day someone adds a guarded
# `extraConfigLua`. The detector reads the `imports` STATEMENT instead.
#
# Without this arm, a regression from statement-scope back to file-scope stays
# green: `imports-fires.nix` is flagged either way.
{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./example-a.nix
    ./example-b.nix
  ];

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    extraConfigLua = ''
      vim.g.example_codesign = true
    '';
  };
}
