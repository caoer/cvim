# `cvim.editor` — The editing core.
{ lib, ... }:
{
  options.cvim.editor = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        The editing core: syntax, completion, formatting, linting, motions,
        and the text-object/surround family.

        This is the layer every other layer assumes. Turning it off gives you
        nixvim's bare defaults, which is a legitimate thing to want when you are
        bisecting a problem.
      '';
    };

    leader = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = " ";
      example = null;
      description = ''
        The `<leader>` key, applied as `vim.g.mapleader`.

        `null` means "set nothing", which leaves Neovim's built-in default of
        backslash. That is a real answer, not an unset one — but it is almost
        never the one you want, because every `<leader>` mapping in every layer
        resolves against whatever this is *at the moment the mapping is
        defined*. A distro that sets no leader silently binds its entire keymap
        surface onto backslash.
      '';
    };

    localLeader = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = " ";
      example = null;
      description = ''
        The `<localleader>` key, applied as `vim.g.maplocalleader`.

        Declared separately from {option}`cvim.editor.leader` because Neovim
        keeps them separate and filetype plugins bind to this one. `null`
        leaves Neovim's default of backslash.
      '';
    };

    largeBufferBytes = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = 1048576; # 1 MiB
      example = null;
      description = ''
        File size, in bytes, above which a buffer is treated as large: syntax,
        treesitter highlighting and linting are switched off for that buffer
        only.

        `null` disables the detector entirely, so every buffer is treated
        normally however big it is.
      '';
    };
  };
}
