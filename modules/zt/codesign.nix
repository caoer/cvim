# macOS: re-sign treesitter parser `.so` files, and `:TSCodesign` to do it manually.
#
# macOS Sequoia hardened the loader: a `.dylib`/`.so` whose signature does not
# match its contents is refused at dlopen. Parsers written into the user site
# directory by anything other than nix (`:TSInstall`, a manual copy, an rsync
# from another machine) carry a stale or absent signature and fail to load, with
# the failure surfacing as "no highlights" rather than as a load error.
#
# `codesign -f -s -` is an ad-hoc signature: no identity, no certificate, no
# network. It only makes the signature match the bytes.
#
# The VimEnter probe checks ONE parser (`lua.so`) and only sweeps when that
# check fails, so the common case costs a single `codesign --verify` and no
# process spawn. The sweep itself is `jobstart(..., { detach = true })` — it
# never blocks startup.
#
# This is guarded on `has("mac")` at build time via `lib.optionalAttrs`, so on
# Linux the autocmd and the command do not exist at all rather than existing
# and doing nothing.
#
# empty:   no parser directory, or no `.so` in it — `ls` fails, `first` is nil,
#          and nothing is spawned. This is the normal case for a pure-nix cvim,
#          where parsers live in the store and are already valid.
# partial: a directory holding a mix of valid and stale parsers gets every file
#          re-signed, not just the stale ones; `codesign -f` is idempotent on an
#          already-valid file.
# error:   `codesign` failing on an individual file is swallowed per-file by
#          `2>/dev/null`, so one unsignable parser cannot abort the sweep for
#          the rest.
#          Capture: results/captures/u9a/u9a-codesign.txt.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf (cfg.enable && pkgs.stdenv.hostPlatform.isDarwin) {
    extraConfigLua = ''
      local function sign_treesitter_parsers()
        local parser_dir = vim.fn.stdpath("data") .. "/site/parser"
        local handle = io.popen('ls "' .. parser_dir .. '"/*.so 2>/dev/null | head -1')
        if handle then
          local first = handle:read("*l")
          handle:close()
          if first then
            vim.fn.jobstart(
              { "sh", "-c", 'for f in "' .. parser_dir .. '"/*.so; do codesign -f -s - "$f" 2>/dev/null; done' },
              { detach = true }
            )
          end
        end
      end

      vim.api.nvim_create_user_command("TSCodesign", function()
        sign_treesitter_parsers()
        vim.notify("Signing treesitter parsers...")
      end, { desc = "Codesign treesitter parser .so files (macOS)" })

      vim.api.nvim_create_autocmd("VimEnter", {
        callback = function()
          vim.schedule(function()
            local parser_dir = vim.fn.stdpath("data") .. "/site/parser"
            local result = vim.fn.system("codesign --verify " .. parser_dir .. "/lua.so 2>&1")
            if vim.v.shell_error ~= 0 then
              sign_treesitter_parsers()
            end
          end)
        end,
      })
    '';
  };
}
