# Use node:18-alpine
FROM node:18-alpine
WORKDIR /app

# Copy package files
COPY package*.json tsconfig.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src ./src

# Build the application
RUN npm run build

# Ensure config directory exists
RUN mkdir -p /root/.familysearch-mcp

# Entrypoint via node
ENTRYPOINT ["node", "dist/index.js"]

# Use CMD for ESM compatibility (avoids ENTRYPOINT array form issues with ESM)
CMD ["node", "dist/index.js"]
