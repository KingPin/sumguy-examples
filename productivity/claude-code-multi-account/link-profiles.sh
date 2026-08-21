#!/usr/bin/env bash
#
# link-profiles.sh
#
# Share one Claude Code toolchain across several accounts.
#
# Each alternate profile directory gets symlinks back to your primary
# ~/.claude for everything that is *tooling* (skills, agents, hooks,
# plugins, commands, transcripts), while keeping the handful of files
# that are genuinely *account state* as real, per-profile files.
#
# Safe to re-run. It only ever replaces symlinks it manages, and it
# refuses to touch a real file or directory it did not create.
#
# Usage:
#   ./link-profiles.sh              # apply
#   ./link-profiles.sh --dry-run    # show what would change
#
# See: https://sumguy.com/claude-code-multi-account-config/

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

# Your main, already-configured Claude Code directory. Everything is
# symlinked back to here. Override with CLAUDE_PRIMARY_DIR if yours moved.
PRIMARY="${CLAUDE_PRIMARY_DIR:-$HOME/.claude}"

# The alternate profiles to build. Add or remove lines as needed.
PROFILES=(
  "$HOME/.claude-alt-1"
  "$HOME/.claude-alt-2"
)

# Shared single files. Symlinked, so an edit from any profile writes
# through to the primary copy.
SHARED_FILES=(
  settings.json
  settings.local.json
  CLAUDE.md
  history.jsonl
)

# Shared directories.
#
# Anything in this list that does not exist under $PRIMARY is skipped,
# NOT created. Creating them would litter your primary config with empty
# directories Claude Code never asked for.
SHARED_DIRS=(
  agents
  commands
  skills
  plugins
  hooks
  scripts
  config
  projects
  file-history
  agent-memory
  plans
  tasks
  sessions
  cache
  paste-cache
  backups
  bin
  downloads
)

# Per-account state. These must stay as real files inside each profile.
#
# Symlinking anything here defeats the whole point: you would either be
# logged in as the same account everywhere (.credentials.json) or sharing
# folder-trust and MCP config across identities (.claude.json).
#
# Note that most of these are NOT dotfiles. A cleanup step that keys off
# "is it hidden?" will happily delete security/, session-env/,
# shell-snapshots/, policy-limits.json and remote-settings.json. That is
# why this script does not do a blanket wipe.
NEVER_SHARE=(
  .credentials.json
  .claude.json
  security
  session-env
  shell-snapshots
  policy-limits.json
  remote-settings.json
)

# ---------------------------------------------------------------------------

DRY_RUN=0
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && DRY_RUN=1

log()  { printf '%s\n' "$*"; }
act()  { if (( DRY_RUN )); then log "  would: $*"; else "$@"; fi; }
warn() { printf 'warning: %s\n' "$*" >&2; }

if [[ ! -d "$PRIMARY" ]]; then
  echo "error: primary config dir not found: $PRIMARY" >&2
  exit 1
fi

# Guard against a NEVER_SHARE entry sneaking into the shared lists.
for guarded in "${NEVER_SHARE[@]}"; do
  for candidate in "${SHARED_FILES[@]}" "${SHARED_DIRS[@]}"; do
    if [[ "$guarded" == "$candidate" ]]; then
      echo "error: '$guarded' is in both the shared and never-share lists." >&2
      echo "       Sharing it would merge your accounts. Refusing to run." >&2
      exit 1
    fi
  done
done

# link_one <source-path> <dest-path>
#
# Replaces dest with a symlink to source, but only if dest is absent or
# is already a symlink. A real file or directory at dest is left alone
# and reported, because it may be data you want.
link_one() {
  local src="$1" dest="$2"

  if [[ ! -e "$src" ]]; then
    log "  skip (not in primary): $(basename "$src")"
    return 0
  fi

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink "$dest")"
    if [[ "$current" == "$src" ]]; then
      log "  ok:   $(basename "$dest")"
      return 0
    fi
    act rm -f "$dest"
  elif [[ -e "$dest" ]]; then
    warn "$dest exists as a real file or directory. Leaving it alone."
    warn "  Move or delete it yourself, then re-run to link it."
    return 0
  fi

  act ln -s "$src" "$dest"
  (( DRY_RUN )) || log "  link: $(basename "$dest") -> $src"
}

for profile in "${PROFILES[@]}"; do
  if [[ "$profile" == "$PRIMARY" ]]; then
    echo "error: profile '$profile' is the primary dir. Refusing." >&2
    exit 1
  fi

  log ""
  log "== $profile"

  if [[ ! -d "$profile" ]]; then
    act mkdir -p "$profile"
    log "  created profile dir (it has no credentials yet)"
  fi

  for name in "${SHARED_FILES[@]}" "${SHARED_DIRS[@]}"; do
    link_one "$PRIMARY/$name" "$profile/$name"
  done

  # Report, but never touch, the per-account state.
  for name in "${NEVER_SHARE[@]}"; do
    target="$profile/$name"
    if [[ -L "$target" ]]; then
      warn "$target is a SYMLINK but must be per-account. Fix this:"
      warn "  rm '$target'   # then re-authenticate this profile"
    elif [[ -e "$target" ]]; then
      log "  keep: $name (per-account)"
    fi
  done
done

log ""
if (( DRY_RUN )); then
  log "Dry run only. Nothing changed."
else
  log "Done. Add the aliases from aliases.sh to your shell rc, then run"
  log "each alias once and authenticate with the emailed verification code."
fi
