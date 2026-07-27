# Lazy-loading provider — lz.n, the substrate every `lazyLoad` spec stands on.
#
# D10 made lz.n the lazy-loading mechanism and no §5 Files line ever assigned
# the provider, so every layer was writing `lazyLoad` specs against a provider
# nobody enabled. This file is that owner. It does one thing.
#
# WHAT ACTUALLY BREAKS WITHOUT IT — measured on this nixvim pin, against the
# built program, because the answer is not the one the plan predicted:
#
#   `lazyLoad.enable` defaults to true as soon as `lazyLoad.settings` holds a
#   non-null attribute, and `autoLoad` defaults to `!lazyLoad.enable`. So a
#   plugin with a spec is `optional = true` — an OPT plugin, on the packpath
#   and not loaded at startup. Its `setup()` is withheld from `init.lua`
#   (`mk-neovim-plugin.nix`, `mkIf (!cfg.lazyLoad.enable) luaConfigAtLocation`)
#   and routed into the lz.n spec's `after` instead.
#
#   With no provider, nothing ever executes that `after`. The plugin is never
#   loaded and its `setup()` never runs. The feature is SILENTLY ABSENT, on a
#   green build, and nixvim only warns.
#
# Two beliefs to discard, both of which cost real debugging time:
#
#   `plugins.lz-n.plugins` is NOT evidence. The spec list is fully populated
#   whether or not the provider is on — measured, both shapes. Reading it back
#   tells you a value; only the generated program tells you the mechanism ran.
#   The discriminator is `require('lz.n').load` in `init.lua`.
#
#   The plugin does NOT become a start plugin and nothing runs eagerly. That
#   path exists only when someone explicitly sets `lazyLoad.enable = false`
#   while leaving `settings` populated, which is a deliberate choice of eager
#   loading rather than something a missing provider does to you.
#
# WHY THIS IS NOT GATED ON `cvim.editor.enable`. It lives in `modules/core/`
# because the provider is core's to own — but its SCOPE is every layer, so
# scoping it to the core layer's toggle would be a live defect, not a style
# question. `cvim.editor.enable`'s own description invites turning the layer
# off to bisect a problem; gate this on it and that documented path silently
# makes every OTHER layer's lazy loading inert, on a green build, while the
# person is looking for something else entirely.
#
# WHY A PLAIN `true` AND NOT `mkDefault`. A deliberate departure from the
# house's mkDefault-by-discipline rule, so that the next reader sees a decision
# and not an oversight. `mkDefault` exists for preferences; this is substrate,
# and an overridable provider re-creates exactly the silent-inert failure this
# file was written to remove. It still coexists with the plan's documented
# `mkDefault true` bridge, because `types.bool` merges definitions that agree.
{
  config,
  options,
  lib,
  ...
}:
{
  config = {
    plugins.lz-n.enable = true;

    # The guard for the one case this file cannot prevent: something else
    # turning the provider back off. CI lints the same property across all
    # three configurations, but CI does not run on a host's `extendModules`,
    # and this is the failure whose only symptom is a feature quietly not
    # being there.
    #
    # nixvim warns here (`modules/lazyload.nix`) and a warning does not fail a
    # build. This is that warning promoted, with the consequence spelled out —
    # a guard has to survive its own future reader, who is looking at a red
    # build and a deadline. "lz-n required" gets deleted; a named incident
    # does not.
    #
    # The candidate filter is nixvim's own, borrowed from
    # `.github/lint/no-lazyload-after.nix` rather than reinvented, and it is
    # load-bearing. Iterating `config.plugins` blindly forces removed options
    # such as `plugins.nvim-osc52`, whose value is a `throw` — and `or false`
    # does not help, because the throw happens before the `or`.
    #
    # That mattered here in the worst way. `||` short-circuits, so with the
    # provider ON the guard never evaluates the list and every build is green.
    # It would have thrown an unrelated `nvim-osc52` error the first time
    # someone disabled lz-n — the exact moment the guard exists for. A guard
    # that only works while it is not needed is worse than no guard.
    assertions =
      let
        isOption = value: builtins.isAttrs value && (value._type or null) == "option";
        isVisible =
          option:
          let
            visible = option.visible or true;
          in
          if builtins.isBool visible then visible else visible == "shallow";
        lazyLoadable = builtins.filter (
          name:
          let
            node = options.plugins.${name}.lazyLoad or null;
          in
          isOption node && isVisible node
        ) (builtins.attrNames config.plugins);
        lazyIntent = builtins.filter (name: config.plugins.${name}.lazyLoad.enable) lazyLoadable;
      in
      [
        {
          assertion = config.plugins.lz-n.enable || lazyIntent == [ ];
          message = ''
            These plugins declare a lazy-loading spec and `plugins.lz-n` is
            disabled, so there is no provider to register it:

            ${lib.concatMapStringsSep "\n" (name: "  - plugins.${name}") lazyIntent}

            Each one is an opt plugin whose `setup()` was withheld from
            init.lua and handed to lz.n instead. With lz.n off, nothing runs
            it: the plugin never loads, its setup never runs, and the feature
            is simply absent. The build stays green and nixvim only warns.

            For `typescript-tools` this is §6 row 2 losing its guard —
            cvim ships it with `lazy = true` and deliberately no `ft`, so the
            spec IS the on-demand rule. Without a provider you do not get
            on-demand TypeScript; you get no TypeScript, and nothing says so.

            Re-enable `plugins.lz-n`, or set `lazyLoad.enable = false` on the
            plugins above if you have genuinely chosen eager loading — that is
            a different thing and it does load them.
          '';
        }
      ];
  };
}
