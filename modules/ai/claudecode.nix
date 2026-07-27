# claudecode.nvim — Claude Code as an IDE peer, not a chat box.
#
# The plugin runs a WebSocket server on 127.0.0.1 and drops a lock file in
# `~/.claude/ide/<port>.lock`. A `claude` CLI started underneath finds that
# lock file and attaches, which is what turns the terminal split into a real
# integration: diffs land in nvim buffers, `@`-mentions resolve against the
# open editor, and the visual selection is pushed as context.
#
# EDITOR-SURFACE STATES (all three measured in a running editor, captures in
# `results/captures/`):
#
#   empty    No session. The plugin is NOT loaded — `vim.g.loaded_claudecode`
#            is nil, no process in the nvim tree holds a TCP listener, and
#            `~/.claude/ide/` is empty. The `:ClaudeCode*` commands still
#            exist as lz.n stubs, so the surface is complete while the cost is
#            zero. `u10-state1-empty.ansi`.
#   partial  Session starting or mid-stream. The split opens on the right at
#            30% width, the server binds a free 127.0.0.1 port, and the lock
#            file appears. Measured attached: nvim LISTEN on 127.0.0.1:11359
#            with an ESTABLISHED peer, which is the claude process itself.
#            `u10-state2-partial.ansi`, `u10-state2-partial-midstream.ansi`.
#   error    `claude` absent from PATH. A single WARN notification; no split,
#            no stack trace, editor stays usable. UNGUARDED this state is a
#            Lua traceback — see the guard below. `u10-state3-error-*.ansi`.
#
# On `:qa` the VimLeavePre hook stops the server and removes the lock file —
# verified, listener and lock both gone. No residue.
{ config, lib, ... }:
let
  cfg = config.cvim.ai;
