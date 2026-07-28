# Platform-conditional guard — no platform-conditional block may carry plugin
# configuration.
#
# WHAT THIS CLOSES. The CI lint (`.github/workflows/build-and-cache.yml`, the
# `lz.n lint` step) asks its two questions of
# `.#nixvimConfigurations.x86_64-linux.<config>` and of nothing else. Anything
# that exists only on darwin is, to that lint, not there — so a darwin-only
# block declaring a plugin with a `lazyLoad` spec passes it, green, every time.
#
# That hole is EMPTY today, and empty because of what the tree contains rather
# than how the lint is built: the one system-conditional block in the tree
# (`modules/zt/codesign.nix`) carries `extraConfigLua` and no plugin config at
# all. Write one darwin-conditional plugin block and the hole is real
# immediately, with nothing to say so. This file makes "empty" structural
# instead of incidental, and `codesign.nix` already satisfies it.
#
# WHY AN ASSERTION AND NOT A CI JOB. Same reason as `modules/core/lazy.nix`,
# measured again here: an assertion rides EVERY package build, including a
# host's own `extendModules` build with option values the CI matrix never
# instantiates. A CI check only ever sees the three outputs CI builds. The
# alternative on the table was matrixing the lint across all three systems —
# rejected: `lint` runs in seconds and `build` has `needs: lint`, so that speed
# is load-bearing for the whole pipeline, and it would spend minutes of scarce
# darwin runner time on a residue of zero. This costs no runner time at all.
#
# WHY THIS ONE IS TEXT AND `lazy.nix` IS NOT. `lazy.nix` interrogates the
# EVALUATED module, which is strictly better and is the house default — every
# spelling of an option is the same attrset once merged, so no comment or Lua
# string can trigger it. That is unavailable here by construction: once the
# module system has merged, `mkIf` has already been resolved and the evaluated
# config no longer records that a definition was conditional. The property is
# about the SOURCE, so the source is what gets read.
#
# That trade is paid for below with a self-test, because a text rule that is
# wrong is worse than none.
#
# THE NEAR-MISS THAT SHAPES THE RULE. `git grep hostPlatform -- modules/`
# returns five hits and only ONE is a condition. The other four are
# `${pkgs.stdenv.hostPlatform.system}` interpolated into an assertion MESSAGE
# in `modules/lang/{java,cpp,rust,csharp}.nix` — string interpolation, not a
# guard on a config block, evaluating identically on every system. All four are
# correct, and all four also declare plugin config, so a rule keyed on the
# token fires on four correct files on day one. A check that red-flags correct
# code teaches people to route around it.
#
# So the rule keys on the CONDITION: interpolations are removed before the
# platform predicate is looked for, and the predicate matched is a BOOLEAN one
# (`hostPlatform.is*`, `stdenv.is*`, a comparison against `hostPlatform.system`)
# rather than the bare `.system` string those messages interpolate.
#
# SCOPE. `modules/` — the tree every configuration imports. `lab/` is the
# scratch layer and is deliberately not scanned; the justfile's loop hardens
# what survives into `modules/<layer>/`, which is where this guard meets it.
{
  lib,
  ...
}:
let
  root = ./..;

  # ---------------------------------------------------------------- detector

  removeMatches =
    re: text: builtins.concatStringsSep "" (builtins.filter builtins.isString (builtins.split re text));

  matches = re: text: builtins.length (builtins.split re text) > 1;

  # Full-line `#` comments only. Anchoring to the start of the line is the
  # point: this tree writes long comment headers that name the very tokens
  # below, and stripping from any mid-line `#` would eat the rest of lines
  # holding a Lua string or a `"#1a1b26"` colour.
  dropComments =
    text:
    builtins.concatStringsSep "\n" (
      builtins.filter (line: builtins.match "[[:space:]]*#.*" line == null) (
        builtins.filter builtins.isString (builtins.split "\n" text)
      )
    );

  # `${…}` antiquotations. Applied twice so one level of nesting is removed
  # too; `[^{}]*` cannot run past a brace, so each pass is bounded.
  #
  # `$`, `{` and `}` are spelled as bracket expressions rather than backslash
  # escapes. POSIX ERE leaves `\{` undefined, and the two `std::regex`
  # implementations Nix is built against disagree: libc++ accepts `\$\{…\}`, so
  # darwin evaluated it green, while libstdc++ rejects the whole pattern and
  # every linux build died with `invalid regular expression`. Inside a bracket
  # expression all three are literal on both.
  dropInterpolations =
    let
      pass = removeMatches "[$][{][^{}]*[}]";
    in
    text: pass (pass text);

  code = text: dropInterpolations (dropComments text);

  platformCondition = "(hostPlatform\\.is|stdenv\\.is|hostPlatform\\.system[[:space:]]*(==|!=))";
  pluginConfig = "(plugins\\.[a-zA-Z]|lazyLoad|extraPlugins)";

  classify =
    text:
    let
      c = code text;
    in
    {
      conditional = matches platformCondition c;
      plugins = matches pluginConfig c;
    };

  # ------------------------------------------------------------- the scan
  #
  # `platform-guard/` itself is skipped, and not as a convenience. This
  # directory is the only place in the tree that must SPELL the tokens it
  # hunts — in the patterns above, in the fixtures, and in the messages below.
  # Scanning it makes the guard's own vocabulary look like the thing it
  # forbids, so it would flag itself the moment a message quoted a predicate.
  # Measured, not predicted: with the naive token rule the only file flagged
  # tree-wide was this one. The directory holds no plugin config and no
  # platform condition by construction, so there is nothing here to check.

  walk =
    prefix: dir:
    lib.concatLists (
      lib.mapAttrsToList (
        name: type:
        let
          rel = prefix + name;
        in
        if type == "directory" then
          lib.optionals (rel != "platform-guard") (walk (rel + "/") (dir + "/${name}"))
        else if lib.hasSuffix ".nix" name then
          [
            {
              inherit rel;
              verdict = classify (builtins.readFile (dir + "/${name}"));
            }
          ]
        else
          [ ]
      ) (builtins.readDir dir)
    );

  scanned = walk "" root;
  violations = map (f: f.rel) (
    builtins.filter (f: f.verdict.conditional && f.verdict.plugins) scanned
  );

  # ------------------------------------------------------------- self-test
  #
  # Two planted fixtures, checked on every build. The violation fixture proves
  # the detector still FIRES; the near-miss fixture proves it still stays
  # QUIET on the shape four correct modules use. Both arms are required —
  # a guard proven only against a violation cannot be told apart from one that
  # always fails, and a guard proven only against correct code cannot be told
  # apart from one that never fires.

  fires = classify (builtins.readFile ./fixtures/fires.nix);
  quiet = classify (builtins.readFile ./fixtures/quiet.nix);
