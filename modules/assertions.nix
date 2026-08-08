# Build-time assertions over cvim's own declared surface.
#
# Three properties the distro cannot check by building successfully, because
# each one's failure mode is a green build. They are collected here rather than
# in the layer that could violate them: a layer cannot assert about its
# siblings, and every one of these is violated by the INTERACTION of two layers
# that are each individually fine.
#
# ## What population each assertion runs over, and why it is not the other one
#
# `config.keymaps` — the keymaps cvim DECLARES, 84 of them, all authored by a
# cvim unit. This is deliberately not the runtime table (`nvim_get_keymap`),
# and the difference decides whether an assertion is usable:
#
#   duplicate (mode, lhs)   safe on either population — duplication is a
#                           property of the whole map space. Returns 0 across
#                           the runtime table too (measured).
#   desc mandatory          ONLY safe on the declared surface. The runtime
#                           table carries ~50 mappings with no `desc` that no
#                           cvim unit authored — `<Plug>` internals from
#                           Plenary and Matchit, matchit's `% [% ]% g%`,
#                           flash-class motion overrides `f F t T ; , s`,
#                           undo-class `u` and `<C-R>`. Asserted over the
#                           runtime table this fails on day one against
#                           mappings nobody here owns, and both natural
#                           reactions — weaken the rule, or go chase upstream
#                           keymaps — are wrong.
#
# One table, two requirements, opposite correct populations.
#
# ## Reading keymaps: project fields, never enumerate them
#
# `builtins.attrNames` on a keymap entry THROWS:
#
#   error: The option `lua' can no longer be used since it's been removed.
#          Full option: `keymaps."[definition 2-entry 1]".lua`
#
# The removed option's value is a `throw`, and `or` does not help because the
# throw happens before the `or`. So every read below names the three fields it
# wants (`mode`, `key`, `options.desc`) and touches nothing else. The same shape
# bit `modules/core/lazy.nix` with `plugins.nvim-osc52`; it is a property of how
# nixvim retires options, not of these two attrsets.
{
  config,
  options,
  lib,
  ...
}:
let
  # Only these three fields, for the reason in the header. `mode` is either a
  # string or a list of them, so it is normalised here and nowhere else.
  keymaps = map (k: {
    modes = lib.toList k.mode;
    inherit (k) key;
    desc = k.options.desc or null;
  }) config.keymaps;

  # One entry per (mode, lhs) pair a keymap actually binds. A keymap listing
  # three modes occupies three slots, because `vim.keymap.set` writes three
  # mappings and each can be clobbered independently.
  #
  # This is also why the key is spelled out rather than called "unique": `v`,
  # `x` and `s` are distinct mode strings and de-duplicating on (mode, lhs)
  # does not collapse them. A reader who reconstructs a different key from the
  # word "unique" gets a different number.
  bindings = lib.concatMap (k: map (mode: "${mode} ${k.key}") k.modes) keymaps;

  bindingCounts = lib.foldl' (acc: b: acc // { ${b} = (acc.${b} or 0) + 1; }) { } bindings;
  duplicates = lib.filter (b: bindingCounts.${b} > 1) (lib.attrNames bindingCounts);

  # An empty `desc` is the same defect as a missing one — which-key renders
  # neither.
  descless = lib.filter (k: k.desc == null || k.desc == "") keymaps;

  # The names nixvim declares an option for, as opposed to the ones that only
  # exist because someone wrote them into the freeform attrset. 223 on this
  # pin, including the `*` meta-server.
  declaredServerNames = lib.attrNames (
    options.lsp.servers.type.getSubOptions options.lsp.servers.loc
  );

  enabledServerNames = lib.attrNames (
    lib.filterAttrs (name: server: name != "*" && server.enable) config.lsp.servers
  );

  # `&&` short-circuits, so `package` is forced only for names nixvim does not
  # declare. That matters: reading `.package` on all 223 declared servers would
  # evaluate 223 package expressions, several of which throw on a mismatched
  # nixpkgs (nixvim's own docs generation wraps the same read in `tryEval`).
  unaccountedServers = lib.filter (
    name:
    !(lib.elem name declaredServerNames)
    && config.lsp.servers.${name}.package == null
    && !config.lsp.servers.${name}.packageFallback
  ) enabledServerNames;
