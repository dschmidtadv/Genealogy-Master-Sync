# **Genealogy Master-Sync Stack (Project Genesis)**

A Dockerized architecture for harmonizing genealogical data between **Ancestry**, **FamilySearch**, and **Gramps Web**, optimized for AI integration via the **Model Context Protocol (MCP)**.

## **🏗 Architecture**

This project implements a **Hub-and-Spoke** model to solve the problem of data silos in genealogy:

* **Ingestion Hub:** RootsMagic 10/11 running in a customized Wine container. It acts as the "Air Lock" for proprietary data syncing (Ancestry TreeShare).  
* **Intelligence Layer:** FamilySearch MCP Server running in Node.js with ESM support. It allows AI agents (Claude/Cursor) to query the FamilySearch global tree directly.  
* **Distribution Node:** Gramps Web for API access and web-based visualization.  
* **Automation:** A Python sync-worker that watches for changes in RootsMagic and propagates them to Gramps.

## **🚀 Quick Start**

### **1. Prerequisites**

* Docker & Docker Compose  
* A VNC Viewer (RealVNC, Remmina) or Web Browser

### **2. Launch the Stack**

```bash
git clone https://github.com/your-user/genealogy-stack.git
cd genealogy-stack
docker-compose up -d --build
```

### **3. Configuration**

**Step A: FamilySearch MCP**

1. Get your Client ID from [FamilySearch Developers](https://www.familysearch.org/developers/).  
2. Create data/mcp_config/config.json:  
   ```json
   { "clientId": "YOUR_CLIENT_ID" }
   ```
3. Restart: `docker restart familysearch-mcp`

**Step B: RootsMagic (The "One-Time" Setup)**

1. Connect via VNC to localhost:5900 (Password: genealogy).  
2. Install RootsMagic (download via the terminal inside the container or mounted volume).  
3. **Critical:** Perform the initial **TreeShare** download from Ancestry to populate the local database.

### **4. Connect AI (Claude Desktop)**

Add this to your claude_desktop_config.json:

```json
{  
  "mcpServers": {  
    "familysearch": {  
      "command": "docker",  
      "args": ["exec", "-i", "familysearch-mcp", "node", "/app/dist/index.js"]  
    }  
  }  
}
```

## **🔐 Security & Configuration**

### **Environment Variables**

Sensitive configuration is managed via `.env` file:

```bash
# Copy the template
cp .env.example .env

# Edit with your secure passwords
VNC_PASSWORD=your_secure_vnc_password
GRAMPS_ADMIN_USER=your_admin_username
GRAMPS_ADMIN_PASS=your_admin_password
```

**Never commit `.env` to version control!** Add it to `.gitignore`.

### **Default Credentials (Change Immediately!)**

| Service | Username | Password | File |
|---------|----------|----------|------|
| RootsMagic VNC | - | `newpassword123` | `.env` (VNC_PASSWORD) |
| Gramps Web | `dschmidt` | `admin123` | Database |

## **🧪 Testing**

The project includes comprehensive functional tests for all services:

### **Running Tests**

```bash
cd genealogy-stack/mcp-server
npm test
```

### **Test Coverage**

- **Grampsweb API Tests:** Authentication, person creation, data validation
- **RootsMagic noVNC Tests:** Service accessibility verification
- **Sync-worker Tests:** Integration endpoint testing
- **Integration Tests:** End-to-end data flow between services

### **Test Authentication**

Tests use HTTP Basic Authentication for Grampsweb API access. Configure credentials in your `.env` file:

```bash
GRAMPS_ADMIN_USER=dschmidt
GRAMPS_ADMIN_PASS=your_secure_password
```

## **🔧 Technical Details**

### **Recent Improvements**

- **ESM Support:** MCP server now uses ECMAScript modules for better compatibility
- **Enhanced Security:** Comprehensive security audit and hardening implemented
- **Integration Testing:** Full test suite for service interaction validation
- **Dependency Management:** Automated Python dependency installation in sync-worker

### **Architecture Components**

* **WebView2/Edge Workaround:** The RootsMagic image installs the Enterprise MSI of Edge to bypass Wine installation crashes.
* **SQLite Collation:** The Python worker implements RMNOCASE to natively read RootsMagic .rmtree files.
* **Data Persistence:** All data is mapped to the ./data directory on the host.
* **Environment Security:** Passwords and sensitive config stored in `.env` file.

### **Service Endpoints**

| Service | Port | Endpoint | Description |
|---------|------|----------|-------------|
| Gramps Web | 5000 | http://localhost:5000 | Web interface and API |
| RootsMagic noVNC | 8080 | http://localhost:8080 | Web-based VNC access |
| RootsMagic VNC | 5900 | vnc://localhost:5900 | Direct VNC connection |
| Sync Worker | 8000 | http://localhost:8000/sync | Sync trigger endpoint |

## **🚀 Development**

### **Branch Structure**

- `main`: Production-ready code
- `feature/security-hardening`: Security improvements and fixes
- `feature/integration-tests`: Comprehensive test suite

### **Contributing**

1. Create a feature branch from `main`
2. Implement changes with appropriate tests
3. Run the test suite: `npm test`
4. Submit a pull request

## **📜 License**

MIT
