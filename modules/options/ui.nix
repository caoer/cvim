# `cvim.ui` — Appearance and chrome.
{ lib, ... }:
{
  options.cvim.ui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Appearance and chrome: colorscheme, statusline, buffer line, keymap
        hints, notifications, and markup rendering.
      '';
    };

    theme.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to set a colorscheme.

        `true` gives you tokyonight, following the terminal's appearance over
        OSC 11 — night when the terminal is dark, day when it is light.

        `false` leaves neovim on its built-in colorscheme. That is the right
        answer when you are bisecting a highlight bug and need to know whether
        the theme is the cause, and it is why this is an option rather than an
        assumption.
      '';
    };

    bufferline.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to show open buffers as a tab line.

        Tabs are numbered by position, and `<leader>1` through `<leader>9` jump
        to the Nth visible tab. Turning this off removes the tab line and those
        nine keymaps together, since a positional jump is meaningless without
        the positions being on screen.
      '';
    };

    whichKey.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to show a popup of available keymaps after a prefix key.

        The `<leader>1-9` buffer jumps are hidden from the popup — they stay
        bound, they just do not crowd out the mnemonic groups.

        `false` is a real answer, not a degraded one: the popup is a discovery
        aid, and once the bindings are in your fingers it is a window that opens
        while you are already typing the next key.
      '';
    };

    notifications.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to route messages and notifications through a popup UI.

        This also installs the startup queue: notifications emitted before the
        popup backend exists are held and replayed into it rather than being
        lost to the first redraw.

        `false` gives you neovim's own message area, which is the right answer
        when you are debugging something that notifies during startup and you
        want the raw ordering.
      '';
    };

    icons.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to show file-type icons, and to register them under the
        `nvim-web-devicons` name so plugins expecting that module find them.

        `false` is correct for a terminal without a patched font, where every
        glyph would otherwise render as a replacement box.
      '';
    };

    markview.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = ''
        Whether to render markdown markup — headings, checkboxes, tables,
        blockquotes — as decoration while editing.

        The buffer text is never rewritten; this is a display layer only.
      '';
    };

    smartcolumn = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        example = false;
        description = ''
          Whether to draw a column guide, and only in buffers that have a line
          long enough to earn one.
        '';
      };

      column = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        example = 100;
        description = ''
          Which column to guide at.

          `null` keeps the plugin's own default of 80, which is also the width
          this layer is verified at. Set a number to override it.
        '';
      };
    };
  };
}
