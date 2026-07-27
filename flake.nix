{
  description = "cvim — ZT's Neovim distro, built directly on nixvim";

  inputs = {
    # No nixpkgs input and no `follows` on nixvim: cvim rides nixvim's own pin
    # so intermediate plugin derivation hashes match what nix-community's
    # cache already holds. Adding a nixpkgs input here would invalidate them.
    nixvim.url = "github:nix-community/nixvim";

    # Lean markdown formatter (mdformat + ship-set + baked flags). Its own
    # nixpkgs is intentional — it only builds a small python env that rides
    # into cvim's closure, so it never touches nixvim's plugin hashes.
    ccc-mdformat.url = "github:caoer/ccc-mdformat";
  };

  nixConfig = {
    extra-substituters = [
      # Public niks3 cache (R2 CDN) — CI pushes every build here.
      "https://cache.0xtau.com"
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.0xtau.com-1:M4y9SWhqZED/M9nvrYvJuxAlEj0umdXnxRYMgoXZxfU="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
    allow-import-from-derivation = false;
  };

  outputs =
    { nixvim, ccc-mdformat, ... }:
    let
      lib = nixvim.inputs.nixpkgs.lib;

      # nixvim itself supports exactly these three; they are also the CI matrix.
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      # Evaluate a cvim configuration. Returns the full module-system result,
      # so callers keep `extendModules` for host-side customization.
      mkConfig =
        {
          system,
          profile,
          extraModules ? [ ],
        }:
        nixvim.lib.evalNixvim {
          inherit system;
          modules = [
            ./modules
            { cvim.profile = profile; }
            # Thread the ccc-mdformat binary into the modules. `_module.args`
            # is the module-system-native inject; no specialArgs plumbing.
            { _module.args.cccMdformat = ccc-mdformat.packages.${system}.default; }
          ]
          ++ extraModules;
        };

      # `bin/cvim` is added by extending the existing package's build, NOT by
      # wrapping it in a new symlinkJoin/runCommand. A wrapper would drop
      # `passthru.config` / `passthru.options` and break host-side
      # `extendModules` and the checks.
      #
      # It has to be `buildCommand` and not `postBuild`: nixvim's package is a
      # `symlinkJoin`, which interpolates `postBuild` into `buildCommand` when
      # the derivation is constructed. `overrideAttrs` runs after that, so an
      # appended `postBuild` lands as an environment variable that nothing
      # ever reads — the build succeeds and the symlink silently never
      # appears. Appending to `buildCommand` extends the same derivation and
      # keeps the passthru.
      mkPackage =
        configuration:
        configuration.config.build.package.overrideAttrs (o: {
          buildCommand = o.buildCommand + ''
            ln -sf $out/bin/nvim $out/bin/cvim
          '';
        });

      # `lab` is the workstation config plus the scratch layer. The lab modules
      # are reachable from here and nowhere else — `default` and `server` must
      # never see them.
      configurationsFor = system: {
        default = mkConfig {
          inherit system;
          profile = "default";
        };
        server = mkConfig {
          inherit system;
          profile = "server";
        };
        lab = mkConfig {
          inherit system;
          profile = "default";
          extraModules = [ ./lab ];
        };
      };
    in
    {
      # The evaluated configurations, exported for host-side `extendModules`.
      nixvimConfigurations = forAllSystems configurationsFor;

      packages = forAllSystems (system: lib.mapAttrs (_: mkPackage) (configurationsFor system));

      checks = forAllSystems (
        system: lib.mapAttrs (_: c: c.config.build.test) (configurationsFor system)
      );

      formatter = forAllSystems (system: nixvim.inputs.nixpkgs.legacyPackages.${system}.nixfmt-tree);
    };
}
