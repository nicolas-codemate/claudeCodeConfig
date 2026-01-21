#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";

const FIGMA_TOKEN = process.env.FIGMA_TOKEN;

if (!FIGMA_TOKEN) {
  console.error("Error: FIGMA_TOKEN environment variable is required");
  console.error("Generate a Personal Access Token at: https://www.figma.com/developers/api#access-tokens");
  process.exit(1);
}

const FIGMA_API_BASE = "https://api.figma.com/v1";

function parseFigmaUrl(url) {
  // Supported URL formats:
  // https://www.figma.com/file/ABC123/ProjectName?node-id=1-42
  // https://www.figma.com/design/ABC123/ProjectName?node-id=1-42
  // https://www.figma.com/proto/ABC123/ProjectName?node-id=1-42
  // https://www.figma.com/board/ABC123/ProjectName?node-id=1-42

  const urlPattern = /figma\.com\/(file|design|proto|board)\/([a-zA-Z0-9]+)/;
  const match = url.match(urlPattern);

  if (!match) {
    throw new Error(
      "Invalid Figma URL. Expected format: https://www.figma.com/(file|design|proto|board)/FILE_KEY/..."
    );
  }

  const fileKey = match[2];

  // Extract node-id from query params
  const urlObj = new URL(url);
  let nodeId = urlObj.searchParams.get("node-id");

  if (!nodeId) {
    throw new Error(
      "Missing node-id in URL. Please select a specific frame or element in Figma and copy its URL."
    );
  }

  // Convert URL format (1-42) to API format (1:42)
  nodeId = nodeId.replace(/-/g, ":");

  return { fileKey, nodeId };
}

async function figmaRequest(endpoint) {
  const url = `${FIGMA_API_BASE}${endpoint}`;
  const response = await fetch(url, {
    headers: {
      "X-Figma-Token": FIGMA_TOKEN,
    },
  });

  if (response.status === 403) {
    throw new Error(
      "Access denied. Either your token is invalid or you don't have access to this file. " +
      "Check your token at: https://www.figma.com/developers/api#access-tokens"
    );
  }

  if (response.status === 404) {
    throw new Error(
      "File or node not found. Please verify the URL and ensure the file is shared with you."
    );
  }

  if (response.status === 429) {
    throw new Error(
      "Rate limit exceeded. Please wait a moment before trying again."
    );
  }

  if (!response.ok) {
    const errorText = await response.text();
    throw new Error(`Figma API error (${response.status}): ${errorText}`);
  }

  return response.json();
}

async function downloadImage(imageUrl) {
  const response = await fetch(imageUrl);

  if (!response.ok) {
    throw new Error(`Failed to download image: ${response.status}`);
  }

  const arrayBuffer = await response.arrayBuffer();
  const buffer = Buffer.from(arrayBuffer);
  return buffer.toString("base64");
}

async function getFigmaScreenshot(url, scale = 1) {
  const { fileKey, nodeId } = parseFigmaUrl(url);

  // Request image from Figma API
  const endpoint = `/images/${fileKey}?ids=${encodeURIComponent(nodeId)}&format=png&scale=${scale}`;
  const result = await figmaRequest(endpoint);

  if (result.err) {
    throw new Error(`Figma API error: ${result.err}`);
  }

  const imageUrl = result.images[nodeId];

  if (!imageUrl) {
    throw new Error(
      `No image generated for node ${nodeId}. The node might be empty or invalid.`
    );
  }

  // Download and convert to base64
  const base64Image = await downloadImage(imageUrl);

  // Check size (rough estimate: base64 is ~1.37x larger than binary)
  const estimatedSizeBytes = (base64Image.length * 3) / 4;
  const estimatedSizeMB = estimatedSizeBytes / (1024 * 1024);

  // If image is too large and scale can be reduced, retry with lower scale
  if (estimatedSizeMB > 1 && scale > 0.5) {
    const newScale = Math.max(0.5, scale / 2);
    console.error(`Image too large (${estimatedSizeMB.toFixed(2)}MB), retrying with scale=${newScale}`);
    return getFigmaScreenshot(url, newScale);
  }

  return {
    base64: base64Image,
    mimeType: "image/png",
    nodeId,
    fileKey,
    scale,
    estimatedSizeMB: estimatedSizeMB.toFixed(2),
  };
}

const TOOLS = [
  {
    name: "figma_screenshot",
    description:
      "Capture a screenshot of a Figma design from its URL. Returns the image as base64 that can be visually analyzed. " +
      "Supports file, design, proto, and board URLs. The URL must include a node-id parameter.",
    inputSchema: {
      type: "object",
      properties: {
        url: {
          type: "string",
          description:
            "The Figma URL to capture. Must include node-id parameter. " +
            "Example: https://www.figma.com/design/ABC123/Project?node-id=1-42",
        },
        scale: {
          type: "number",
          description:
            "Image scale factor (0.5, 1, or 2). Default is 1. Use 0.5 for smaller images, 2 for higher resolution.",
          enum: [0.5, 1, 2],
        },
      },
      required: ["url"],
    },
  },
];

async function handleFigmaScreenshot(args) {
  const { url, scale = 1 } = args;

  // Validate scale
  const validScales = [0.5, 1, 2];
  const actualScale = validScales.includes(scale) ? scale : 1;

  const result = await getFigmaScreenshot(url, actualScale);

  return {
    content: [
      {
        type: "image",
        data: result.base64,
        mimeType: result.mimeType,
      },
      {
        type: "text",
        text: JSON.stringify({
          fileKey: result.fileKey,
          nodeId: result.nodeId,
          scale: result.scale,
          estimatedSizeMB: result.estimatedSizeMB,
        }, null, 2),
      },
    ],
  };
}

const server = new Server(
  {
    name: "figma-screenshot",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools: TOOLS };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    if (name === "figma_screenshot") {
      return await handleFigmaScreenshot(args);
    }

    throw new Error(`Unknown tool: ${name}`);
  } catch (error) {
    return {
      content: [
        {
          type: "text",
          text: `Error: ${error.message}`,
        },
      ],
      isError: true,
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Figma Screenshot MCP server started");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
