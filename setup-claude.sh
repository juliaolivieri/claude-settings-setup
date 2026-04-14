#!/bin/bash
set -euo pipefail

CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"
STATUSLINE="$CLAUDE_DIR/statusline.sh"

mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
  echo "Created $SETTINGS"
fi

changed=false
needs_statusLine=false
needs_sandbox=false

if ! jq -e 'has("statusLine")' "$SETTINGS" >/dev/null 2>&1; then
  needs_statusLine=true
fi

if ! jq -e 'has("sandbox")' "$SETTINGS" >/dev/null 2>&1; then
  needs_sandbox=true
fi

if $needs_statusLine || $needs_sandbox; then
  tmp=$(mktemp)
  cp "$SETTINGS" "$tmp"

  if $needs_statusLine; then
    jq '.statusLine = {"type":"command","command":"~/.claude/statusline.sh","padding":0}' "$tmp" > "${tmp}.out" && mv "${tmp}.out" "$tmp"
    echo "Added statusLine to $SETTINGS"
  fi

  if $needs_sandbox; then
    jq '.sandbox = {"enabled":true,"autoAllowBashIfSandboxed":true}' "$tmp" > "${tmp}.out" && mv "${tmp}.out" "$tmp"
    echo "Added sandbox to $SETTINGS"
  fi

  mv "$tmp" "$SETTINGS"
  changed=true
else
  echo "statusLine and sandbox already present in $SETTINGS — no changes made"
fi

if [ -f "$STATUSLINE" ]; then
  echo "$STATUSLINE already exists — skipping"
else
  cat > "$STATUSLINE" << 'SCRIPT'
#!/bin/bash
input=$(cat)
SESSION=$(echo "$input" | jq -r '.session_id')
MODEL=$(echo "$input" | jq -r '.model.display_name')
COST=$(printf '%.2f' "$(echo "$input" | jq -r '.cost.total_cost_usd // 0')")
echo "[$MODEL] $SESSION | \$$COST"
SCRIPT
  chmod +x "$STATUSLINE"
  echo "Wrote $STATUSLINE (executable)"
  changed=true
fi

if $changed; then
  echo "Done — restart Claude Code to pick up the new settings."
else
  echo "Everything already configured — nothing to do."
fi
