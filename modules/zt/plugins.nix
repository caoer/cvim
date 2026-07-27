# The four utility plugins that belong to no other layer: nvim-sops, hurl,
# videre, csvview. All are `optional = true` and loaded by `packadd` on a
# trigger, so none of them costs anything at startup.
#
# WHY NOT lz.n: the conventions file allows `luaConfig.post` and forbids the
# `after` key under an lz.n settings attrset. As of 2026-07-27 the CI lint for
# that rule is a token grep blind to the nested forms, and the fleet audit
# found zero lz.n uses across all eight branches — the lint fix is meant to
# land before lz.n usage does. These four keep the ported `optional` +
# `packadd` mechanism, which does not touch that surface at all.
#
# (Worded to avoid the literal token: the lint greps text, so a comment
# *about* the rule trips it. u4b hit the same thing.)
#
# THE `require("sops")` BUG (§ "Known pre-existing bug" on the U9b card) is
# fixed here, and the memo's diagnosis was wrong. It was attributed to
# lzn-auto-require's shim missing. It is not: nvim-sops ships its Lua under
# `lua/nvim_sops/`, so the module is `nvim_sops` and `require("sops")` names a
# module that has never existed. See ./plugins.nix notes at the sops block.
#
# Binaries: hurl, jq and sops are declared in `extraPackages` rather than
# inherited from the ambient shell. U5 hit exactly this — `rg`/`fd` worked on
# ZT's mac and failed on a bare server profile.
#
# Editor-surface states:
#   empty    No trigger fired — none of the four is in `runtimepath` and no
#            command of theirs exists. `:Videre` is the one exception: a stub
#            command stands in so the name is always available.
#   partial  Plugin loaded but its binary missing: hurl and sops both report
#            the failure in their own output. `extraPackages` is what keeps
#            that from being the normal case.
#   error    A `packadd` that fails leaves the stub commands in place; they
#            check the plugin's own loaded-flag and report rather than
#            recursing into themselves.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.utilities;

  # Vendored: videre.nvim is not in nixpkgs, so it carries a pinned `rev` +
  # `hash` per the conventions file's provenance rule. Upstream is small and
  # low-traffic; the pin is what makes the build reproducible rather than
  # tracking whatever HEAD happens to be.
  videre-nvim = pkgs.vimUtils.buildVimPlugin {
    pname = "videre-nvim";
    version = "unstable-2025-04-03";
    src = pkgs.fetchFromGitHub {
      owner = "Owen-Dechow";
      repo = "videre.nvim";
      rev = "785ede15e3b280fbf5a6d36823eb74122cd85a83";
      hash = "sha256-GAbSWhaEB5XnH2DGYQAXgWJCm5zHhLJaQ6WTbbVTWJk=";
    };
    doCheck = false;
    meta.homepage = "https://github.com/Owen-Dechow/videre.nvim";
  };
