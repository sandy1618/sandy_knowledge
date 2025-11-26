# Agents Creation

This folder contains Claude Code agent definitions that can be used to automate and enhance your workflow.

## How to Use These Agents

1. Copy the `.md` file to your `~/.claude/agents/` directory
2. Restart Claude Code or start a new session
3. Invoke the agent using `@agent-<agent_name>`

## Available Agents

| Agent | File | Purpose |
|-------|------|---------|
| **knowledge_agent** | [[knowledge_agent]] | Manages the sandy_knowledge Obsidian vault - creates documentation, migrates learnings from repos, and organizes content |

## Agent File Structure

Each agent file uses this frontmatter format:

```yaml
---
name: agent_name
description: Description shown when invoking the agent
model: sonnet  # or opus, haiku
color: green   # UI color indicator
---

[Agent instructions in markdown]
```

## Creating New Agents

To create a new agent:

1. Create a new `.md` file in `~/.claude/agents/`
2. Add the YAML frontmatter with name, description, model, and color
3. Write detailed instructions for the agent's behavior
4. Include examples of expected input/output
5. Save and restart Claude Code

## Related Topics

- [[GKE Hands-On Tutorial]] - Example of content created by knowledge_agent
- [[GKE Overview]] - Conceptual documentation created by knowledge_agent

## Tags
#claude-code #agents #automation #workflow