in
{
  config = lib.mkIf cfg.enable {
    plugins.claudecode = {
      enable = true;

      settings = {
        # Upstream defaults to "info", and the logger routes INFO through
        # `vim.notify` — every connect, disconnect and queue event becomes a
        # popup. "warn" keeps the failures and drops the chatter. The plugin
        # asserts this value against its own five-name list at setup, so
        # unlike most of the freeform `settings.*` surface a typo here fails
        # loudly instead of silently reverting to the default.
        log_level = "warn";

        terminal = {
          split_side = "right";
          split_width_percentage = 0.30;
        };

        track_selection = true;
        focus_after_send = false;

        diff_opts = {
          layout = "vertical";
          open_in_new_tab = false;
        };
      };

      # Deferral is the whole hostile-defaults answer for this plugin.
      #
      # `auto_start` defaults to true, so an eagerly-loaded claudecode binds a
      # localhost port and writes a lock file in EVERY nvim process, including
      # the thousand that will never talk to Claude. Setting `auto_start =
      # false` is the wrong fix: `:ClaudeCode` only toggles the terminal, it
      # never starts the server, so the CLI would launch, find no lock file,
      # and run with no IDE integration at all — working terminal, silently
      # dead integration, which is the failure class that is hardest to see.
      #
      # Deferring the whole plugin keeps `auto_start = true` honest instead:
      # setup runs at the first `:ClaudeCode*` command, and the server starts
      # exactly when something is about to connect to it. Measured both ways —
      # no listener before the first command, listener plus attached peer
      # after.
      #
      # The command list is deliberately the FULL set rather than the handful
      # the keymaps use. lz.n only creates stubs for names listed here, so any
      # name left out is `E492: Not an editor command` until something else
      # happens to load the plugin.
      lazyLoad.settings.cmd = [
        "ClaudeCode"
        "ClaudeCodeAdd"
        "ClaudeCodeClose"
        "ClaudeCodeCloseAllDiffs"
        "ClaudeCodeDiffAccept"
        "ClaudeCodeDiffDeny"
        "ClaudeCodeFocus"
        "ClaudeCodeOpen"
        "ClaudeCodeSelectModel"
        "ClaudeCodeSend"
        "ClaudeCodeSendText"
        "ClaudeCodeStart"
        "ClaudeCodeStatus"
        "ClaudeCodeStop"
        "ClaudeCodeTreeAdd"
      ];

      # The missing-binary guard. `luaConfig.post`, never
      # `lazyLoad.settings.after` — writing `after` REPLACES the generated
      # `require("claudecode").setup(...)` rather than appending to it, and
      # the plugin would then never be configured.
      #
      # Without this, `<leader>act` with no `claude` on PATH raises
      # `E475: Invalid value for argument cmd: 'claude' is not executable`
      # out of snacks.terminal, straight through the user command, as a
      # floating stack traceback. Measured, not predicted — the capture is
      # `u10-state3-error-UNGUARDED.ansi`.
      #
      # The six names below are every entry point on `claudecode.terminal`
      # that can reach `get_provider().open`. There is no single funnel under
      # them: `simple_toggle` and `focus_toggle` call the PROVIDER's method
      # directly rather than routing through `M.open`, and the provider table
      # is a module-local, so wrapping `M.open` alone would leave the two
      # paths the keymaps actually use unguarded.
      #
      # The binary name is read back from the plugin's own `defaults` rather
      # than hardcoded, so a host that sets `terminal_cmd` gets its own binary
      # checked instead of a "claude" that was never going to run.
      luaConfig.post = ''
        do
          local term = require("claudecode.terminal")
          local function claude_bin()
            local cmd = term.defaults.terminal_cmd
            if not cmd or cmd == "" then
              cmd = "claude"
            end
            return cmd:match("^%S+")
          end
          for _, name in ipairs({
            "open",
            "simple_toggle",
            "focus_toggle",
            "toggle",
            "toggle_open_no_focus",
            "ensure_visible",
          }) do
            local spawn = term[name]
            term[name] = function(...)
              local bin = claude_bin()
              if vim.fn.executable(bin) == 1 then
                return spawn(...)
              end
              -- Kept under 80 columns on purpose: the ui layer's notifier
              -- truncates rather than wraps, and SSH panes are 80 wide.
              vim.notify(
                ("cvim.ai: %q not on PATH -- install the CLI."):format(bin),
                vim.log.levels.WARN
              )
            end
          end
        end
      '';
    };

    # cvim does NOT ship the Claude Code CLI, and this line is what stops it.
    #
    # nixvim's claudecode module declares `claude-code` as a dependency and
    # turns it on with `mkDefault true`, which prefixes `pkgs.claude-code`
    # onto the wrapped editor's PATH. Two separate reasons that is wrong here:
    #
    #   `pkgs.claude-code` is UNFREE. With the dependency left at its default,
    #   `nix build` refuses to evaluate at all — "Refusing to evaluate package
    #   'claude-code-2.1.214' ... because it has an unfree license". A public
    #   distro cannot ship a build that only works with `allowUnfree` set.
    #   Same shape as git-conflict.nvim in the git layer, different licence
    #   reason.
    #
    #   A prefixed nix binary SHADOWS the one the user already runs. The CLI
    #   is a fast-moving, self-updating tool that carries its own session and
    #   auth state; whichever `claude` the user's shell resolves is the one
    #   that should answer. Verified in the smoke test: the terminal split
    #   spawned `/Users/caoer115/.local/bin/claude` — the ambient binary, not
    #   a store path — and that process is the one that held the WebSocket.
    #
    # This is a plain `false`, not `mkDefault false`, because two `mkDefault`s
    # would conflict rather than resolve. A host that genuinely wants the
    # pinned CLI sets `dependencies.claude-code.enable = lib.mkForce true;`
    # and supplies its own `allowUnfree`.
    dependencies.claude-code.enable = false;

    # `<leader>ac*` — the prefix cnixvim used, kept so the muscle memory
    # survives the move. Every binding drives a command in the lz.n stub list
    # above, so pressing one loads the plugin; none of them touch plugin
    # internals directly.
    keymaps = [
      {
        mode = "n";
        key = "<leader>act";
        action = "<cmd>ClaudeCode<cr>";
        options.desc = "Claude: toggle terminal";
      }
      {
        mode = "n";
        key = "<leader>acc";
        action = "<cmd>ClaudeCode --continue<cr>";
        options.desc = "Claude: continue last session";
      }
      {
        mode = "n";
        key = "<leader>acr";
        action = "<cmd>ClaudeCode --resume<cr>";
        options.desc = "Claude: resume a session";
      }
      {
        mode = "n";
        key = "<leader>acf";
        action = "<cmd>ClaudeCodeFocus<cr>";
        options.desc = "Claude: focus terminal";
      }
      {
        mode = "n";
        key = "<leader>acm";
        action = "<cmd>ClaudeCodeSelectModel<cr>";
        options.desc = "Claude: select model";
      }
      {
        mode = "n";
        key = "<leader>acb";
        action = "<cmd>ClaudeCodeAdd %<cr>";
        options.desc = "Claude: add current buffer to context";
      }
      {
        mode = "v";
        key = "<leader>acs";
        action = "<cmd>ClaudeCodeSend<cr>";
        options.desc = "Claude: send selection";
      }
      {
        mode = "n";
        key = "<leader>aca";
        action = "<cmd>ClaudeCodeDiffAccept<cr>";
        options.desc = "Claude: accept diff";
      }
      {
        mode = "n";
        key = "<leader>acd";
        action = "<cmd>ClaudeCodeDiffDeny<cr>";
        options.desc = "Claude: deny diff";
      }
      {
        mode = "n";
        key = "<leader>ac?";
        action = "<cmd>ClaudeCodeStatus<cr>";
        options.desc = "Claude: integration status";
      }
    ];
  };
}
