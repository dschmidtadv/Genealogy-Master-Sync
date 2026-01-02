# **Genealogy Master-Sync Stack (Project Genesis)**

A Dockerized architecture for harmonizing genealogical data between **Ancestry**, **FamilySearch**, and **Gramps Web**, optimized for AI integration via the **Model Context Protocol (MCP)**.

## **🏗 Architecture**

This project implements a **Hub-and-Spoke** model to solve the problem of data silos in genealogy:

* **Ingestion Hub:** RootsMagic 10/11 running in a customized Wine container. It acts as the "Air Lock" for proprietary data syncing (Ancestry TreeShare).  
* **Intelligence Layer:** FamilySearch MCP Server running in Node.js. It allows AI agents (Claude/Cursor) to query the FamilySearch global tree directly.  
* **Distribution Node:** Gramps Web for API access and web-based visualization.  
* **Automation:** A Python sync-worker that watches for changes in RootsMagic and propagates them to Gramps.

## **🚀 Quick Start**

### **1\. Prerequisites**

* Docker & Docker Compose  
* A VNC Viewer (RealVNC, Remmina) or Web Browser

### **2\. Launch the Stack**

git clone \[https://github.com/your-user/genealogy-stack.git\](https://github.com/your-user/genealogy-stack.git)  
cd genealogy-stack  
docker-compose up \-d \--build

### **3\. Configuration**

**Step A: FamilySearch MCP**

1. Get your Client ID from [FamilySearch Developers](https://www.familysearch.org/developers/).  
2. Create data/mcp\_config/config.json:  
   { "clientId": "YOUR\_CLIENT\_ID" }

3. Restart: docker restart familysearch-mcp

**Step B: RootsMagic (The "One-Time" Setup)**

1. Connect via VNC to localhost:5900 (Password: genealogy).  
2. Install RootsMagic (download via the terminal inside the container or mounted volume).  
3. **Critical:** Perform the initial **TreeShare** download from Ancestry to populate the local database.

### **4\. Connect AI (Claude Desktop)**

Add this to your claude\_desktop\_config.json:

{  
  "mcpServers": {  
    "familysearch": {  
      "command": "docker",  
      "args": \["exec", "-i", "familysearch-mcp", "node", "/app/dist/index.js"\]  
    }  
  }  
}

## **🔐 Security & Configuration**

### **Environment Variables**

Sensitive configuration is managed via `.env` file:

```bash
# Copy the template
cp .env.example .env

# Edit with your secure passwords
VNC_PASSWORD=your_secure_vnc_password
GRAMPS_ADMIN_USER=your_admin_username
```

**Never commit `.env` to version control!** Add it to `.gitignore`.

### **Default Credentials (Change Immediately!)**

| Service | Username | Password | File |
|---------|----------|----------|------|
| RootsMagic VNC | - | `newpassword123` | `.env` (VNC_PASSWORD) |
| Gramps Web | `dschmidt` | `admin123` | Database |

## **� Technical Details**

* **WebView2/Edge Workaround:** The RootsMagic image installs the Enterprise MSI of Edge to bypass Wine installation crashes.
* **SQLite Collation:** The Python worker implements RMNOCASE to natively read RootsMagic .rmtree files.
* **Data Persistence:** All data is mapped to the ./data directory on the host.
* **Environment Security:** Passwords and sensitive config stored in `.env` file.

## **📜 License**

MIT
