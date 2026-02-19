#!/usr/bin/env node
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execFile } from "child_process";
import { writeFile } from "fs/promises";
import { promisify } from "util";

const execFileAsync = promisify(execFile);

const server = new Server(
  {
    name: "devbox-mcp-server",
    version: "0.1.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Helper to run devbox commands
async function runDevbox(args, options = {}) {
  const { cwd = process.cwd(), timeout = 120000 } = options;
  try {
    const { stdout, stderr } = await execFileAsync("devbox", args, {
      cwd,
      timeout,
      maxBuffer: 10 * 1024 * 1024, // 10MB buffer
    });
    return { success: true, stdout, stderr };
  } catch (error) {
    return {
      success: false,
      stdout: error.stdout || "",
      stderr: error.stderr || error.message,
      exitCode: error.code,
    };
  }
}

// Helper to fetch file list from GitHub API
async function fetchDocsList() {
  try {
    const response = await fetch(
      "https://api.github.com/repos/jetify-com/docs/git/trees/main?recursive=1",
      {
        headers: {
          "User-Agent": "devbox-mcp-server",
          "Accept": "application/vnd.github+json",
        },
      }
    );

    if (!response.ok) {
      throw new Error(`GitHub API returned ${response.status}: ${response.statusText}`);
    }

    const tree = await response.json();
    const docFiles = tree.tree
      .filter((item) => item.type === "blob" && (item.path.endsWith(".md") || item.path.endsWith(".mdx")))
      .map((item) => item.path)
      .sort();

    return { success: true, files: docFiles };
  } catch (error) {
    return {
      success: false,
      error: error.message,
    };
  }
}

// Helper to fetch raw content from GitHub
async function fetchRawContent(filePath) {
  try {
    const response = await fetch(
      `https://api.github.com/repos/jetify-com/docs/contents/${filePath}`,
      {
        headers: {
          "User-Agent": "devbox-mcp-server",
          "Accept": "application/vnd.github.raw",
        },
      }
    );

    if (!response.ok) {
      throw new Error(`GitHub API returned ${response.status}: ${response.statusText}`);
    }

    const content = await response.text();
    return { success: true, content };
  } catch (error) {
    return {
      success: false,
      error: error.message,
    };
  }
}

// Helper to search devbox docs
async function searchDocs(query, options = {}) {
  const { maxResults = 10 } = options;

  // Check for GitHub PAT token
  const githubToken = process.env.GITHUB_TOKEN || process.env.GITHUB_PAT;

  try {
    // Use GitHub's code search API
    // Search in the docs repo - most files are markdown anyway
    const searchQuery = `${query} repo:jetify-com/docs`;
    const url = new URL("https://api.github.com/search/code");
    url.searchParams.set("q", searchQuery);
    url.searchParams.set("per_page", String(maxResults));

    const headers = {
      "User-Agent": "devbox-mcp-server",
      "Accept": "application/vnd.github.text-match+json",
    };

    // Add authorization header if token is available
    if (githubToken) {
      headers["Authorization"] = `Bearer ${githubToken}`;
    }

    const response = await fetch(url, { headers });

    if (!response.ok) {
      // Return detailed error with helpful message for authentication issues
      const errorDetails = {
        status: response.status,
        statusText: response.statusText,
      };

      if (response.status === 401 || response.status === 403) {
        return {
          success: false,
          error: `GitHub API returned ${response.status}: ${response.statusText}`,
          requiresAuth: true,
          helpMessage: !githubToken
            ? "GitHub's code search API requires authentication. Please set a GitHub Personal Access Token (PAT) in your environment:\n\n" +
              "1. Create a PAT at: https://github.com/settings/tokens (fine-grained token with public_repo read access)\n" +
              "2. Set it as an environment variable:\n" +
              "   export GITHUB_TOKEN='your_token_here'\n" +
              "   or\n" +
              "   export GITHUB_PAT='your_token_here'\n\n" +
              "Alternatively, use devbox_docs_list to browse files, then devbox_docs_read to read specific docs."
            : "Your GitHub token may have expired or lacks the required permissions. Please check:\n\n" +
              "1. Token has 'public_repo' or 'repo' read access\n" +
              "2. Token hasn't expired (check https://github.com/settings/tokens)\n\n" +
              "Alternatively, use devbox_docs_list to browse files, then devbox_docs_read to read specific docs.",
        };
      }

      throw new Error(`GitHub API returned ${response.status}: ${response.statusText}`);
    }

    const data = await response.json();
    const results = data.items.map((item) => {
      // Extract first text match if available
      const match = item.text_matches?.[0];
      const fragment = match?.fragment || "";

      return {
        file: item.path,
        line: "1",
        content: fragment || "(match in file)",
      };
    });

    return { success: true, results, total: data.total_count };
  } catch (error) {
    return {
      success: false,
      error: error.message,
    };
  }
}

// Helper to list documentation files
async function listDocs() {
  return fetchDocsList();
}

// Helper to read a specific doc file
async function readDoc(filePath) {
  try {
    const result = await fetchRawContent(filePath);
    if (result.success) {
      return { success: true, content: result.content, filePath };
    }
    return result;
  } catch (error) {
    return {
      success: false,
      error: error.message,
      stderr: error.stderr || "",
    };
  }
}

// List available tools
server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "devbox_run",
        description:
          "Execute a devbox command or script. Can run scripts from devbox.json or any binary in PATH.\n\n" +
          "IMPORTANT: When a project has a devbox.json, ALWAYS use this tool instead of Bash commands. " +
          "Devbox ensures the correct tools and environment are available.\n\n" +
          "Project structure:\n" +
          "- devbox.json: Package and script definitions\n" +
          "- devbox.d/: Per-project configuration directory\n" +
          "- .devbox/virtenv/: Temporary runtime directory (auto-regenerated, never edit directly)\n\n" +
          "The .devbox/virtenv/ directory is automatically regenerated on 'devbox shell' or 'devbox run'. " +
          "Any manual changes to files in .devbox/virtenv/ will be lost.\n\n" +
          "OUTPUT MANAGEMENT: For commands that produce large output (builds, test suites, logs), " +
          "use the 'logFile' parameter to write output to a file instead of returning it inline. " +
          "This keeps context tokens low. The response will include the file path, exit status, " +
          "and a short summary. You can then read the log file selectively if needed.",
        inputSchema: {
          type: "object",
          properties: {
            command: {
              type: "string",
              description:
                "Command or script to run (e.g., 'test', 'android.sh devices list', 'pytest')",
            },
            args: {
              type: "array",
              items: { type: "string" },
              description: "Additional arguments to pass to the command",
            },
            pure: {
              type: "boolean",
              description: "Run in isolated environment (--pure flag)",
              default: false,
            },
            env: {
              type: "object",
              description: "Environment variables to set",
              additionalProperties: { type: "string" },
            },
            cwd: {
              type: "string",
              description: "Working directory (defaults to current directory)",
            },
            timeout: {
              type: "number",
              description: "Timeout in milliseconds (default: 120000)",
              default: 120000,
            },
            logFile: {
              type: "string",
              description:
                "Absolute path to write stdout+stderr to instead of returning inline. " +
                "Use for commands with large output (builds, test suites) to avoid filling context. " +
                "When set, the response returns a short summary with the log file path.",
            },
          },
          required: ["command"],
        },
      },
      {
        name: "devbox_list",
        description: "List installed packages in current devbox environment",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
        },
      },
      {
        name: "devbox_add",
        description: "Add package(s) to devbox.json",
        inputSchema: {
          type: "object",
          properties: {
            packages: {
              type: "array",
              items: { type: "string" },
              description: "Packages to add (e.g., ['python@3.11', 'nodejs@20'])",
            },
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
          required: ["packages"],
        },
      },
      {
        name: "devbox_info",
        description: "Get information about a package",
        inputSchema: {
          type: "object",
          properties: {
            package: {
              type: "string",
              description: "Package name",
            },
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
          required: ["package"],
        },
      },
      {
        name: "devbox_search",
        description: "Search for packages in Nix registry",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query",
            },
          },
          required: ["query"],
        },
      },
      {
        name: "devbox_docs_search",
        description:
          "Search devbox documentation for a keyword or phrase. Returns matching lines from the official devbox docs repository.\n\n" +
          "IMPORTANT - Authentication Required:\n" +
          "This tool requires a GitHub Personal Access Token (PAT) configured in the MCP server environment. " +
          "If the user hasn't configured their GITHUB_TOKEN, this tool will fail with a 403 error. " +
          "When this happens, inform the user they need to reconfigure their MCP server:\n\n" +
          "  claude mcp remove devbox-mcp -s user\n" +
          "  claude mcp add devbox-mcp -s user -e GITHUB_TOKEN=\"your_token\" -- node /path/to/devbox-mcp/src/index.js\n\n" +
          "To create a GitHub PAT:\n" +
          "1. Visit https://github.com/settings/tokens\n" +
          "2. Create a fine-grained token or classic token\n" +
          "3. Grant 'public_repo' or 'repo' read access\n" +
          "4. Set it as GITHUB_TOKEN environment variable in MCP config\n\n" +
          "Alternative: Use devbox_docs_list (no auth required) to browse files, then devbox_docs_read to read specific docs.",
        inputSchema: {
          type: "object",
          properties: {
            query: {
              type: "string",
              description: "Search query (keyword or phrase)",
            },
            maxResults: {
              type: "number",
              description: "Maximum number of results to return (default: 10)",
              default: 10,
            },
          },
          required: ["query"],
        },
      },
      {
        name: "devbox_docs_list",
        description: "List all available documentation files in the devbox documentation repository. Returns a list of file paths that can be read with devbox_docs_read.",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "devbox_docs_read",
        description: "Read the full content of a specific documentation file. Use the file path from devbox_docs_list results to read complete documentation.",
        inputSchema: {
          type: "object",
          properties: {
            filePath: {
              type: "string",
              description: "Path to the documentation file (e.g., 'app/docs/devbox.mdx', 'README.md')",
            },
          },
          required: ["filePath"],
        },
      },
      {
        name: "devbox_init",
        description: "Initialize a new devbox.json file in the specified directory. Creates a basic configuration that can be customized.",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Directory to initialize devbox in (defaults to current directory)",
            },
          },
        },
      },
      {
        name: "devbox_shell_env",
        description: "Get the environment variables that would be set in a devbox shell. Useful for understanding what PATH, variables, and tools are available.",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Working directory",
            },
          },
        },
      },
      {
        name: "devbox_sync",
        description:
          "Ensure the .devbox/virtenv/ directory is up to date by regenerating it from devbox.json. " +
          "This is useful after modifying devbox.json or when the virtenv may be stale. " +
          "Equivalent to running 'devbox shell' which regenerates the virtenv.",
        inputSchema: {
          type: "object",
          properties: {
            cwd: {
              type: "string",
              description: "Working directory (defaults to current directory)",
            },
          },
        },
      },
    ],
  };
});

