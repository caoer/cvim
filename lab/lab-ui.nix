# Scratch space for the `ui` layer. Empty is the resting state.
#
# Candidates go here, get built as `.#lab`, and either graduate into
# `modules/ui/` or get deleted. Nothing here ships.
#
# ITERATION 2 — iteration 1 (theme, bufferline, which-key, noice/notify,
# mini-icons, markview, smartcolumn) plus the two dashboard candidates and a
# deliberate early notification that proves the startup replay actually flushes.
# snacks.image is held for iteration 3: it shells out and it fetches, so it gets
# trialled on its own where a failure cannot be blamed on anything else.
{ lib, pkgs, ... }:
{
  colorschemes.tokyonight = {
    enable = true;
    settings = {
      style = "night";
      light_style = "day";
    };
  };

  plugins = {
    bufferline = {
      enable = true;
      settings.options.numbers = "ordinal";
    };

    which-key = {
      enable = true;
      settings.spec = map (n: {
        __unkeyed-1 = "<leader>${toString n}";
        hidden = true;
      }) (lib.range 1 9);
    };

    noice.enable = true;
    notify.enable = true;

    mini-icons = {
      enable = true;
      mockDevIcons = true;
    };

    markview = {
      enable = true;
      settings.preview.icon_provider = "mini";
    };

    smartcolumn.enable = true;

    # Dashboard candidate A. `settings` here is freeform — nixvim declares no
    # `dashboard` sub-options — so a typo would evaluate clean and no-op. Which
    # is exactly why this gets read back out of the running editor.
    snacks = {
      enable = true;
      # ITERATION 3 — image rendering. Held until last on purpose: it shells out
      # (imagemagick, mmdc) and mmdc fetches a browser, so a failure here must
      # not be confusable with anything else in the layer.
      settings.image.enabled = true;

      settings.dashboard = {
        enabled = true;
        # snacks' DEFAULT preset is { header, keys, startup } and its `startup`
        # section calls require("lazy.stats") with no guard (dashboard.lua:1095),
        # so it throws E5108 on any setup without lazy.nvim — which is every
        # nixvim setup. Naming the sections explicitly is the whole fix.
        sections = [
          { section = "header"; }
          {
            section = "keys";
            gap = 1;
            padding = 1;
          }
        ];
      };
    };

    # Dashboard candidate B. Both are enabled in the same build on purpose: one
    # wins the startup screen, and the loser opens on demand
    # (`:lua Snacks.dashboard()` / `:lua MiniStarter.open()`), so a single build
    # yields a capture of each instead of two builds yielding one apiece.
    # ITERATION 2b: mini-starter off, so snacks owns the startup screen and the
    # sections fix is verified rather than hidden behind the other candidate.
    mini-starter.enable = false;
  };

  # mmdc drives a headless browser through puppeteer. Its bundled default expects
  # a Chromium that nixpkgs does not build for darwin, so on darwin it must be
  # pointed at the installed Chrome or `mmdc` is simply broken (§6 row 13).
  extraPackages = [ pkgs.mermaid-cli ];
  env = lib.optionalAttrs pkgs.stdenv.isDarwin {
    PUPPETEER_EXECUTABLE_PATH = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
  };

  extraConfigLuaPre = ''
    do
      local queued = {}
      local original = vim.notify
      local function capture(...)
        table.insert(queued, vim.F.pack_len(...))
      end
      vim.notify = capture

      local timer = assert(vim.uv.new_timer())
      local check = assert(vim.uv.new_check())
      vim.g.cvim_notify_replayed = 0

      local function replay()
        timer:stop()
        check:stop()
        if vim.notify == capture then
          vim.notify = original
        end
        vim.schedule(function()
          for _, args in ipairs(queued) do
            vim.notify(vim.F.unpack_len(args))
          end
          vim.g.cvim_notify_replayed = #queued
          queued = {}
        end)
      end

      check:start(function()
        if vim.notify ~= capture then
          replay()
        end
      end)
      timer:start(500, 0, replay)
    end

    -- LAB PROBE ONLY, never hardened. This notification fires while vim.notify
    -- is still the capture function, so it can only ever be seen if the queue
    -- really is flushed into the plugin that replaced vim.notify. `replayed=0`
    -- proves nothing on its own; this makes the counter say 1.
    vim.notify("cvim lab: startup replay probe", vim.log.levels.WARN)
  '';

  keymaps = map (n: {
    mode = "n";
    key = "<leader>${toString n}";
    action = "<cmd>BufferLineGoToBuffer ${toString n}<cr>";
    options = {
      desc = "Go to buffer ${toString n}";
      silent = true;
    };
  }) (lib.range 1 9);
}
