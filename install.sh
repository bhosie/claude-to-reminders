#!/bin/bash
# install.sh — Build and register the Reminders MCP server with Claude Code.
# Run once after cloning. Re-run after pulling changes to rebuild.

set -e

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/Library/Application Support/Claude/claude_desktop_config.json"
BINARY_PATH="$REPO_DIR/.build/arm64-apple-macosx/release/App"

echo "→ Building release binary..."
swift build -c release --package-path "$REPO_DIR"

echo "→ Registering MCP server in $CONFIG_FILE..."
mkdir -p "$(dirname "$CONFIG_FILE")"

# If the config file already exists, merge our server entry into it.
# Otherwise, create it fresh.
if [ -f "$CONFIG_FILE" ]; then
    # Use python3 (available on all modern Macs) to safely merge JSON.
    python3 - "$CONFIG_FILE" "$BINARY_PATH" <<'EOF'
import json, sys

config_path = sys.argv[1]
binary_path = sys.argv[2]

with open(config_path, "r") as f:
    config = json.load(f)

config.setdefault("mcpServers", {})
config["mcpServers"]["reminders"] = {"command": binary_path, "args": []}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print("  Updated existing config.")
EOF
else
    python3 - "$CONFIG_FILE" "$BINARY_PATH" <<'EOF'
import json, sys

config_path = sys.argv[1]
binary_path = sys.argv[2]

config = {"mcpServers": {"reminders": {"command": binary_path, "args": []}}}

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)
    f.write("\n")

print("  Created new config.")
EOF
fi

echo ""
echo "✓ Done. Restart Claude Code to pick up the new MCP server."
echo "  Then run /mcp to confirm 'reminders' is connected."