// Handle tool calls
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  switch (name) {
    case "devbox_run": {
      const { command, args: cmdArgs = [], pure = false, env = {}, cwd, timeout, logFile } = args;

      const devboxArgs = ["run"];
      if (pure) devboxArgs.push("--pure");

      // Add environment variables
      for (const [key, value] of Object.entries(env)) {
        devboxArgs.push("-e", `${key}=${value}`);
      }

      devboxArgs.push(command);
      if (cmdArgs.length > 0) {
        devboxArgs.push(...cmdArgs);
      }

      const result = await runDevbox(devboxArgs, { cwd, timeout });

      // If logFile is specified, write output to file and return summary
      if (logFile) {
        const fullOutput = [
          result.stdout || "",
          result.stderr ? `\n--- stderr ---\n${result.stderr}` : "",
        ].join("");

        try {
          await writeFile(logFile, fullOutput, "utf-8");
        } catch (writeErr) {
          return {
            content: [
              {
                type: "text",
                text: `✗ Failed to write log file: ${writeErr.message}\n\nCommand ${result.success ? "succeeded" : `failed (exit ${result.exitCode})`}`,
              },
            ],
            isError: true,
          };
        }

        const lines = fullOutput.split("\n");
        const lineCount = lines.length;
        const tail = lines.slice(-5).join("\n");

        return {
          content: [
            {
              type: "text",
              text: result.success
                ? `✓ Command succeeded (${lineCount} lines written to ${logFile})\n\nLast 5 lines:\n${tail}`
                : `✗ Command failed (exit ${result.exitCode}, ${lineCount} lines written to ${logFile})\n\nLast 5 lines:\n${tail}`,
            },
          ],
          isError: !result.success,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Command succeeded\n\nOutput:\n${result.stdout}${result.stderr ? `\nStderr:\n${result.stderr}` : ""}`
              : `✗ Command failed (exit ${result.exitCode})\n\nStdout:\n${result.stdout}\n\nStderr:\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_list": {
      const { cwd } = args;
      const result = await runDevbox(["list"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_add": {
      const { packages, cwd } = args;
      const result = await runDevbox(["add", ...packages], { cwd, timeout: 180000 });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Added packages: ${packages.join(", ")}\n\n${result.stdout}`
              : `✗ Failed to add packages\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_info": {
      const { package: pkg, cwd } = args;
      const result = await runDevbox(["info", pkg], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_search": {
      const { query } = args;
      const result = await runDevbox(["search", query]);

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? result.stdout
              : `Error: ${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_docs_search": {
      const { query, maxResults = 10 } = args;
      const result = await searchDocs(query, { maxResults });

      if (!result.success) {
        let errorMessage = `✗ Failed to search docs\n\nError: ${result.error}`;

        // Add helpful authentication message if authentication is required
        if (result.requiresAuth && result.helpMessage) {
          errorMessage += `\n\n${result.helpMessage}`;
        }

        if (result.stderr) {
          errorMessage += `\n\nDetails: ${result.stderr}`;
        }

        return {
          content: [
            {
              type: "text",
              text: errorMessage,
            },
          ],
          isError: true,
        };
      }

      const formatted = result.results
        .map((r) => `${r.file}:${r.line}: ${r.content}`)
        .join("\n");

      return {
        content: [
          {
            type: "text",
            text: `Found ${result.total} match(es) for "${query}" (showing ${result.results.length}):\n\n${formatted}`,
          },
        ],
      };
    }

    case "devbox_docs_list": {
      const result = await listDocs();

      if (!result.success) {
        return {
          content: [
            {
              type: "text",
              text: `✗ Failed to list docs\n\nError: ${result.error}\n${result.stderr ? `\nDetails: ${result.stderr}` : ""}`,
            },
          ],
          isError: true,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `Documentation files (${result.files.length}):\n\n${result.files.join("\n")}\n\nTip: Use devbox_docs_read to read any file.`,
          },
        ],
      };
    }

    case "devbox_docs_read": {
      const { filePath } = args;
      const result = await readDoc(filePath);

      if (!result.success) {
        return {
          content: [
            {
              type: "text",
              text: `✗ Failed to read doc\n\nError: ${result.error}\n${result.stderr ? `\nDetails: ${result.stderr}` : ""}`,
            },
          ],
          isError: true,
        };
      }

      return {
        content: [
          {
            type: "text",
            text: `# ${result.filePath}\n\n${result.content}`,
          },
        ],
      };
    }

    case "devbox_init": {
      const { cwd } = args;
      const result = await runDevbox(["init"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Initialized devbox.json\n\n${result.stdout}`
              : `✗ Failed to initialize devbox.json\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_shell_env": {
      const { cwd } = args;
      // Use 'devbox run' with 'env' command to get the shell environment
      const result = await runDevbox(["run", "env"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `Environment variables in devbox shell:\n\n${result.stdout}`
              : `✗ Failed to get shell environment\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    case "devbox_sync": {
      const { cwd } = args;
      // Run 'devbox shell --refresh' to regenerate virtenv
      // Using echo true to exit immediately after regeneration
      const result = await runDevbox(["shell", "--refresh", "-c", "echo Virtenv regenerated"], { cwd });

      return {
        content: [
          {
            type: "text",
            text: result.success
              ? `✓ Virtenv synchronized\n\nThe .devbox/virtenv/ directory has been regenerated from devbox.json.\n\n${result.stdout}`
              : `✗ Failed to sync virtenv\n\n${result.stderr}`,
          },
        ],
        isError: !result.success,
      };
    }

    default:
      throw new Error(`Unknown tool: ${name}`);
  }
});

// Start server
async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("Devbox MCP server running on stdio");
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