in
{
  config.assertions = [
    # ── 1. No two keymaps claim the same (mode, lhs) ───────────────────────
    #
    # `vim.keymap.set` overwrites silently: the second definition wins, the
    # first is simply gone, and nothing anywhere reports it. Across eight
    # layers written by eight units this is the collision nobody is positioned
    # to notice — the layer that lost its binding is not the layer that took
    # it.
    {
      assertion = duplicates == [ ];
      message = ''
        These (mode, lhs) pairs are bound by more than one cvim keymap:

        ${lib.concatMapStringsSep "\n" (b: "  - ${b}") duplicates}

        `vim.keymap.set` does not merge or warn — the last definition to be
        written wins and the earlier one is silently absent. Pick a different
        key, or delete the binding that is no longer wanted.
      '';
    }

    # ── 2. Every declared keymap carries a `desc` ──────────────────────────
    #
    # Design law, §4: `desc` is what which-key renders and what makes a
    # binding discoverable. A keymap without one is bound and invisible.
    {
      assertion = descless == [ ];
      message = ''
        These cvim keymaps have no `options.desc`:

        ${lib.concatMapStringsSep "\n" (k: "  - ${lib.concatStringsSep "/" k.modes} ${k.key}") descless}

        `desc` is mandatory on every keymap cvim declares (§4 design law): it
        is the text which-key shows, so a binding without one is bound and
        undiscoverable. This checks only cvim's own 84 declared keymaps —
        upstream `<Plug>` mappings are out of scope and always will be.
      '';
    }

    # ── 3. Every enabled server has a binary somebody chose ────────────────
    #
    # `lsp.servers` is FREEFORM. `lsp.servers.gopsl.enable = true` evaluates
    # green, builds green, and configures nothing: the name is accepted as a
    # new freeform attribute, `package` takes its `null` default, and no
    # binary, no config and no `vim.lsp.enable` for the server you meant ever
    # appear. That is §7's freeform class, arriving through a misspelled
    # attribute NAME rather than a misspelled setting.
    #
    # `cvim.lang.<lang>.servers` already closes this with an `enum`, so this
    # assertion is what covers the paths that enum does not reach: a host's
    # `extendModules`, and any module writing `lsp.servers.<name>` directly.
    #
    # THE THREE ACCEPTED SHAPES, per `modules/lsp/servers.nix`:
    #
    #   package != null                cvim ships the binary. In the closure.
    #   packageFallback = true         cvim defers to a $PATH copy on purpose.
    #   a name nixvim DECLARES         `package = null` here overrides a real
    #                                  package default, so it is a decision.
    #                                  This is what `toolchain = "devshell"`
    #                                  produces, and it is supported.
    #
    # The third clause is why this assertion is about the NAME and not only
    # about the value. A declared server with `package = null` and a freeform
    # server with `package = null` hold the identical value; only the option
    # surface distinguishes "someone chose to ship nothing" from "nobody chose
    # anything". Asserting on the value alone fires on `toolchain = "devshell"`
    # — a documented, supported configuration — which is an assertion that has
    # to be weakened the first time it fires. That is worse than none.
    {
      assertion = unaccountedServers == [ ];
      message = ''
        These language servers are enabled but nixvim does not declare them,
        and cvim ships no binary for them:

        ${lib.concatMapStringsSep "\n" (name: "  - lsp.servers.${name}") unaccountedServers}

        `lsp.servers` is freeform, so an unrecognised name is accepted as a
        new attribute rather than rejected: the build stays green and the
        server you meant is never configured. Check the spelling against
        nixvim's server list, or — if the name is right and the binary comes
        from somewhere cvim cannot see — set `packageFallback = true` to say
        so explicitly.
      '';
    }
  ];
}
