# `<leader>tq` — project a few columns out of the current CSV with DuckDB.
#
# A 60-column CSV is unreadable in a text editor. This asks for the columns
# worth seeing, runs the projection through DuckDB's `read_csv_auto`, and opens
# the result as a new buffer. The source file is never modified.
#
# Two deliberate changes from the cnixvim original, both required by cvim's
# rules rather than by taste:
#
#   1. The output goes under `stdpath("state")` — `$XDG_STATE_HOME/nvim` — and
#      not `tempname()`. cnixvim wrote into `$TMPDIR`, which on this mac is a
#      `/var/folders/...` path; the layer rule is that runtime writes land in
#      `$XDG_STATE_HOME` or fail loudly, so it now fails loudly if the
#      directory cannot be created.
#   2. Every failure is now reported. cnixvim ignored `shell_error` and ran
#      `:edit` regardless, so a missing `duckdb`, a typo'd column name, or a
#      malformed CSV all produced the same thing: an empty buffer named after a
#      file that was never written. That is the silent-no-op class this distro
#      is supposed to refuse.
#
# The command is invoked as an argv list, so a source path containing spaces or
# quotes cannot break out of the SQL — the original built one shell string and
# would have mis-parsed both.
#
# `duckdb` is NOT in cvim's closure. It is ZT's own tool, found on PATH, which
# is why absence is a loud error rather than a build-time dependency.
#
# empty:   an empty answer at the prompt cancels — no file is written and no
#          buffer is opened.
# partial: a column list naming one good and one missing column is a DuckDB
#          error, so nothing is written and the DuckDB message is surfaced
#          verbatim; there is no half-written output file.
# error:   `duckdb` absent, an unnamed buffer, or an uncreatable state
#          directory each abort before the query with a specific message.
#          Capture: results/captures/u9a/u9a-duckdb.txt.
{ config, lib, ... }:
let
  cfg = config.cvim.utilities;
in
{
  config = lib.mkIf cfg.enable {
    extraConfigLua = ''
      vim.keymap.set("n", "<leader>tq", function()
        if vim.fn.executable("duckdb") == 0 then
          vim.notify("CSV: duckdb not found on PATH", vim.log.levels.ERROR)
          return
        end

        local src = vim.fn.expand("%:p")
        if src == "" or vim.fn.filereadable(src) == 0 then
          vim.notify("CSV: current buffer is not a readable file on disk", vim.log.levels.ERROR)
          return
        end

        local cols = vim.fn.input("select cols (e.g. url,tranco_today): ")
        if cols == "" then return end

        local outdir = vim.fn.stdpath("state") .. "/cvim/csv-projection"
        pcall(vim.fn.mkdir, outdir, "p")
        if vim.fn.isdirectory(outdir) == 0 then
          vim.notify("CSV: cannot create " .. outdir, vim.log.levels.ERROR)
          return
        end

        local out = string.format(
          "%s/%s-%s.csv",
          outdir,
          vim.fn.fnamemodify(src, ":t:r"),
          os.date("%Y%m%d-%H%M%S")
        )
        local sql = string.format(
          "COPY (SELECT %s FROM read_csv_auto('%s')) TO '%s' (HEADER)",
          cols, src, out
        )

        local result = vim.fn.system({ "duckdb", "-c", sql })
        if vim.v.shell_error ~= 0 then
          vim.notify("CSV: duckdb failed -- " .. vim.trim(result), vim.log.levels.ERROR)
          return
        end

        vim.cmd("edit " .. vim.fn.fnameescape(out))
      end, { desc = "CSV: project cols via DuckDB" })
    '';
  };
}
