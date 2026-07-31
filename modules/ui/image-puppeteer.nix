# macOS: point mermaid-cli's puppeteer at the installed Google Chrome.
#
# `mmdc` (shipped by image.nix) drives a browser through puppeteer, and
# nixpkgs has no chromium for darwin. Without this variable ChromeLauncher
# throws and produces nothing; with it, `mmdc` rendered a 2961-byte PNG —
# verified in both directions in the U4a session
# (decisions/u4a-snacks-image.md), which recorded this exact recipe for the
# unit that ships image rendering.
#
# This file is the codesign.nix shape the platform guard prescribes: a
# `mkIf … isDarwin` block carrying `env` and nothing else. The plugin config
# it serves lives unconditionally in image.nix, so the CI lint — which
# evaluates x86_64-linux only — still sees every plugin.
#
# On linux the variable is absent and nixpkgs' own mermaid-cli wrapping
# resolves the browser.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.ui;
in
{
  config = lib.mkIf (cfg.enable && cfg.image.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    env.PUPPETEER_EXECUTABLE_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  };
}