in
{
  config = lib.mkIf cfg.enable {
    extraPlugins = [
      {
        plugin = pkgs.vimPlugins.hurl-nvim;
        optional = true;
      }
      {
        plugin = pkgs.vimPlugins.nvim-sops;
        optional = true;
      }
      {
        plugin = videre-nvim;
        optional = true;
      }
      {
        plugin = pkgs.vimPlugins.csvview-nvim;
        optional = true;
      }
    ];

    # The binaries these three shell out to. Declared, not inherited.
    extraPackages = [
      pkgs.hurl
      pkgs.jq
      pkgs.sops
    ];

    keymaps = [
      {
        mode = "n";
        key = "<leader>cz";
        action = "<cmd>SopsDecrypt<cr>";
        options = {
          desc = "Decrypt SOPS file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>ce";
        action = "<cmd>SopsEncrypt<cr>";
        options = {
          desc = "Encrypt SOPS file";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>jv";
        action = "<cmd>Videre<cr>";
        options = {
          desc = "JSON Graph Explorer";
          silent = true;
        };
      }
    ];

    extraConfigLua = ''
      -- `packadd` takes the plugin's DIRECTORY name under pack/*/opt, which is
      -- the nixpkgs `pname` and not always the attribute name: it is
      -- `hurl.nvim` and `csvview.nvim`, but `nvim-sops`. cnixvim used
      -- `packadd hurl-nvim`, which silently never matched, so hurl's
      -- lazy-load has never fired there either — the failure only surfaces as
      -- a `module 'hurl' not found` traceback from inside a FileType autocmd,
      -- which reads like a plugin bug rather than a name typo.
      --
      -- Wrapping it makes a wrong name say so in one line, at the moment it
      -- happens. Names verified against `globpath(&packpath, "pack/*/opt/*")`
      -- in the built editor, not assumed.
      local function zt_packadd(dir)
        local ok = pcall(vim.cmd, "packadd " .. dir)
        if not ok then
          vim.notify("cvim: packadd failed for '" .. dir .. "'", vim.log.levels.ERROR)
        end
        return ok
      end

      -- ── nvim-sops ────────────────────────────────────────────────────────
      -- The plugin's own plugin/nvim_sops.vim defines :SopsDecrypt and
      -- :SopsEncrypt, calls setup{} and sets g:loaded_nvim_sops, so `packadd`
      -- is the whole of the wiring. cnixvim additionally called
      -- require("sops").setup({ auto_decrypt = true, auto_encrypt = true }),
      -- which was wrong twice over: the module is `nvim_sops`, and neither
      -- option exists in nvim_sops.setup (it reads enabled/debug/binPath and
      -- defaults.*). Decryption is manual, via the commands.
      local function zt_sops_load()
        if vim.g.loaded_nvim_sops == 1 then return true end
        zt_packadd("nvim-sops")
        return vim.g.loaded_nvim_sops == 1
      end

      -- Stub commands so <leader>cz / <leader>ce work in any buffer, not only
      -- one the autocmd below already matched. packadd redefines both with
      -- `command!`, so the stub is replaced rather than shadowed; the
      -- loaded-flag check is what stops a failed packadd recursing.
      for _, name in ipairs({ "SopsDecrypt", "SopsEncrypt" }) do
        vim.api.nvim_create_user_command(name, function()
          if not zt_sops_load() then
            vim.notify("nvim-sops failed to load", vim.log.levels.ERROR)
            return
          end
          vim.cmd(name)
        end, { desc = "nvim-sops: " .. name .. " (lazy)" })
      end

      -- Load on any sops-encrypted file so the commands are ready. BufReadPost
      -- deliberately: the secret guard's BufReadPre has already cleared
      -- undofile/swapfile for this buffer by the time this runs.
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
        pattern = { "*.sops.*" },
        callback = function() zt_sops_load() end,
      })

      -- ── hurl.nvim ────────────────────────────────────────────────────────
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "hurl",
        callback = function(args)
          if not vim.g.zt_hurl_loaded then
            if not zt_packadd("hurl.nvim") then return end
            require("hurl").setup({
              mode = "split",
              show_notification = false,
              formatters = { json = { "jq" } },
            })
            -- Set only after a load that worked, so a failure does not latch
            -- the buffer into a half-configured state for the session.
            vim.g.zt_hurl_loaded = true
          end

          local function opts(desc)
            return { buffer = args.buf, desc = desc, silent = true }
          end
          vim.keymap.set("n", "<leader>ha", "<cmd>HurlRunner<CR>", opts("Hurl: Run all requests"))
          vim.keymap.set("n", "<leader>he", "<cmd>HurlRunnerAt<CR>", opts("Hurl: Run at cursor"))
          vim.keymap.set("n", "<leader>hE", "<cmd>HurlRunnerToEnd<CR>", opts("Hurl: Run to end"))
          vim.keymap.set("n", "<leader>hv", "<cmd>HurlVerbose<CR>", opts("Hurl: Run verbose"))
          vim.keymap.set("n", "<leader>hm", "<cmd>HurlToggleMode<CR>", opts("Hurl: Toggle popup/split"))
          vim.keymap.set("v", "<leader>h", ":HurlRunner<CR>", opts("Hurl: Run selection"))
        end,
      })

      -- ── videre.nvim ──────────────────────────────────────────────────────
      -- videre's plugin/videre.lua requires the module, whose body registers
      -- :Videre — so `packadd` OVERWRITES this stub with the real command and
      -- nothing further is needed.
      --
      -- cnixvim instead ran `delcommand Videre` after the packadd, which
      -- deleted the real command it had just loaded, leaving :Videre and
      -- <leader>jv failing with E492. It also forwarded `nargs = "?"` while
      -- videre's command takes none. Both are dropped.
      --
      -- `videre_loaded` is the recursion guard: if a future videre stops
      -- registering the command, the second entry reports instead of looping.
      local videre_loaded = false
      vim.api.nvim_create_user_command("Videre", function()
        if videre_loaded then
          vim.notify("videre.nvim did not register :Videre", vim.log.levels.ERROR)
          return
        end
        videre_loaded = true
        if not zt_packadd("videre-nvim") then return end
        vim.cmd("Videre")
      end, { desc = "JSON Graph Explorer (lazy)" })

      -- ── csvview.nvim ─────────────────────────────────────────────────────
      vim.api.nvim_create_autocmd("FileType", {
        pattern = { "csv", "tsv" },
        callback = function(args)
          if not vim.g.zt_csvview_loaded then
            if not zt_packadd("csvview.nvim") then return end
            require("csvview").setup({ view = { display_mode = "border" } })
            vim.g.zt_csvview_loaded = true
          end
          local csvview = require("csvview")
          if not csvview.is_enabled(args.buf) then
            csvview.enable(args.buf)
          end
          vim.keymap.set("n", "<leader>tv", "<cmd>CsvViewToggle<cr>",
            { buffer = args.buf, desc = "CSV: toggle table view", silent = true })
        end,
      })
    '';
  };
}
