# Runtime residue owned by this layer: the FilePost augroup and the
# large-buffer detector.
#
# empty:   a scratch, help or plugin-UI buffer is not a file — FilePost never fires for it and the detector never measures it.
# partial: a buffer with no file on disk yet (a new unwritten file) measures as size 0, so it is never treated as large.
# error:   an unreadable or vanished path makes fs_stat fail; the detector treats that as "not large" and the buffer opens normally rather than erroring.
#
# TWO SEPARATE MECHANISMS, and they are wired together on purpose.
#
# 1. `User CvimFilePost` — fires ONCE per real file buffer, after the file is
#    loaded. "Real file" excludes the buffers a distro spends its startup in:
#    empty buffers, `nofile`/`nowrite` scratch buffers, plugin UIs, help. Later
#    layers hook expensive per-file work here instead of at startup, and get a
#    guarantee that a genuine file exists.
#
#    It is NOT a lazy-loading mechanism and must not be mistaken for one — this
#    layer writes no lazyLoad specs (see default.nix). It is an event source,
#    and it has a consumer inside this very file, which is what keeps it from
#    being decoration.
#
# 2. The large-buffer detector — measures the file at `BufReadPre`, i.e. BEFORE
#    the content is read, because that is the only point where opting out of
#    expensive machinery still saves the work. It only marks the buffer there;
#    the actual switching-off happens at FilePost, once the filetype is settled
#    and treesitter has had its chance to start.
#
# Everything is BUFFER-LOCAL. Opening one 40 MB log must not change how the
# next file behaves, so nothing here touches a global.
{ config, lib, ... }:
let
  cfg = config.cvim.editor;
  threshold = cfg.largeBufferBytes;
in
{
  config = lib.mkIf cfg.enable {
    autoGroups.cvim_file_post.clear = true;

    autoCmd = [
      # ── 1. FilePost: fire once, only for real files ──────────────────────
      {
        event = [
          "BufReadPost"
          "BufNewFile"
        ];
        group = "cvim_file_post";
        desc = "Fire User CvimFilePost once per real file buffer";
        callback.__raw = ''
          function(args)
            local buf = args.buf
            if vim.b[buf].cvim_file_post_fired then
              return
            end
            -- Not a real file: scratch, plugin UI, help, or an unnamed buffer.
            if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
              return
            end
            vim.b[buf].cvim_file_post_fired = true
            vim.api.nvim_exec_autocmds("User", {
              pattern = "CvimFilePost",
              data = { buf = buf },
            })
          end
        '';
      }
    ]
    ++ lib.optionals (threshold != null) [
      # ── 2a. Measure before the content is read ───────────────────────────
      {
        event = [ "BufReadPre" ];
        group = "cvim_file_post";
        desc = "Mark buffers over cvim.editor.largeBufferBytes as large";
        callback.__raw = ''
          function(args)
            local buf = args.buf
            local name = vim.api.nvim_buf_get_name(buf)
            if name == "" then
              return
            end
            local ok, stat = pcall(vim.uv.fs_stat, name)
            if ok and stat and stat.size > ${toString threshold} then
              vim.b[buf].cvim_large_buffer = true
            end
          end
        '';
      }

      # ── 2b. Switch the expensive machinery off, for THIS buffer only ─────
      {
        event = [ "User" ];
        pattern = "CvimFilePost";
        group = "cvim_file_post";
        desc = "Disable syntax, treesitter and diagnostics in large buffers";
        callback.__raw = ''
          function(args)
            local buf = (args.data and args.data.buf) or vim.api.nvim_get_current_buf()
            if not vim.b[buf].cvim_large_buffer then
              return
            end
            -- MUST be deferred. Measured event order for a file open is
            -- BufReadPre -> FileType -> BufReadPost, and nixvim starts
            -- treesitter on FileType -- but stopping it here synchronously
            -- does not stick, because the highlighter is started again before
            -- the open completes. vim.schedule runs after the whole current
            -- event-loop turn, which is the first point where the stop holds.
            -- Verified by probe, not assumed: stopping inline left
            -- highlighter.active[buf] populated.
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(buf) then
                return
              end
              -- Order matters here, and it is the reverse of the obvious one.
              -- vim.treesitter.stop() hands highlighting BACK to vim's regex
              -- syntax engine, so clearing `syntax` first just gets undone --
              -- measured: syntax went "" -> "lua" after the stop. Stop
              -- treesitter first, then take regex syntax down, or the large
              -- buffer ends up on the *more* expensive highlighter.
              pcall(vim.treesitter.stop, buf)
              vim.bo[buf].syntax = "off"
              vim.diagnostic.enable(false, { bufnr = buf })
              vim.notify(
                ("cvim: large buffer (>%d bytes) — syntax, treesitter and diagnostics off for this buffer")
                  :format(${toString threshold}),
                vim.log.levels.INFO
              )
            end)
          end
        '';
      }
    ];

    # nvim-lint spawns a process per write regardless of whether its output is
    # displayed, so disabling diagnostics above is not enough to stop the work
    # on a large buffer. Guarding `try_lint` itself is what makes the claim
    # true rather than approximately true.
    extraConfigLua = lib.mkIf (threshold != null) ''
      do
        local ok, lint = pcall(require, "lint")
        if ok and not lint.__cvim_large_buffer_guarded then
          local orig = lint.try_lint
          lint.try_lint = function(...)
            if vim.b[vim.api.nvim_get_current_buf()].cvim_large_buffer then
              return
            end
            return orig(...)
          end
          lint.__cvim_large_buffer_guarded = true
        end
      end
    '';
  };
}
