# Prefix-keymap guard — no keymap may be both a complete mapping and a prefix
# of another in a mode they share.
#
# WHAT THIS PREVENTS, AT FULL SEVERITY. A key that is both a complete mapping
# and a prefix of a longer one behaves by relative definition order. Defined
# last it stalls for `timeoutlen`. Defined FIRST it fires immediately and the
# orphaned suffix executes as a bare normal-mode command.
#
# Measured on the pre-fix binary (`c1c2d7c`), `<leader>l` against its nine
# `<leader>l*` siblings, 150 ms gap, the window provably moved in every arm:
#
#   p / P   the SYSTEM CLIPBOARD is pasted into the buffer (changedtick 6→7)
#   i       insert mode; keystrokes become text
#   R       replace mode; keystrokes overtype
#   d       operator pending; the next motion deletes
#   q       arms macro recording and the editor stops answering RPC
#
# `p`/`P` are why this file exists rather than a style note.
# `modules/zt/clipboard.nix` sets `clipboard.register = "unnamedplus"`, so the
# unnamed register IS the system clipboard: a user reaching for peek-definition
# moves their window and pastes whatever they last copied — a token, a
# password — into a source file that may then be committed, with nothing about
# the keypress to suggest it happened. That is the Unit 0 threat model arriving
# through a keymap, past guards that defend files rather than keystrokes.
#
# Both instances are gone (`874ef06` dropped `<leader>hjkl`) and an independent
# runtime enumeration on `002ce05` found ZERO collisions. That is a property of
# what the tree currently contains, not of how it is built — the same geometry
# as the empty darwin residue in `platform-guard`. This file is what turns
# "zero today" into "cannot recur".
#
# ── THIS IS NOT A BAN ──────────────────────────────────────────────────────
#
# The shape is legitimate; vim itself ships `gc`/`gcc`. The goal is to make it
# a DECISION rather than an accident, so `cvim.keymapGuard.allow` below takes
# the collision back out — and demands a written reason for it. An accepted
# `timeoutlen` stall is fine. An unnoticed one that reinterprets keystrokes is
# not.
#
# ── WHY AN ASSERTION AND NOT A CI CHECK ────────────────────────────────────
#
# An assertion rides EVERY package build, including a host's own
# `extendModules` build with option values the three CI outputs never
# instantiate. A CI check only ever sees those three. Strictly wider reach,
# zero runner cost. Same argument as `modules/core/lazy.nix` and
# `modules/platform-guard`, and it was verified rather than assumed for the
# latter: with a violation injected, `nix build .#default` fails at EVAL,
# before any derivation is built.
#
# ── WHY THIS ONE IS SEMANTIC AND `platform-guard` IS TEXT ──────────────────
#
# `platform-guard` reads source text under protest, because `mkIf` is already
# resolved once the module system has merged and the evaluated config no longer
# records that a definition was conditional — its property is about the source.
# This property is not. Keymaps survive the merge as data, so this guard reads
# the EVALUATED config, which is the house default (`modules/core/lazy.nix`)
# and is strictly better: no comment, Lua string or spelling can trigger it.
#
# One surface resists that and is handled explicitly below: keymaps written as
# `vim.keymap.set(...)` inside Lua. Those are read out of `config.content` —
# the generated `init.lua`, still the evaluated artifact rather than the
# source tree, so it stays profile-accurate. Nineteen live mappings arrive this
# way, including the `<leader>h` visual-mode binding that is the whole reason
# modes are compared rather than ignored. Skipping them would have left the
# guard blind to the exact case it must not misjudge.
#
# ── ON `nowait`, WHERE THIS DELIBERATELY DIFFERS FROM THE RUNTIME AUDIT ────
#
# `results/harness/leader-prefix-audit.lua` excludes `nowait` mappings, and was
# right to: it reads the RUNNING editor, where which-key installs a
# buffer-local `nowait` trigger on the bare leader that re-feeds the sequence.
# Counting it made the leader a prefix of all 75 other mappings and buried the
# real answer in noise.
#
# That mapping does not exist on this surface at all — it is created by
# which-key at runtime, not declared in nix, and the live config contains zero
# `nowait` keymaps. What `nowait` means HERE is an author writing
# `options.nowait = true`, which does not remove the conflict but makes it
# unconditional: the shorter mapping always wins and the longer one becomes
# unreachable. That is the worse half of the failure, so it is not excluded.
# If one is ever deliberate, `allow` is where it says so.
{
  config,
  lib,
  ...
}:
let
  cfg = config.cvim.keymapGuard;

  # ─────────────────────────────────────────────────────────── mode expansion
  #
  # Vim mode letters are not atoms. `""` is `:map` — normal, visual, select AND
  # operator-pending. `"v"` is visual AND select, while `"x"` is visual alone.
  # So `""` and `"n"` conflict, `"v"` and `"x"` conflict, and `"v"` and `"n"`
  # do NOT. Comparing the letters for equality gets all three wrong, and the
  # last one is the false positive that matters: `modules/zt/plugins.nix` binds
  # `<leader>h` in visual mode against `<leader>hv` in normal, and that code is
  # correct.
  #
  # Every letter is expanded to the concrete modes it covers, and two mappings
  # conflict when those sets intersect.
  modeExpansion = {
    "" = [
      "n"
      "x"
      "s"
      "o"
    ];
    "!" = [
      "i"
      "c"
    ];
    "v" = [
      "x"
      "s"
    ];
  };
  expandModes =
    m:
    lib.unique (
      lib.concatMap (one: modeExpansion.${one} or [ one ]) (if builtins.isList m then m else [ m ])
    );

  # ──────────────────────────────────────────────────────── key normalization
  #
  # The prefix relation is over KEY SEQUENCES, not over the strings that spell
  # them. `<leader>` is the configured `mapleader` — a space here — so
  # `<Space>gg` and `<leader>g` are the same two-key space and the second IS a
  # prefix of the first. Compared raw they share nothing.
  #
  # Scope, stated so the next reader does not assume more: leader, localleader
  # and `<Space>` only. Other aliases for one key (`<C-i>`/`<Tab>`,
  # `<C-[>`/`<Esc>`) are NOT normalized. Each is a possible false negative and
  # none appears in the tree; adding them is a one-line change to the table
  # below plus a fixture.
  str = v: if builtins.isString v then v else null;
  leader = str (config.globals.mapleader or null);
  localLeader = str (config.globals.maplocalleader or null);
  aliases =
    (lib.optionalAttrs (leader != null) {
      "<leader>" = leader;
      "<Leader>" = leader;
    })
    // (lib.optionalAttrs (localLeader != null) {
      "<localleader>" = localLeader;
      "<localLeader>" = localLeader;
      "<LocalLeader>" = localLeader;
    })
    // {
      "<space>" = " ";
      "<Space>" = " ";
    };
  normKey = builtins.replaceStrings (builtins.attrNames aliases) (builtins.attrValues aliases);

  mk = origin: mode: key: {
    inherit origin;
    key = normKey key;
    modes = expandModes mode;
    raw = key;
  };

  # ───────────────────────────────────────────────────────────── the detector
  #
  # `a` is a PROPER prefix of `b` — strictly shorter and a leading substring.
  # "shares a prefix" is a different and much broader relation, and flagging it
  # would condemn `<leader>f*`, `<leader>g*` and every other correct cluster in
  # the tree. `fixtures.quiet.siblingsNoPrefix` is the arm that holds that line.
  isPrefixOf =
    a: b:
    let
      la = builtins.stringLength a;
    in
    la < builtins.stringLength b && builtins.substring 0 la b == a;

  findCollisions =
    maps:
    lib.concatMap (
      a:
      lib.concatMap (
        b:
        let
          shared = lib.intersectLists a.modes b.modes;
        in
        lib.optional (isPrefixOf a.key b.key && shared != [ ]) {
          prefix = a;
          longer = b;
          modes = shared;
        }
      ) maps
    ) maps;

  # ────────────────────────────────────────────────────────────── the sources
  #
  # Every place a keymap can enter this config. `keymapsOnEvents` is empty
  # today and is read anyway: a surface left out is a hole that opens the first
  # time someone uses it, silently, on a green build.
  fromList = origin: maps: map (k: mk origin (k.mode or "") k.key) maps;

  fromEvents = lib.concatLists (
    lib.mapAttrsToList (ev: fromList "keymapsOnEvents.${ev}") (config.keymapsOnEvents or { })
  );

  # ── the Lua surface, and its coverage check ────────────────────────────────
  #
  # `config.content` is the generated `init.lua`. Calls whose first two
  # arguments are string literals are parsed out; nineteen live mappings are
  # written that way.
  #
  # AN EMPTY LIST IS NOT A CLOSED LIST. A call this pattern cannot read —
  # `vim.keymap.set({ "n", "v" }, …)`, or a mode held in a variable — would
  # simply not appear, and the guard would report zero collisions over a set it
  # never saw. So every `vim.keymap.set(` in the artifact is counted and the
  # buckets must add up (assertion 3). The two calls that are neither literal
  # nor a defect are nixvim's own table iterators, `vim.keymap.set(map.mode, …)`
  # and `vim.keymap.set(keymap.mode, …)`; the data behind those is already read
  # from `keymaps` and `lsp.keymaps` above, so reading it twice would only
  # duplicate rows.
  content = config.content;
  countMatches = re: builtins.length (builtins.filter builtins.isList (builtins.split re content));

  luaLiteralRe = ''vim\.keymap\.set\([[:space:]]*"([^"]*)",[[:space:]]*"([^"]*)"'';
  luaIteratorRe = ''vim\.keymap\.set\([a-zA-Z_][a-zA-Z0-9_]*\.mode,'';

  fromLua = map (h: mk "lua" (builtins.elemAt h 0) (builtins.elemAt h 1)) (
    builtins.filter builtins.isList (builtins.split luaLiteralRe content)
  );

  luaTotal = countMatches ''vim\.keymap\.set\('';
  luaLiteral = countMatches luaLiteralRe;
  luaIterator = countMatches luaIteratorRe;
  luaUnread = luaTotal - luaLiteral - luaIterator;

  live =
    fromList "keymaps" config.keymaps
    ++ fromList "lsp.keymaps" (config.lsp.keymaps or [ ])
    ++ fromEvents
    ++ fromLua;

  # ─────────────────────────────────────────────────────────────── the opt-out
  #
  # An entry excuses a collision when it names the same PREFIX key and covers
  # every mode the two mappings actually share. Matching on the shared modes
  # rather than on the prefix mapping's full set keeps the excuse as narrow as
  # the conflict: `mode = "n"` forgives a normal-mode stall and nothing else.
  excused =
    c:
    builtins.any (
      e: normKey e.prefix == c.prefix.key && lib.subtractLists (expandModes e.mode) c.modes == [ ]
    ) cfg.allow;

  violations = builtins.filter (c: !excused c) (findCollisions live);

  fmt =
    c:
    "${builtins.toJSON c.prefix.raw} (${builtins.concatStringsSep "," c.prefix.modes}, from ${c.prefix.origin}) is a prefix of ${builtins.toJSON c.longer.raw} (${builtins.concatStringsSep "," c.longer.modes}, from ${c.longer.origin}) — they share mode${
      lib.optionalString (builtins.length c.modes > 1) "s"
    } ${builtins.concatStringsSep "," c.modes}";

  # ───────────────────────────────────────────────────────────────── self-test
  fx = import ./fixtures.nix;
  runFixture = group: name: findCollisions (fromList "fixtures.${group}.${name}" fx.${group}.${name});
  silentFires = builtins.filter (n: runFixture "fires" n == [ ]) (builtins.attrNames fx.fires);
  noisyQuiets = builtins.filter (n: runFixture "quiet" n != [ ]) (builtins.attrNames fx.quiet);

  blankReasons = builtins.filter (e: builtins.match "[[:space:]]*" e.reason != null) cfg.allow;
in
{
  # WHY THIS OPTION IS NOT IN `modules/options/`. That directory is the
  # `cvim.*` FEATURE surface — one file per area a user turns on or off. This
  # is not a feature; it is the escape hatch of one guard, useless without the
  # assertion twenty lines below it, and splitting the two across directories
  # would mean neither file could be read on its own. `platform-guard` makes
  # the same departure by owning no options file at all.
  options.cvim.keymapGuard.allow = lib.mkOption {
    default = [ ];
    description = ''
      Prefix collisions that are accepted deliberately.

      Each entry takes a mapping back out of the prefix guard. The `reason` is
      mandatory and has to say why the `timeoutlen` delay — and the risk that
      definition order flips it into an immediate fire — is worth it here.
    '';
    example = lib.literalExpression ''
      [
        {
          mode = "n";
          prefix = "gc";
          reason = "vim's own comment operator; `gcc` is the line form and the delay is vim's documented behaviour.";
        }
      ]
    '';
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          mode = lib.mkOption {
            type = lib.types.either lib.types.str (lib.types.listOf lib.types.str);
            description = ''
              The mode the collision is accepted in, spelled as the keymap
              spells it. Expanded the same way the guard expands modes, so
              `""` covers normal, visual, select and operator-pending.
            '';
          };
          prefix = lib.mkOption {
            type = lib.types.str;
            description = ''
              The SHORTER key — the complete mapping that is also a prefix.
              `<leader>` and `<Space>` are normalized, so either spelling works.
            '';
          };
          reason = lib.mkOption {
            type = lib.types.str;
            description = ''
              Why the collision is accepted. Required, and required to be
              non-blank: an opt-out that records nothing is indistinguishable
              from having no guard.
            '';
          };
        };
      }
    );
  };

  config.assertions = [
    {
      assertion = violations == [ ];
      message = ''
        These keymaps are both a complete mapping AND a prefix of a longer one
        in a mode they share:

        ${lib.concatMapStringsSep "\n" (c: "  - " + fmt c) violations}

        The shorter mapping's behaviour now depends on definition order.
        Defined last it stalls for `timeoutlen` on every press. Defined FIRST
        it fires immediately and the leftover suffix runs as a bare command —
        measured on `c1c2d7c`, where a stolen `<leader>l` left `p` to paste the
        SYSTEM CLIPBOARD into the buffer, `d` waiting for a motion to delete
        with, and `i`/`R` in insert and replace mode. Nothing about the
        keypress said so.

        Three ways out, in order of preference:

          1. Rename the shorter mapping so it is not a prefix — this is what
             `874ef06` did, and it is the only one that removes the ambiguity
             rather than choosing a side.
          2. Move one of them to a mode the other does not cover, if that
             matches how the key is actually used.
          3. Accept it deliberately, in `cvim.keymapGuard.allow`, with a reason
             that says why the delay is worth it. The shape is legitimate —
             vim ships `gc`/`gcc` — and this guard exists to make it a decision,
             not to ban it.

        IF THE FLAGGED PAIR IS MODE-DISJOINT, THE DETECTOR HAS REGRESSED. That
        shape is correct — `modules/zt/plugins.nix` binds `<leader>h` in visual
        mode against `<leader>hv` in normal — and
        `modules/keymap-guard/fixtures.nix` (`quiet.modeDisjoint`) asserts it
        stays quiet. FIX THE DETECTOR, NOT THE MODULE.
      '';
    }

    {
      assertion = live != [ ];
      message = ''
        The prefix-keymap guard read zero keymaps.

        Nothing is being checked and the invariant above passes vacuously —
        the exact failure an assertion exists to remove. Either every source in
        `modules/keymap-guard/default.nix` has been renamed out from under it,
        or this configuration genuinely binds no keys. Establish which before
        trusting any green build of this tree.
      '';
    }

    {
      assertion = luaUnread == 0;
      message = ''
        ${toString luaUnread} `vim.keymap.set(` call(s) in the generated
        init.lua are in a form this guard cannot read: ${toString luaTotal}
        total, ${toString luaLiteral} with literal `"mode", "key"` arguments,
        ${toString luaIterator} nixvim table iterators.

        Those mappings are NOT being checked for prefix collisions, and the
        guard would keep reporting zero over a set it never saw.

        The pattern reads a mode and a key that are both string literals.
        A table (`vim.keymap.set({ "n", "v" }, …)`) or a variable defeats it.
        Fix it at the source: split the table into one call per mode, or move
        the mapping into the `keymaps` option, where it is read as data and
        needs no parsing at all. Declaring it in `keymaps` is the better answer
        in almost every case.
      '';
    }

    {
      assertion = silentFires == [ ];
      message = ''
        The prefix-keymap guard no longer detects its own planted violations:

        ${lib.concatMapStringsSep "\n" (n: "  - fixtures.fires.${n}") silentFires}

        Each of those is a pair the guard exists to catch, and the detector now
        reads them as clean. Every green build of this tree is therefore
        meaningless — the guard would pass whether or not a real collision
        existed. `modules/keymap-guard/fixtures.nix` says which mechanism each
        fixture is the arm for. Repair the detector before trusting any result
        from it.
      '';
    }

    {
      assertion = noisyQuiets == [ ];
      message = ''
        The prefix-keymap guard now fires on correct code:

        ${lib.concatMapStringsSep "\n" (n: "  - fixtures.quiet.${n}") noisyQuiets}

        `quiet.modeDisjoint` is `<leader>h` in VISUAL mode against `<leader>hv`
        and `<leader>hm` in NORMAL — mode-disjoint, so no precedence conflict
        exists and nothing waits. It is copied from `modules/zt/plugins.nix`
        and that code is right. `quiet.siblingsNoPrefix` is an ordinary key
        cluster whose shared prefix is not itself a mapping, which describes
        most of the tree.

        Left standing this red-flags correct code, and the next reader with a
        red build works around the guard permanently. Narrow the detector back;
        do not touch the modules.
      '';
    }

    {
      assertion = blankReasons == [ ];
      message = ''
        These `cvim.keymapGuard.allow` entries have a blank reason:

        ${lib.concatMapStringsSep "\n" (
          e: "  - ${builtins.toJSON e.prefix} (mode ${builtins.toJSON e.mode})"
        ) blankReasons}

        The reason is the entire point of the opt-out. Accepting a
        `timeoutlen` stall is a legitimate call; accepting one without saying
        why leaves the next reader unable to tell a decision from an
        oversight, which is the state this guard was written to end.
      '';
    }
  ];
}
