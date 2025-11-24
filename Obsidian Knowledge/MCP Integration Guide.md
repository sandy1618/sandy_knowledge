---
title: MCP Integration Guide
tags: [obsidian, mcp, ai, integration, copilot]
created: 2025-11-24
---

# MCP Integration Guide

This vault is configured to work with AI agents via the Model Context Protocol (MCP).

## 🎯 What is MCP?

**Model Context Protocol** allows AI agents (like GitHub Copilot) to interact with external tools and data sources, including your Obsidian vault.

## ⚙️ Current Configuration

### Location
`.vscode/settings.json`

### Configuration

```json
{
  "mcpServers": {
    "obsidian": {
      "command": "npx",
      "args": ["-y", "obsidian-mcp-server"],
      "env": {
        "OBSIDIAN_VAULT_PATH": "/Users/user/Repository/sandy_knowledge"
      }
    }
  }
}
```

### What This Enables

✅ **Search vault** - AI can search your notes
✅ **Read notes** - AI can read note contents
✅ **Create notes** - AI can create new notes
✅ **Update notes** - AI can edit existing notes
✅ **Follow links** - AI can navigate wikilinks
✅ **Query tags** - AI can find notes by tags

## 🚀 Usage

### In VSCode with GitHub Copilot

After reloading VSCode, you can ask Copilot:

**Search queries:**
```
"Search my Obsidian vault for notes about Git"
"Find all notes tagged with #setup"
"What notes do I have about API integration?"
```

**Read operations:**
```
"Read the Setup Guide from my vault"
"Show me the content of Welcome.md"
"What's in my Git Plugin Tutorial?"
```

**Create operations:**
```
"Create a new note about Python in my vault"
"Add a daily note for today"
"Create a note explaining Docker basics"
```

**Update operations:**
```
"Add a section about testing to my Setup Guide"
"Update the REST API guide with error handling"
"Add today's date to Welcome.md"
```

### How It Works

```
┌─────────────────────┐
│   GitHub Copilot    │
│   (in VSCode)       │
└──────────┬──────────┘
           │
           │ MCP Protocol
           ▼
┌─────────────────────┐
│  obsidian-mcp-      │
│  server (npx)       │
└──────────┬──────────┘
           │
           │ File System
           ▼
┌─────────────────────┐
│  Obsidian Vault     │
│  (This Folder)      │
└─────────────────────┘
```

## 📦 Dependencies

The MCP server is loaded via `npx`, which automatically downloads and runs:

```
obsidian-mcp-server
```

**Requirements:**
- Node.js installed
- npm/npx available
- Vault path correctly set

## 🔍 Available MCP Tools

### 1. `search_vault`
Search notes by content or metadata

**Example:**
```javascript
{
  "query": "git plugin",
  "limit": 10
}
```

### 2. `read_note`
Read a specific note by path

**Example:**
```javascript
{
  "path": "Obsidian Knowledge/Setup Guide.md"
}
```

### 3. `create_note`
Create a new note

**Example:**
```javascript
{
  "path": "daily/2025-11-24.md",
  "content": "# Daily Note\n\n- Task 1\n- Task 2"
}
```

### 4. `update_note`
Update existing note content

**Example:**
```javascript
{
  "path": "Welcome.md",
  "content": "Updated content..."
}
```

### 5. `list_tags`
Get all tags in the vault

**Example:**
```javascript
{}  // No parameters needed
```

### 6. `get_note_by_tag`
Find notes with specific tag

**Example:**
```javascript
{
  "tag": "setup"
}
```

## 🧪 Testing the Integration

### Test 1: Simple Search

Ask Copilot:
> "Search my vault for notes about setup"

Expected: Returns Setup Guide and related notes

### Test 2: Read Note

Ask Copilot:
> "Read the Welcome note from my vault"

Expected: Shows Welcome.md content

### Test 3: Create Note

Ask Copilot:
> "Create a test note in my vault about MCP testing"

Expected: Creates new note with content

