# Where `verify-pane` writes captures. Agents point this at their session
# directory; interactively it falls back to a gitignored dir in the repo.
capture_dir := env_var_or_default("CVIM_CAPTURE_DIR", justfile_directory() / "captures")

_default:
    @just --list

# Capture a tmux pane, ANSI escapes intact, into {{ capture_dir }}/<name>.ansi
#
# This is how every layer gets verified visually. `-e` is the whole point: it
# keeps the colour and attribute escapes, so the capture shows what the pane
# actually looked like rather than its plain text. Read it back with
# `cat`, or diff two captures to show a theme or statusline change.
#
#   just verify-pane %3 ui-tokyonight-night
#   just verify-pane cvim-lab:0.1 picker-zero-results
verify-pane target name:
    #!/usr/bin/env bash
    set -euo pipefail
    mkdir -p {{ quote(capture_dir) }}
    out={{ quote(capture_dir) }}/{{ quote(name) }}.ansi
    tmux capture-pane -e -p -t {{ quote(target) }} > "$out"
    printf '%s (%s lines)\n' "$out" "$(wc -l < "$out" | tr -d ' ')"

# Build the workstation editor
build:
    nix build .#default

# Build the scratch layer — the loop is: edit lab/lab-<layer>.nix, build, run,
# `just verify-pane`, then harden what survives into modules/<layer>/
lab:
    nix build .#lab

# Everything CI gates on
check:
    nix flake check
