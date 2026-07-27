# `:SudaWrite` — save a buffer to a path you cannot write, via `sudo tee`.
#
# Replaces vim-suda, which cnixvim inherits from khanelivim and cvim does not
# ship. Surfaced by the defaults-parity sweep as a capability gap rather than a
# defaults row; ZT's call was to write it rather than vendor it ("do 2, its
# simple plugin, write one ourselves"). Vendoring costs a pinned `rev`+`hash`
# to maintain and a third-party surface to review, for more code than this.
#
# ── Why `:w !cmd` and not a job or a temp file ──────────────────────────────
#
# `sudo` reads the password FROM THE TERMINAL, not from stdin — documented in
# sudo(8): "Normally, if sudo requires a password, it will read it from the
# user's terminal." That single fact is what makes this work, and it is why the
# obvious alternatives are worse:
#
#   - `vim.system` / `jobstart` give the child no controlling terminal, so a
#     password prompt has nowhere to appear. The write hangs or fails with no
#     visible reason.
#   - `sudo -S` reads the password from stdin, which is where the buffer
#     contents have to go. Mixing a credential into the same stream as file
#     data to save a process is not a trade worth making.
#   - Staging through a temp file then `sudo mv` puts a plaintext copy of the
#     buffer at a second path, which is what the row-15 guard exists to
#     prevent. Note `/tmp` and `$TMPDIR` are INSIDE the guarded region for
#     exactly that reason.
#
# `:w !cmd` hands the buffer to the command's stdin and leaves the terminal
# free for the prompt. It also writes through the command rather than through
# vim's own write path, which has a consequence worth stating plainly: VIM
# NEVER WRITES AN UNDO FILE ON THIS PATH, for any buffer, guarded or not.
# Verified on the filesystem rather than asserted — results/harness/suda-write/.
#
# ── What it deliberately does not do ────────────────────────────────────────
#
# NO automatic elevation. It runs when asked and is never a fallback on a
# failed `:w`. On a distro shipping to ~15 servers, a write that sometimes
# elevates is a write nobody can reason about.
#
# NO `noundofile` / `noswapfile` bypass. Nothing here touches either option.
# The §6 row 15 guard keeps whatever it set, and this path adds no persistence
# of its own.
#
# `&modified` is cleared ONLY on a successful write to the buffer's own path.
# A cleared flag after a failed write is the same lie as a silent failure in
# different clothes — the user believes a file was saved that was not, which is
# the worst outcome this feature can produce.
#
# Editor-surface states:
#   empty    Unnamed buffer and no path argument — one ERROR naming the
#            problem, nothing spawned, buffer untouched.
#   partial  Writing to a path OTHER than the buffer's own (`:SudaWrite path`)
#            succeeds and deliberately leaves `&modified` SET, because the
#            buffer still does not correspond to its own file on disk.
#   error    `sudo` absent, password cancelled, or tee failing — one ERROR
#            stating the file was NOT written and the buffer is still modified.
#            Cancelling is a normal answer rather than a crash, so it reports
#            instead of raising.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLua = ''
      local function zt_suda_write(target)
        local own = vim.fn.expand("%:p")
        local writing_own_file = (target == nil or target == "" or target == own)
        if target ~= nil and target ~= "" then
          target = vim.fn.fnamemodify(vim.fn.expand(target), ":p")
          writing_own_file = (target == own)
        else
          target = own
        end

        if target == "" then
          vim.notify("SudaWrite: buffer has no name — give a path", vim.log.levels.ERROR)
          return
        end
        if vim.fn.executable("sudo") ~= 1 then
          vim.notify("SudaWrite: sudo not found on PATH — file NOT written", vim.log.levels.ERROR)
          return
        end

        -- `silent` suppresses the shell's own press-enter prompt; the redraw
        -- after repairs the screen the child process scribbled on.
        local cmd = "silent write !sudo tee " .. vim.fn.shellescape(target) .. " >/dev/null"
        local ok, err = pcall(function() vim.cmd(cmd) end)
        vim.cmd("redraw!")

        if not ok then
          vim.notify("SudaWrite: " .. tostring(err) .. " — file NOT written", vim.log.levels.ERROR)
          return
        end
        if vim.v.shell_error ~= 0 then
          vim.notify(
            "SudaWrite: FAILED (exit " .. vim.v.shell_error .. "). " .. target
              .. " NOT written; buffer still modified.",
            vim.log.levels.ERROR
          )
          return
        end

        if writing_own_file then
          vim.bo.modified = false
          vim.notify("SudaWrite: " .. target, vim.log.levels.INFO)
        else
          vim.notify(
            "SudaWrite: " .. target .. " (buffer still modified — it is not this file)",
            vim.log.levels.INFO
          )
        end
      end

      vim.api.nvim_create_user_command("SudaWrite", function(o)
        zt_suda_write(o.args)
      end, {
        nargs = "?",
        complete = "file",
        desc = "Write buffer through sudo tee",
      })
    '';
  };
}
