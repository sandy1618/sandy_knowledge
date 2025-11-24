---
title: Obsidian Vault Setup Guide
tags: [obsidian, setup, guide]
created: 2025-11-24
---

# Obsidian Vault Setup Guide

This document describes the complete setup of this Obsidian vault.

## 📁 Repository Structure

```
sandy_knowledge/
├── .obsidian/              # Obsidian configuration
│   ├── app.json           # App settings
│   ├── appearance.json    # Theme/UI settings
│   ├── core-plugins.json  # Core plugins config
│   └── graph.json         # Graph view settings
├── .vscode/               # VSCode configuration
│   └── settings.json      # MCP server config
├── Obsidian Knowledge/    # Meta documentation
├── .gitignore            # Git ignore rules
├── .gitattributes        # Git LFS configuration
└── Welcome.md            # Initial note
```

## 🔧 Current Setup

### 1. Git Repository

**Initialized:** 2025-11-24
- **Remote:** https://github.com/sandy1618/sandy_knowledge.git
- **Branch:** master
- **Status:** Private repository

### 2. Git LFS Configuration

Large files are tracked with Git LFS:

```
Documents: *.pdf
Images: *.png, *.jpg, *.jpeg, *.gif, *.webp
Videos: *.mp4, *.mov, *.avi
Audio: *.mp3, *.wav, *.m4a
Archives: *.zip, *.tar.gz
```

### 3. Git Ignore Rules

**Tracked:**
- ✅ All markdown notes (.md)
- ✅ Obsidian settings (app.json, core-plugins.json, etc.)
- ✅ Plugin configurations
- ✅ Attachments (via Git LFS)

**Ignored:**
- ❌ workspace.json (personal tab layout)
- ❌ workspace-mobile.json
- ❌ .obsidian/cache/
- ❌ .trash/
- ❌ System files (.DS_Store)

### 4. MCP Server Integration

**Configuration:** `.vscode/settings.json`

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

**Capabilities:**
- Search vault from GitHub Copilot
- Read/write notes via AI
- Follow wikilinks
- Query by tags

### 5. REST API Access

**Plugin:** Obsidian Local REST API
- **Base URL:** http://localhost:27123
- **API Key:** `acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809`
- **Status:** ⚠️ Requires Obsidian to be running

## 📚 Reference Documents

- [[REST API Usage Guide]] - How to use the REST API
- [[Git Plugin Tutorial]] - Using Git within Obsidian
- [[MCP Integration Guide]] - AI agent integration

## 🎯 Use Cases

This vault is designed for:

1. **Knowledge Management** - Store and organize notes
2. **AI Agent Access** - Programmatic access via MCP/REST API
3. **Version Control** - Track changes with Git
4. **Collaboration** - Share via GitHub (when needed)
5. **Cross-Platform** - Sync across devices

## 🔄 Workflow

### Daily Usage
1. Open Obsidian
2. Create/edit notes
3. Git automatically tracks changes (with Git plugin)
4. Push to GitHub periodically

### AI Agent Access
1. Via MCP: Ask Copilot to interact with vault
2. Via REST API: Use Python/Node.js scripts
3. Via File System: Direct file access

## 🚀 Next Steps

- [ ] Install Git plugin in Obsidian
- [ ] Configure auto-sync
- [ ] Set up templates
- [ ] Add more plugins (Dataview, etc.)
- [ ] Create folder structure for different topics
