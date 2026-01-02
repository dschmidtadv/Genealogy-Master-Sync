#!/usr/bin/env node

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ErrorCode,
  ListToolsRequestSchema,
  McpError,
} from '@modelcontextprotocol/sdk/types.js';
import axios from 'axios';

class FamilySearchMCPServer {
  private server: Server;

  constructor() {
    this.server = new Server(
      {
        name: 'familysearch-mcp',
        version: '1.0.0',
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers() {
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: [
          {
            name: 'search_family_tree',
            description: 'Search for individuals in FamilySearch family tree',
            inputSchema: {
              type: 'object',
              properties: {
                query: {
                  type: 'string',
                  description: 'Search query (name, place, etc.)',
                },
                maxResults: {
                  type: 'number',
                  description: 'Maximum number of results to return',
                  default: 10,
                },
              },
              required: ['query'],
            },
          },
          {
            name: 'get_person_details',
            description: 'Get detailed information about a specific person',
            inputSchema: {
              type: 'object',
              properties: {
                personId: {
                  type: 'string',
                  description: 'FamilySearch person ID',
                },
              },
              required: ['personId'],
            },
          },
        ],
      };
    });

    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      switch (name) {
        case 'search_family_tree':
          return this.searchFamilyTree(args);
        case 'get_person_details':
          return this.getPersonDetails(args);
        default:
          throw new McpError(
            ErrorCode.MethodNotFound,
            `Unknown tool: ${name}`
          );
      }
    });
  }

  private async searchFamilyTree(args: any) {
    const { query, maxResults = 10 } = args;

    try {
      // Note: This is a placeholder implementation
      // FamilySearch API requires authentication and specific endpoints
      // In a real implementation, you would:
      // 1. Authenticate with FamilySearch API
      // 2. Use the search endpoint
      // 3. Handle pagination and results

      return {
        content: [
          {
            type: 'text',
            text: `Search results for "${query}" (placeholder - FamilySearch API integration needed):\n\n` +
                  `Found ${Math.min(maxResults, 5)} potential matches:\n` +
                  `1. John Smith (1820-1890) - ID: FS123456\n` +
                  `2. Jane Smith (1785-1850) - ID: FS789012\n` +
                  `3. William Smith (1750-1820) - ID: FS345678\n` +
                  `4. Mary Smith (1800-1875) - ID: FS901234\n` +
                  `5. Robert Smith (1775-1845) - ID: FS567890\n\n` +
                  `Note: This is mock data. Real implementation requires FamilySearch API credentials.`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Search failed: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async getPersonDetails(args: any) {
    const { personId } = args;

    try {
      // Placeholder implementation
      return {
        content: [
          {
            type: 'text',
            text: `Person details for ID: ${personId} (placeholder):\n\n` +
                  `Name: John Smith\n` +
                  `Birth: 15 Mar 1820, Springfield, IL\n` +
                  `Death: 22 Jul 1890, Chicago, IL\n` +
                  `Spouse: Jane Doe (1825-1900)\n` +
                  `Children: 3\n\n` +
                  `Note: This is mock data. Real implementation requires FamilySearch API access.`,
          },
        ],
      };
    } catch (error) {
      throw new McpError(
        ErrorCode.InternalError,
        `Failed to get person details: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error('FamilySearch MCP server running on stdio');
  }
}

// Run the server
const server = new FamilySearchMCPServer();
server.run().catch((error) => {
  console.error('Server error:', error);
  process.exit(1);
});