# D10 lint: `plugins.<name>.lazyLoad.settings.after` is forbidden.
#
# WHY, from nixvim's own source rather than from reputation
# (lib/plugins/mk-neovim-plugin.nix, the lz-n routing block):
#
#     after =
#       let
#         after = cfg.lazyLoad.settings.after or null;
#         default = if hasLuaConfig then "function()\n " + cfg.luaConfig.content + " \nend" else null;
#       in
#       if (lib.isString after || lib.types.rawLua.check after) then after else default;
#
# A string `after` REPLACES the wrapped `luaConfig.content`; it does not append to
# it. Setting it silently drops the plugin's entire generated config, and the
# build still succeeds. `luaConfig.post` is the appending form.
#
# WHY THIS ASKS THE EVALUATED MODULE AND NOT THE TEXT. `grep` matches a spelling,
# and this option has arbitrarily many:
#
#     plugins.a.lazyLoad.settings.after = "…";               # flat
#     plugins.b.lazyLoad.settings = { after = "…"; };        # nested
#     plugins.c.lazyLoad = { settings = { after = "…"; }; }; # deeper
#
# After module merging all three are ONE attrset — the difference exists only in
# the serialization. A regex written from the first form is blind to the other
# two, and tuning the regex is a race against how someone chose to nest braces.
# Reading the evaluated config wins that race permanently: B and C are not
# special cases here, they are the same value. It also cannot fire on a comment
# or a Lua string, because neither is an option definition — and a rule whose
# only real defence is that people know about it must not punish them for writing
# that knowledge down.
#
# Evaluation only, so this is safe with `allow-import-from-derivation = false`:
# it forces the module system, never a derivation.
#
# The candidate filter is nixvim's own, from modules/lazyload.nix — an option
# node that is a real option and is visible. That matters: iterating
# `config.plugins` blindly forces removed options such as `plugins.nvim-osc52`,
# whose value is a `throw`, and the lint dies on an unrelated error. nixvim runs
# this same filter on every build, so it is known to hold for this plugin set.
#
# Takes an evaluated nixvim configuration (`nixvimConfigurations.<system>.<name>`)
# and returns the offending option paths, newline-separated. Empty means clean.
#
# `after` is flagged whether or not `lazyLoad.enable` is set. The routing block
# above sits behind `mkIf cfg.lazyLoad.enable`, so a violation with lazy loading
# off is latent rather than live — it starts dropping config the moment somebody
# enables it, which is exactly when nobody is looking for this.
module:
let
  opts = module.options.plugins;
  cfg = module.config.plugins;

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
      node = opts.${name}.lazyLoad or null;
    in
    isOption node && isVisible node
  ) (builtins.attrNames cfg);

  offenders = builtins.filter (name: cfg.${name}.lazyLoad.settings ? after) lazyLoadable;
in
builtins.concatStringsSep "\n" (map (name: "plugins.${name}.lazyLoad.settings.after") offenders)
