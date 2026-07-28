# The `ui` layer
#
# Colorscheme, statusline, buffer line, keymap hints, notifications.
#
# Implements `cvim.ui.*`, declared in `../options/ui.nix`. One
# implementation unit owns this directory and that options file; nothing
# outside the unit writes to either.
#
# ── Loading: every plugin here is EAGER, and that is now a decision ──────────
#
# Stated plainly because it was not one to begin with: this layer shipped with no
# deferrals because lazy loading never came up, not because it was weighed. Eager
# by omission and eager by decision are indistinguishable from the outside, and
# startup profiling would have measured an all-eager layer that nobody chose. So
# the reasoning is recorded here rather than left to be re-derived.
#
# Eager because it has to be:
#
#   theme          The colorscheme must be applied before the first paint.
#   noice          Replaces the message and cmdline UI; it has to exist before
#                  there are messages to route.
#   notify         The notify backend. notifications.nix installs a queue that
#                  waits for something to replace `vim.notify` and flushes into
#                  it. Defer this and the queue falls through to its 500ms
#                  timeout on every launch, which is a slower startup AND a
#                  worse result — the exact inversion worth avoiding.
#   icons          Consumed by bufferline and markview for their glyphs, and it
#                  registers the `nvim-web-devicons` mock other plugins look up
#                  by name. Deferring a provider behind its consumers is
#                  backwards.
#   bufferline     Owns the tab line, which is on screen from the first buffer.
#   dashboard      Draws at VimEnter. There is nothing to defer to.
#
# GENUINE LAZY CANDIDATES, deliberately not deferred yet, pending an owner for
# the lazy-loading provider:
#
#   which-key      Needed only once a prefix key is pressed. Key-triggered.
#   markview       Needed only in markdown-family buffers. Filetype-triggered.
#   smartcolumn    Needed only once a buffer exists. Marginal — the plugin only
#                  ever sets a window option, so the win is small.
#
# These are not deferred today on purpose. `plugins.lz-n.enable` reads false
# across every output, so nothing in the tree provides the lazy-loading
# mechanism. Writing a `lazyLoad` spec now would produce a config that READS
# deferred while the plugin loads eagerly anyway — a silent downgrade, and worse
# than honest eager loading, because it would hide these three candidates from
# whoever eventually looks. Revisit when a provider exists.
{
  imports = [
    ./theme.nix
    ./theme-picker.nix
    ./bufferline.nix
    ./which-key.nix
    ./notifications.nix
    ./icons.nix
    ./markview.nix
    ./smartcolumn.nix
    ./dashboard.nix
    ./statusline.nix
  ];
}
