# Server plumbing: the seam the `lang` layer attaches servers to.
#
# cvim configures servers through neovim's native `vim.lsp.config` /
# `vim.lsp.enable` API, which nixvim exposes as `lsp.servers.<name>`. There is
# no per-server setup call and no `on_attach` chain to thread.
{ config, lib, ... }:
let
  cfg = config.cvim.lsp;
in
{
  config = lib.mkIf cfg.enable {
    # nvim-lspconfig ships default configs — cmd, root_markers, filetypes — for
    # several hundred servers, and enables none of them. `lsp.servers.<name>`
    # supplies only the delta.
    #
    # It is also a HARD DEPENDENCY of the expected-servers signal in
    # ./expected-servers.nix, which reads each server's filetypes from
    # `vim.lsp.config[name].filetypes` at runtime. Those tables come from
    # nvim-lspconfig's `lsp/<name>.lua` runtime files and from nowhere else.
    # Measured in the lab build: without this option every lookup is `nil`, so
    # every filetype answers "no servers expected" no matter how many servers
    # `lang` enabled — with a green build, a clean eval, and no error anywhere.
    # Do not drop this to shrink the closure without replacing that lookup.
    plugins.lspconfig.enable = true;

    lsp.inlayHints.enable = cfg.inlayHints;
  };

  # ── The toolchain gate, for the `lang` layer ────────────────────────────
  #
  # Nothing is populated here on purpose; this comment is the interface `lang`
  # implements against. Each server module chooses one of three shapes:
  #
  #   package = null                     cvim ships no binary. The server runs
  #                                      only if the user's $PATH has one, e.g.
  #                                      from a project devshell. Nothing enters
  #                                      the closure.
  #
  #   packageFallback = true             cvim ships a binary, but suffixes it to
  #                                      $PATH instead of prefixing it, so a
  #                                      devshell's version wins when present.
  #                                      This is the right default for anything
  #                                      whose version must track the project.
  #
  #   (neither)                          cvim's binary is prefixed onto $PATH
  #                                      and always wins. Correct only for
  #                                      servers with no project-local version
  #                                      to respect.
  #
  # All three are visible to the statusline: `expected-servers.nix` reports
  # `package` and `fallback` per server, so a missing server that was always
  # meant to come from a devshell reads differently from one that is broken.
  #
  # U12 asserts that every enabled server is either in the closure or
  # explicitly fallback-marked, which is why "neither" must stay a deliberate
  # choice rather than a default anyone drifts into.
}