### Test 4: Complex Query

Ask Copilot:
> "What guides do I have in the Obsidian Knowledge folder?"

Expected: Lists all guides in that folder

## 🔄 Reload After Changes

After modifying `.vscode/settings.json`:

1. **Reload VSCode Window**
   - `Cmd/Ctrl + Shift + P`
   - Type "Developer: Reload Window"
   - Press Enter

2. **Verify MCP Server**
   - Ask Copilot to search your vault
   - Check for successful response

## 🐛 Troubleshooting

### Issue: "MCP server not found"

**Solutions:**
1. Check Node.js is installed: `node --version`
2. Check npx is available: `npx --version`
3. Manually install: `npm install -g obsidian-mcp-server`
4. Reload VSCode window

### Issue: "Vault path not found"

**Solution:**
Verify path in `.vscode/settings.json`:
```json
"OBSIDIAN_VAULT_PATH": "/Users/user/Repository/sandy_knowledge"
```

### Issue: "Permission denied"

**Solution:**
```bash
chmod -R 755 /Users/user/Repository/sandy_knowledge
```

### Issue: "MCP server crashes"

**Check logs:**
1. Open VS Code Developer Tools
2. Go to Console tab
3. Look for MCP-related errors

## 🔒 Security Considerations

### What the MCP Server Can Do

✅ Read all notes in the vault
✅ Create new notes
✅ Modify existing notes
✅ Delete notes (if implemented)

### What It Cannot Do

❌ Access files outside the vault
❌ Run arbitrary commands
❌ Access network without permission

### Best Practices

1. **Review AI changes** before committing
2. **Use Git** to track all modifications
3. **Backup regularly** (auto-commit helps)
4. **Limit vault path** to specific folder if needed

## 🎨 Advanced Usage

### Custom MCP Server

Create your own MCP server for specialized needs:

```typescript
// custom-obsidian-mcp/index.ts
import { Server } from "@modelcontextprotocol/sdk/server/index.js";

const server = new Server({
  name: "custom-obsidian",
  version: "1.0.0",
});

// Add custom tools
server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "analyze_vault") {
    // Custom analysis logic
    return { result: "Analysis complete" };
  }
});
```

Update `.vscode/settings.json`:
```json
{
  "mcpServers": {
    "obsidian": {
      "command": "node",
      "args": ["/path/to/custom-obsidian-mcp/index.js"],
      "env": {
        "VAULT_PATH": "/Users/user/Repository/sandy_knowledge"
      }
    }
  }
}
```

## 🔗 Integration with Other Tools

### Combine with REST API

Use both MCP (for AI) and REST API (for scripts):

```python
# AI agent uses MCP
# Your scripts use REST API
# Both work on same vault!

from obsidian_api import ObsidianVault

vault = ObsidianVault()
notes = vault.search("tag:#ai")

# AI via MCP can now access these same notes
```

### Combine with Git Plugin

Workflow:
1. AI creates/modifies notes via MCP
2. Git plugin auto-commits changes
3. Changes pushed to GitHub
4. Full version history maintained

## 📊 Monitoring

### Check MCP Server Status

**In Copilot Chat:**
> "List available tools"

Should show obsidian-related tools if connected.

### View MCP Logs

VSCode Output Panel → Select "Model Context Protocol"

## 📚 Resources

- [MCP Documentation](https://modelcontextprotocol.io)
- [obsidian-mcp-server on npm](https://www.npmjs.com/package/obsidian-mcp-server)
- [[Setup Guide]] - Overall configuration
- [[REST API Usage Guide]] - Alternative access method

## ✅ Quick Start Checklist

- [x] MCP configuration added to `.vscode/settings.json`
- [ ] VSCode window reloaded
- [ ] Node.js and npx verified
- [ ] Test search query with Copilot
- [ ] Test read operation
- [ ] Test create operation
- [ ] Verify Git auto-commits AI changes

---

**Status:** Configured and ready to use
**Last Updated:** 2025-11-24
