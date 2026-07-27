# Filetype associations — ported from cnixvim's "Custom filetype associations"
# section, plus the dosini commentstring that only makes sense alongside them.
#
# The `pattern` keys are Lua patterns, not globs: `%.` is a literal dot and
# `%-` a literal dash. Getting that wrong fails silently — the association
# simply never matches — so they are copied verbatim rather than retyped.
#
# Editor-surface states:
#   empty    No file open, or a file matching none of these — vim's own
#            filetype detection applies unchanged.
#   partial  Not applicable: a filetype either matches or it does not.
#   error    A malformed Lua pattern does not raise; it silently never
#            matches. Verified by opening a file of each kind and reading
#            `:set filetype?` back, not by inspecting this table.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    filetype = {
      extension = {
        conf = "toml";
        dconf = "toml";
        har = "json";
      };
      filename = {
        "Cargo.lock" = "toml";
      };
      pattern = {
        "%.config/.*" = "toml";
        ".*surge%-config/providers/.*%.txt" = "dosini";
      };
    };

    autoCmd = [
      {
        # dosini's default commentstring is empty, so `gc` is a no-op on the
        # surge provider files matched above until this is set.
        event = [ "FileType" ];
        pattern = [ "dosini" ];
        callback.__raw = ''
          function(args)
            vim.bo[args.buf].commentstring = "# %s"
          end
        '';
      }
    ];
  };
}