in
{
  config.assertions = [
    {
      assertion = violations == [ ];
      message = ''
        These files carry BOTH a platform condition and plugin configuration:

        ${lib.concatMapStringsSep "\n" (rel: "  - modules/${rel}") violations}

        Plugin config reached through a platform condition is invisible to the
        CI lint, which evaluates `x86_64-linux` and only `x86_64-linux`. A
        darwin-only plugin — or a darwin-only `lazyLoad` spec — is simply not
        in the config that lint sees, so it passes green while the plugin is
        never loaded on the platform that has it.

        Split the file: keep the platform-conditional block free of plugin
        config (`modules/zt/codesign.nix` is the shape that works — a
        `mkIf … isDarwin` carrying `extraConfigLua` and nothing else), and
        declare the plugin unconditionally, driving the platform difference
        through its settings instead.

        If the flagged line is `hostPlatform` inside an assertion MESSAGE
        rather than a condition, the detector has regressed — that shape is
        correct and `modules/platform-guard/fixtures/quiet.nix` asserts it stays
        quiet. Fix the detector, not the module.
      '';
    }

    {
      assertion = scanned != [ ];
      message = ''
        The platform guard scanned zero files under `modules/`.

        Nothing is being checked, and the invariant assertion above passes
        vacuously — the exact failure mode an assertion is supposed to remove.
        The directory walk in `modules/platform-guard/default.nix` is broken.
      '';
    }

    {
      assertion = fires.conditional && fires.plugins;
      message = ''
        The platform guard no longer detects its own planted violation.

        `modules/platform-guard/fixtures/fires.nix` is a platform-conditional
        block declaring a plugin with a `lazyLoad` spec — the exact shape this
        guard exists to catch — and the detector now reads it as
        conditional=${lib.boolToString fires.conditional}, plugins=${lib.boolToString fires.plugins}.

        Every green build of this tree is therefore meaningless: the guard
        would pass whether or not a real violation existed. Repair the
        detector before trusting any result from it.
      '';
    }

    {
      assertion = quiet.plugins && !quiet.conditional;
      message = ''
        The platform guard now fires on correct code.

        `modules/platform-guard/fixtures/quiet.nix` interpolates
        `${"\${pkgs.stdenv.hostPlatform.system}"}` into an assertion MESSAGE in a
        file that also declares plugin config. That is not a platform
        condition, and four real modules use it —
        `modules/lang/{java,cpp,rust,csharp}.nix`. The detector now reads the
        fixture as conditional=${lib.boolToString quiet.conditional},
        plugins=${lib.boolToString quiet.plugins}.

        Left standing, this red-flags four correct files and teaches the next
        reader to route around the guard. Narrow the rule back to the
        condition; do not touch the four modules.
      '';
    }
  ];
}
