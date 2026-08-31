#!/usr/bin/env bash
# Start the operating Claude CLI session on ENV-W inside tmux, from the repo.
#
# Not a convenience. Between 2026-08-27 and 2026-08-29 the ENV-W session
# archived itself four times, once nine minutes into a task, and each time the
# analysis slipped by hours or a day. Running under tmux was recommended three
# times in the logbook and applied zero, because a recommendation is something
# you have to remember and a command is something you run. This is the command.
#
# It also fixes the second half of that failure: the CLI was being started from
# the home directory rather than the checkout, so it found no CLAUDE.md and did
# its onboarding against nothing.
#
#   bench/env-w/start-session.sh [branch]      # create or attach
#   tmux attach -t northstream                 # reattach after a dropped ssh
#   tmux ls                                    # see whether it is still alive
set -uo pipefail

SESSION="${NS_TMUX_SESSION:-northstream}"
BRANCH="${1:-}"
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if ! command -v tmux >/dev/null 2>&1; then
    echo "tmux is not installed. Install it before starting a session that has to" >&2
    echo "outlive an ssh connection: sudo apt-get install -y tmux" >&2
    exit 2
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "Session '$SESSION' already exists — attaching instead of starting a second one."
    echo "(Two sessions on one branch is the doubling CLAUDE.md §3.8 warns about.)"
    exec tmux attach -t "$SESSION"
fi

cd "$REPO" || exit 1
if [[ -n "$BRANCH" ]]; then
    git fetch --quiet origin "$BRANCH" || true
    git checkout "$BRANCH" || { echo "cannot check out $BRANCH" >&2; exit 1; }
    git pull --ff-only --quiet origin "$BRANCH" || true
fi

echo "repo:    $REPO"
echo "branch:  $(git rev-parse --abbrev-ref HEAD) @ $(git rev-parse --short HEAD)"
echo "session: $SESSION"
echo
echo "Starting the CLI in tmux. It survives a dropped connection; reattach with:"
echo "  tmux attach -t $SESSION"
echo
exec tmux new-session -s "$SESSION" -c "$REPO" "claude"
