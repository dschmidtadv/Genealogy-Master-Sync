#!/bin/bash

# ==============================================================================
# COPILOT / AI INSTRUCTIONS
# ==============================================================================
# CONTEXT: This script (`generate_repo.sh`) builds the "Mac-Native" version of
# the Genealogy Stack.
#
# ACTION: It creates a local workspace, sets up Python/Node environments,
# and generates configuration scripts for macOS.
# ==============================================================================

# Project Genesis: Mac-Native Repository Generator

# 1. Create Directory Structure
echo "Creating Mac-Native directory structure..."
BASE_DIR="genealogy-mac-stack"
mkdir -p "$BASE_DIR/mcp-server"
mkdir -p "$BASE_DIR/scripts"
mkdir -p "$BASE_DIR/config"

cd "$BASE_DIR" || exit

# 2. Generate Python Sync Worker (Native Version)
echo "Generating scripts/sync_worker.py..."
cat << 'EOF' > scripts/sync_worker.py
import sqlite3
import time
import os
import sys
from pathlib import Path

# Configuration: Tries to find RootsMagic file in standard Mac Documents location
USER_HOME = str(Path.home())
DEFAULT_DB_PATH = os.path.join(USER_HOME, "Documents", "RootsMagic", "MasterTree.rmtree")

def rmnocase_collation(s1, s2):
    """Simulates RootsMagic RMNOCASE collation."""
    s1 = s1.lower() if s1 else ""
    s2 = s2.lower() if s2 else ""
    if s1 == s2: return 0
    if s1 < s2: return -1
    return 1

def sync_data(db_path):
    try:
        print(f"Connecting to RootsMagic DB at {db_path}...")
        conn = sqlite3.connect(db_path)
        conn.create_collation("RMNOCASE", rmnocase_collation)
        cursor = conn.cursor()

        cursor.execute("""
            SELECT count(*) FROM PersonTable
        """)
        count = cursor.fetchone()[0]
        print(f"SUCCESS: Found {count} persons in your RootsMagic tree.")
        
        # Add your custom ETL / Export logic here
        # e.g., Export to GEDCOM for MacFamilyTree
        
        conn.close()
    except Exception as e:
        print(f"ERROR: {e}")

if __name__ == "__main__":
    target_db = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_DB_PATH
    if os.path.exists(target_db):
        sync_data(target_db)
    else:
        print(f"Creating starter config... (DB not found at {target_db})")
        print("Please run RootsMagic and create a tree named 'MasterTree.rmtree' in Documents/RootsMagic")
EOF

# 3. Generate Mac Setup Script (Install Dependencies)
echo "Generating setup_env.sh..."
cat << 'EOF' > setup_env.sh
#!/bin/bash
# Installs Node.js dependencies for the MCP server

echo ">>> Setting up FamilySearch MCP Server..."
if [ ! -d "mcp-server/dist" ]; then
    echo "Cloning MCP Server..."
    git clone https://github.com/dulbrich/familysearch-mcp.git ./mcp-server_temp
    mv ./mcp-server_temp/* ./mcp-server/
    rm -rf ./mcp-server_temp
fi

cd mcp-server
echo "Installing NPM packages..."
npm install
echo "Building TypeScript..."
npm run build
cd ..

echo ">>> Setup Complete."
echo "You can now verify the install by running: node mcp-server/dist/index.js"
EOF
chmod +x setup_env.sh

# 4. Generate Claude Configuration Helper
echo "Generating config/claude_config_helper.sh..."
cat << 'EOF' > config/claude_config_helper.sh
#!/bin/bash
# Output the JSON snippet needed for Claude Desktop
PWD_PATH=$(pwd)
NODE_PATH=$(which node)

echo "========================================================"
echo "      CLAUDE DESKTOP CONFIGURATION SNIPPET"
echo "========================================================"
echo "Copy the block below into your config file at:"
echo "~/Library/Application Support/Claude/claude_desktop_config.json"
echo ""
echo "{"
echo "  \"mcpServers\": {"
echo "    \"familysearch\": {"
echo "      \"command\": \"$NODE_PATH\","
echo "      \"args\": [\"$PWD_PATH/../mcp-server/dist/index.js\"],"
echo "      \"env\": { \"NODE_ENV\": \"production\" }"
echo "    }"
echo "  }"
echo "}"
echo "========================================================"
EOF
chmod +x config/claude_config_helper.sh

# 5. Generate Roo Code / VS Code Configuration
echo "Generating config/roocode_config.json..."
# We create a JSON file directly that can be copied
PWD_PATH=$(pwd)
NODE_PATH=$(which node)

# If node path is empty, default to standard mac path for the JSON suggestion
if [ -z "$NODE_PATH" ]; then
    NODE_PATH="/usr/local/bin/node"
fi

cat << EOF > config/roocode_config.json
{
  "mcpServers": {
    "familysearch": {
      "command": "$NODE_PATH",
      "args": ["$PWD_PATH/mcp-server/dist/index.js"],
      "env": {
        "NODE_ENV": "production"
      }
    }
  }
}
EOF

# 6. Generate README
echo "Generating README.md..."
cat << 'EOF' > README.md
# Genealogy Mac-Native Stack

A simplified, host-based workflow for syncing genealogy data on macOS using native apps and local scripts.

## 🍎 Architecture

1.  **Ingestion:** [RootsMagic 10/11 for Mac](https://rootsmagic.com/download) (Native App).
2.  **Intelligence:** FamilySearch MCP Server (Local Node.js process).
3.  **Automation:** Python scripts reading direct file paths.

## 🛠 Setup

### 1. Requirements
* **RootsMagic 10 or 11** (Installed in `/Applications`)
* **Node.js** (v18+)
* **Python 3.10+**
* **VS Code** with **Roo Code** extension

### 2. Installation
Run the setup script to download and build the MCP server:
\`\`\`bash
./setup_env.sh
\`\`\`

### 3. Configure FamilySearch
1.  Get your Client ID from FamilySearch Developers.
2.  Create the config file:
    \`\`\`bash
    mkdir ~/.familysearch-mcp
    echo '{ "clientId": "YOUR_KEY_HERE" }' > ~/.familysearch-mcp/config.json
    \`\`\`

### 4. Connect to Roo Code (VS Code)
1.  Open the file \`config/roocode_config.json\` created in this repo.
2.  In VS Code, open the **Roo Code** extension sidebar.
3.  Click the **MCP** icon / "Configure MCP Servers".
4.  Paste the content of \`roocode_config.json\` into your Roo Code settings file.
5.  Restart the Extension or VS Code.

### 5. Run Sync Diagnostics
Test if Python can read your RootsMagic file:
\`\`\`bash
python3 scripts/sync_worker.py
\`\`\`

## 📝 Workflow
1.  Use **RootsMagic** to sync with Ancestry/FamilySearch.
2.  Use **Roo Code** to ask questions like: *"Search FamilySearch for [Name] and write a Python script to find their duplicates in my local DB."*
3.  Run the **Python script** to perform custom analysis.
EOF

# 7. Initialize Git
echo "Initializing Git..."
git init
git add .
git commit -m "Initial commit: Mac-Native Genealogy Stack"

echo "--------------------------------------------------------"
echo "Mac-Native Stack Created in ./genealogy-mac-stack"
echo "Run './setup_env.sh' inside that folder to begin."
echo "--------------------------------------------------------"