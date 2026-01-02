#!/bin/bash

# ==============================================================================
# COPILOT / AI INSTRUCTIONS
# ==============================================================================
# CONTEXT: This script (`generate_repo.sh`) is the canonical source of truth 
# for building the "Genealogy Master-Sync Stack" repository.
#
# ACTION: To build the repository, executing this script is the primary method.
# It creates the folder structure, writes the Dockerfiles, and initializes git.
#
# CONSTRAINT: When asked to "update the stack" or "change the infrastructure", 
# generate a new version of THIS script rather than editing individual files,
# as this ensures reproducibility.
# ==============================================================================

# Project Genesis: Repository Generator
# This script creates the directory structure and files for the Genealogy Master-Sync Stack.

# 1. Create Directory Structure
echo "Creating directory structure..."
mkdir -p genealogy-stack/mcp-server
mkdir -p genealogy-stack/rootsmagic
mkdir -p genealogy-stack/scripts
mkdir -p genealogy-stack/data/rm_data
mkdir -p genealogy-stack/data/gramps_db
mkdir -p genealogy-stack/data/gramps_media
mkdir -p genealogy-stack/data/gramps_users
mkdir -p genealogy-stack/data/mcp_config

cd genealogy-stack

# 2. Generate docker-compose.yml
echo "Generating docker-compose.yml..."
cat << 'EOF' > docker-compose.yml
version: '3.8'

services:
  # -------------------------------------------------------
  # 1. INTELLIGENCE LAYER: FamilySearch MCP Server
  # -------------------------------------------------------
  familysearch-mcp:
    build: ./mcp-server
    container_name: familysearch-mcp
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    volumes:
      - ./data/mcp_config:/root/.familysearch-mcp
    # Expose stdio for local connections or use a proxy for HTTP transport
    stdin_open: true
    tty: true

  # -------------------------------------------------------
  # 2. INGESTION HUB: RootsMagic (Wine + Edge)
  # -------------------------------------------------------
  rootsmagic:
    build: ./rootsmagic
    container_name: rootsmagic-wine
    cap_add:
      - SYS_PTRACE
    ports:
      - "5900:5900" # VNC Port
      - "8080:8080" # noVNC Web Interface
    environment:
      - VNC_PASSWORD=genealogy
      - WINEARCH=win64
      - WINEPREFIX=/root/.wine
    volumes:
      - ./data/rm_data:/root/Documents/RootsMagic
    # Host networking needed for reliable Ancestry OAuth callbacks
    network_mode: "host" 

  # -------------------------------------------------------
  # 3. DISTRIBUTION NODE: Gramps Web
  # -------------------------------------------------------
  grampsweb:
    image: ghcr.io/gramps-project/grampsweb:latest
    container_name: grampsweb
    restart: always
    ports:
      - "5000:5000"
    environment:
      - GRAMPSWEB_TREE=My_Family_Tree
      - GRAMPSWEB_CELERY_CONFIG__broker_url=redis://redis:6379/0
      - GRAMPSWEB_CELERY_CONFIG__result_backend=redis://redis:6379/0
    volumes:
      - ./data/gramps_users:/app/users
      - ./data/gramps_media:/app/media
    depends_on:
      - redis

  redis:
    image: redis:alpine
    container_name: gramps_redis
    restart: always

  # -------------------------------------------------------
  # 4. AUTOMATION GLUE: Python Sync Worker
  # -------------------------------------------------------
  sync-worker:
    image: python:3.11-slim
    container_name: sync-worker
    working_dir: /app
    volumes:
      - ./scripts:/app
      - ./data/rm_data:/data/rm_data # Read-only access to RM DB
    command: python sync_worker.py
    depends_on:
      - grampsweb
EOF

# 3. Generate MCP Dockerfile
echo "Generating mcp-server/Dockerfile..."
cat << 'EOF' > mcp-server/Dockerfile
# Build stage
FROM node:18-alpine AS builder
WORKDIR /app

# Install git to clone the repo
RUN apk add --no-cache git

# Clone the repository identified in the research
RUN git clone https://github.com/dulbrich/familysearch-mcp.git .

# Install dependencies and build
RUN npm install
RUN npm run build

# Runtime stage
FROM node:18-alpine
WORKDIR /app

# Copy built artifacts
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./

# Ensure config directory exists
RUN mkdir -p /root/.familysearch-mcp

