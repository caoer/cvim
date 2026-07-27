# Secret-persistence guard — §6 row 15, plus the shada register cap (row 16)
# and the `swapfile = true` default that row 10 makes the surrounding rule.
#
# Ported from cnixvim `c1b8ab7` (guard) and `abe9eb6` (shada cap), both
# verified live on ZT's mac. The incident behind it: 40 undo files under
# `~/.local/share/nvim/undo/` held age master keys, SSH private keys, and
# GitHub/AWS/Anthropic tokens, under filenames that spell out the source path.
#
# Editor-surface states:
#   empty    No secret-shaped buffer open — nothing runs; ordinary buffers keep
#            `swapfile` on and whatever `undofile` the distro sets.
#   partial  Path layer fires alone on a secret-shaped NAME whose content holds
#            no recognised key material. Persistence off, no message.
#   error    Content probe fires on a matched buffer and emits a WARN notify
#            ("secret detected: undo/swap persistence disabled for this
#            buffer"). A delete of a stale undo file that fails is silent by
#            design — the buffer is already unprotected either way.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    opts = {
      # THE SUBSTRATE THE GUARD STANDS ON. cvim inherits nothing — it has no
      # khanelivim, so all 35 globals and 71 opts cnixvim got that way are
      # unset here, and neovim's own default for `undofile` is OFF.
      #
      # That matters more than it looks. The guard below clears `undofile` and
      # `swapfile` BUFFER-LOCALLY for secret paths. If neither is ever set
      # globally, it clears something that was never on — "the guard is
      # present" would stop meaning "the leak is closed", and every check
      # still passes. So the pair is set here, beside the guard that depends
      # on it, and both are verified in the same running editor.
      #
      # `undofile` is ON deliberately: persistent undo is the feature ZT uses,
      # and this guard is what makes it safe to have on.
      undofile = true;

      # §6 row 10. Swap stays ON for ordinary buffers: the incident it
      # prevents is unrecoverable loss on crash. The guard below is the
      # exception, and it is buffer-local — this must never become a global
      # `noswapfile`.
      swapfile = true;

      # §6 row 16. shada persists yank registers and command-line history per
      # session, regardless of which buffer the text came from, so the
      # buffer-local guard below cannot reach it — main.shada held a
      # `github_pat_` on 2026-07-27. Default is `<50`; this caps registers at
      # 10 lines.
      #
      # This SHRINKS the window, it does not close it: a one-line key still
      # persists. Full closure is `<0`, which was considered and rejected
      # because it also kills cross-session yank. Do not "fix" this in either
      # direction without re-reading that trade.
      shada = "!,'100,<10,s10,h,r/tmp/,r/private/";
    };

    autoCmd = [
      {
        # Layer 1a — secret-shaped NAMES.
        #
        # BufReadPre is the correct hook and the only correct one: it runs
        # before the swap file is created and before the undo file is read.
        # FileType and BufReadPost are both too late for swap.
        event = [
          "BufReadPre"
          "BufNewFile"
        ];
        pattern = [
          "*.sops.*"
          "*secret*"
          ".env"
          ".env.*"
          "*.env"
          ".envrc"
          ".envrc.*"
          "*credential*"
          "*token*"
          "*.age"
          "*.gpg"
          "*.pem"
          "*.key"
          "*.p12"
          "*.pfx"
          "id_rsa"
          "id_dsa"
          "id_ecdsa"
          "id_ed25519"
          ".netrc"
          ".pgpass"
          ".authinfo"
        ];
        callback.__raw = "function(args) _G.zt_no_persist(args.buf, args.file) end";
      }
      {
        # Layer 1b — the sops temp-decrypt tree, matched at RUNTIME.
        #
        # cnixvim baked the prefixes as globs. That is platform-shaped:
        # `$TMPDIR` is `/var/folders/…` on darwin and `/tmp` on linux, so a
        # baked list tuned to one silently protects NOTHING on the other. cvim
        # ships to a linux fleet, so the glob is replaced with a resolved
        # prefix test — see `zt_under_tmpdir` below.
        event = [
          "BufReadPre"
          "BufNewFile"
        ];
        pattern = [ "*" ];
        callback.__raw = ''
          function(args)
            if _G.zt_under_tmpdir(args.file) then
              _G.zt_no_persist(args.buf, args.file)
            end
          end
        '';
      }
    ];

    extraConfigLua = ''
      -- Resetting 'swapfile' deletes an already-created swap file (documented
      -- vim behaviour), which is why the content probe can still clean up at
      -- BufWritePre. Clearing 'undofile' before BufWritePost stops the undo
      -- file being written at all.
      --
      -- Deleting the undo file here gives the guard a property worth keeping:
      -- re-opening a path that leaked BEFORE this guard existed self-cleans.
      function _G.zt_no_persist(buf, name)
        buf = buf or 0
        vim.bo[buf].undofile = false
        vim.bo[buf].swapfile = false
        name = name or vim.api.nvim_buf_get_name(buf)
        if name == "" then return end
        local undo_path = vim.fn.undofile(name)
        if undo_path ~= "" and vim.fn.filereadable(undo_path) == 1 then
          vim.fn.delete(undo_path)
        end
      end

      -- Temp-tree prefixes, resolved once at startup rather than baked as
      -- globs. Both the prefixes and the candidate path go through
      -- vim.fn.resolve, so darwin's /tmp -> /private/tmp and
      -- /var/folders -> /private/var/folders symlinks compare equal instead of
      -- silently missing.
      local zt_tmp_prefixes = (function()
        local seen, out = {}, {}
        local function add(p)
          if not p or p == "" then return end
          local abs = vim.fn.resolve(vim.fn.fnamemodify(p, ":p")):gsub("/+$", "")
          if abs ~= "" and not seen[abs] then
            seen[abs] = true
            out[#out + 1] = abs
          end
        end
        add(vim.env.TMPDIR)           -- darwin /var/folders/…, linux often unset
        add(vim.fn.fnamemodify(vim.fn.tempname(), ":h"))
        add("/tmp")                   -- linux default, and darwin's symlink
        return out
      end)()

      function _G.zt_under_tmpdir(name)
        if not name or name == "" then return false end
        local abs = vim.fn.resolve(vim.fn.fnamemodify(name, ":p"))
        for _, prefix in ipairs(zt_tmp_prefixes) do
          if abs:sub(1, #prefix + 1) == prefix .. "/" then return true end
        end
        return false
      end

      -- Layer 2 — key material in INNOCUOUSLY-NAMED buffers.
      --
      -- Not optional, and not redundant with the path globs. Of the 40 undo
      -- files with confirmed key material on ZT's mac, ~40% had names no glob
      -- would ever catch: tmux/cheatsheet.md (AGE-SECRET-KEY + AKIA),
      -- tmux.conf, a values.yaml (AKIA), a shell init.sh (sk-ant-), and a
      -- service file with no extension. Globs alone cover 60% of a verified
      -- live leak.
      local zt_secret_re = vim.regex(
        [[\v(AGE-SECRET-KEY-|BEGIN [A-Z ]+PRIVATE KEY|sk-ant-[a-zA-Z0-9_-]{20}|ghp_[a-zA-Z0-9]{30}|github_pat_[a-zA-Z0-9_]{30}|AKIA[0-9A-Z]{16}|xoxb-[0-9]{10}|glpat-[a-zA-Z0-9_-]{20})]]
      )

      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePre" }, {
        callback = function(args)
          local buf = args.buf
          if not vim.bo[buf].undofile and not vim.bo[buf].swapfile then return end
          if not vim.api.nvim_buf_is_loaded(buf) then return end
          -- Bound the cost: a hand-edited secret file is never this large.
          if vim.api.nvim_buf_line_count(buf) > 5000 then return end
          local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
          if zt_secret_re:match_str(text) then
            _G.zt_no_persist(buf, args.file)
            vim.notify(
              "secret detected: undo/swap persistence disabled for this buffer",
              vim.log.levels.WARN
            )
          end
        end,
      })
    '';
  };
}
