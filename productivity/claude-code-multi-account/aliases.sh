# Claude Code profile aliases.
#
# Append to ~/.zshrc or ~/.bashrc, then `source` it.
#
# The primary account keeps the plain `claude` command and ~/.claude.
# Each alternate just points CLAUDE_CONFIG_DIR somewhere else.
#
# See: https://sumguy.com/claude-code-multi-account-config/

alias claude-alt-1="CLAUDE_CONFIG_DIR=$HOME/.claude-alt-1 claude"
alias claude-alt-2="CLAUDE_CONFIG_DIR=$HOME/.claude-alt-2 claude"

# Handy when you want to know which account a given pane is running as.
claude-whoami() {
  local dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
  if [[ -r "$dir/.claude.json" ]]; then
    printf 'config dir: %s\n' "$dir"
    python3 -c "
import json, sys
d = json.load(open('$dir/.claude.json'))
a = d.get('oauthAccount') or {}
print('account:    ', a.get('emailAddress', '(not signed in)'))
print('org:        ', a.get('organizationName', '-'), '/', a.get('organizationRole', '-'))
"
  else
    printf 'config dir: %s (not initialised)\n' "$dir"
  fi
}