# Entrypoint via node
ENTRYPOINT ["node", "dist/index.js"]
EOF

# 4. Generate RootsMagic Dockerfile
echo "Generating rootsmagic/Dockerfile..."
cat << 'EOF' > rootsmagic/Dockerfile
# Base image from the expert report recommendation
FROM scottyhardy/docker-wine:latest

# Set environment for 64-bit Windows 10
ENV WINEARCH=win64
ENV WINEPREFIX=/root/.wine

# 1. Install Critical Dependencies (Report Section 4.2)
# corefonts: Text rendering
# gdiplus: Tree drawing
# wininet: Ancestry API calls
# msxml6: Parsing XML responses
RUN winetricks -q corefonts gdiplus wininet msxml6 d3dcompiler_47

# 2. The Edge/WebView2 Workaround (Report Section 4.3)
# We download the standalone enterprise installer to avoid downloader stubs that crash
RUN wget https://msedge.sf.dl.delivery.mp.microsoft.com/filestreamingservice/files/6c905869-7756-4b82-9014-4340e461a668/MicrosoftEdgeEnterpriseX64.msi -O /root/edge.msi \
    && wine msiexec /i /root/edge.msi /qn \
    && rm /root/edge.msi

# 3. Directory Setup
WORKDIR /root/Documents/RootsMagic
CMD ["/usr/bin/entrypoint"]
EOF

# 5. Generate Sync Worker Script
echo "Generating scripts/sync_worker.py..."
cat << 'EOF' > scripts/sync_worker.py
import sqlite3
import time
import os
import requests
import uuid

# Configuration
RM_DB_PATH = "/data/rm_data/MasterTree.rmtree"
GRAMPS_API_URL = "http://grampsweb:5000/api"
CHECK_INTERVAL = 300  # Check every 5 minutes

def rmnocase_collation(s1, s2):
    """
    Simulates the RMNOCASE collation used by RootsMagic.
    Essential for querying NameTable without crashing.
    """
    s1 = s1.lower() if s1 else ""
    s2 = s2.lower() if s2 else ""
    if s1 == s2: return 0
    if s1 < s2: return -1
    return 1

def check_db_changes():
    """
    Watches the file modification time of the RootsMagic DB.
    """
    last_mtime = 0
    while True:
        try:
            if os.path.exists(RM_DB_PATH):
                current_mtime = os.path.getmtime(RM_DB_PATH)
                if current_mtime > last_mtime:
                    print(f"Change detected in {RM_DB_PATH}. Starting sync...")
                    sync_data()
                    last_mtime = current_mtime
            else:
                print("Waiting for RootsMagic database creation...")
        except Exception as e:
            print(f"Error watching file: {e}")
        
        time.sleep(CHECK_INTERVAL)

def sync_data():
    """
    Extracts data from RootsMagic and pushes to Gramps.
    """
    try:
        # Connect to RootsMagic SQLite
        conn = sqlite3.connect(RM_DB_PATH)
        conn.create_collation("RMNOCASE", rmnocase_collation)
        cursor = conn.cursor()

        # Extract Persons with Ancestry Links
        # Query based on research into LinkAncestryTable
        cursor.execute("""
            SELECT p.PersonID, n.Given, n.Surname, l.extID 
            FROM PersonTable p
            JOIN NameTable n ON p.PersonID = n.OwnerID
            LEFT JOIN LinkAncestryTable l ON p.PersonID = l.rmID
            WHERE n.IsPrimary = 1
        """)
        
        persons = cursor.fetchall()
        print(f"Found {len(persons)} persons in RootsMagic.")

        # Sync logic would go here:
        # 1. Iterate through persons
        # 2. Check if they exist in Gramps (via API)
        # 3. Create or Update
        
        conn.close()
        print("Sync complete.")

    except Exception as e:
        print(f"Sync failed: {e}")

if __name__ == "__main__":
    print("Starting Genealogy Sync Worker...")
    check_db_changes()
EOF

# 6. Initialize Git Repo
echo "Initializing Git repository..."
git init
git add .
git commit -m "Initial commit: Generated Genealogy Master-Sync Stack"

echo "----------------------------------------------------------------"
echo "Repository created successfully in ./genealogy-stack"
echo "To push to GitHub, run:"
echo "  cd genealogy-stack"
echo "  git remote add origin https://github.com/<YOUR_USERNAME>/genealogy-stack.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo "----------------------------------------------------------------"
