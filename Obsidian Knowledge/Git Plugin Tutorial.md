---
title: Obsidian Git Plugin Tutorial
tags: [obsidian, git, tutorial, version-control]
created: 2025-11-24
---

# Obsidian Git Plugin Tutorial

Complete guide to using the Obsidian Git plugin for automatic version control.


## 📥 Installation

### Method 1: Community Plugins (Recommended)

1. Open Obsidian Settings (`Cmd/Ctrl + ,`)
2. Navigate to **Community Plugins**
3. Click **Browse**
4. Search for "**Obsidian Git**"
5. Click **Install**
6. Enable the plugin

### Method 2: Manual Installation

```bash
cd /Users/user/Repository/sandy_knowledge/.obsidian/plugins/
git clone https://github.com/denolehov/obsidian-git.git
cd obsidian-git
npm install
npm run build
```

Then enable in Obsidian settings.

## ⚙️ Initial Configuration

### 1. Basic Settings

**Settings → Obsidian Git → General**

```
✅ Auto-pull on startup
✅ Auto-save after file change
⚙️ Auto-save interval: 5 minutes
✅ Auto-commit on save
⚙️ Commit message: "vault backup: {{date}}"
```

### 2. Recommended Settings

```json
{
  "autoPullOnBoot": true,
  "autoSaveInterval": 5,
  "autoCommitMessage": "vault backup: {{date}}",
  "autoPushInterval": 30,
  "disablePush": false,
  "pullBeforePush": true,
  "differentIntervalCommitAndPush": true
}
```

### 3. Commit Message Templates

You can use variables in commit messages:

- `{{date}}` - Current date (YYYY-MM-DD)
- `{{numFiles}}` - Number of files changed
- `{{files}}` - List of changed files
- `{{hostname}}` - Computer name

**Examples:**
```
"vault backup: {{date}}"
"auto-save: {{numFiles}} files on {{date}}"
"📝 {{date}}: {{files}}"
```

## 🎮 Basic Commands

### Via Command Palette (`Cmd/Ctrl + P`)

| Command | Description |
|---------|-------------|
| `Git: Commit all changes` | Manually commit staged changes |
| `Git: Push` | Push commits to remote |
| `Git: Pull` | Pull changes from remote |
| `Git: Backup` | Commit + Push in one step |
| `Git: List changed files` | See what's modified |
| `Git: Open diff view` | View changes |
| `Git: Clone` | Clone a vault from GitHub |

### Hotkeys (Recommended)

Set up custom hotkeys in Settings:

```
Cmd/Ctrl + Shift + G : Git Backup (commit + push)
Cmd/Ctrl + Shift + P : Git Push
Cmd/Ctrl + Shift + L : List changed files
```

## 🔄 Workflows

### Workflow 1: Automatic Sync

**Best for solo use:**

1. Enable auto-pull on startup
2. Enable auto-commit after changes (5 min interval)
3. Enable auto-push (30 min interval)

**Result:** Vault automatically syncs without manual intervention!

### Workflow 2: Manual Control

**Best for collaborative work:**

1. Disable auto-push
2. Enable auto-commit only
3. Manually push via command palette when ready

### Workflow 3: Hybrid

**Recommended for this vault:**

1. Auto-commit every 5 minutes
2. Auto-push every 30 minutes
3. Manual pull when needed
4. Review changes before push (optional)

## 📋 Daily Usage Examples

### Morning Routine

1. Open Obsidian
2. Plugin auto-pulls latest changes
3. Start working on notes
4. Changes auto-commit every 5 min
5. Changes auto-push every 30 min

### Before Important Changes

```
1. Cmd+P → "Git: Pull" (get latest)
2. Make your changes
3. Cmd+P → "Git: List changed files" (review)
4. Cmd+P → "Git: Backup" (commit + push)
```

### Reviewing History

```
1. Cmd+P → "Git: Open diff view"
2. Or use GitHub to view history
3. Or use command line: git log --oneline
```

## 🔧 Advanced Configuration

### Custom Commit Messages

**Settings → Obsidian Git → Commit Message**

```
{{date}} - {{numFiles}} file(s) updated

Changed files:
{{files}}
```

### Exclude Files from Auto-commit

Create `.gitignore` in vault (already done):

```gitignore
.obsidian/workspace.json
.obsidian/cache/
.trash/
```

### Sync Specific Folders Only

**Settings → Obsidian Git → Advanced**

```
Include patterns: Obsidian Knowledge/**, daily/**
Exclude patterns: private/**
```

## 🚨 Troubleshooting

### Issue: "No remote configured"

**Solution:**
```bash
cd /Users/user/Repository/sandy_knowledge
git remote add origin https://github.com/sandy1618/sandy_knowledge.git
```

### Issue: "Authentication failed"

**Solution:** Configure Git credentials

```bash
# Use SSH instead of HTTPS
git remote set-url origin git@github.com:sandy1618/sandy_knowledge.git

# Or configure GitHub token
git config credential.helper store
```

### Issue: "Merge conflicts"

**Solution:**

1. `Cmd+P` → "Git: Pull"
2. Manually resolve conflicts in affected files
3. `Cmd+P` → "Git: Commit all changes"
4. Add message: "Resolved merge conflicts"
5. `Cmd+P` → "Git: Push"

### Issue: "Push rejected"

**Solution:**
```bash
cd /Users/user/Repository/sandy_knowledge
git pull --rebase
# Resolve any conflicts
git push
```

### Issue: Plugin not working

**Checklist:**
- ✅ Git installed on system (`git --version`)
- ✅ Repository initialized (`ls -la .git`)
- ✅ Remote configured (`git remote -v`)
- ✅ Plugin enabled in Obsidian
- ✅ Valid credentials configured

## 🎯 Best Practices

### DO ✅

1. **Pull before making major changes**
2. **Review commit history occasionally**
3. **Use descriptive commit messages**
4. **Enable auto-pull on startup**
5. **Backup API keys separately** (not in vault)

### DON'T ❌

1. **Don't commit large binary files** (use Git LFS)
2. **Don't commit sensitive info** (API keys, passwords)
3. **Don't disable auto-pull** (can cause conflicts)
4. **Don't force push** (can lose data)

## 📊 Status Bar

The plugin shows Git status in the bottom status bar:

```
✅ All changes committed
🔄 Syncing...
⚠️ 3 files changed
❌ Error: push failed
```

Click the status to see more details.

## 🔗 Integration with This Vault

### Current Setup

✅ Git repository initialized
✅ Remote: `https://github.com/sandy1618/sandy_knowledge.git`
✅ Branch: `master`
✅ Git LFS configured
✅ `.gitignore` configured

### Next Steps

1. Install Obsidian Git plugin
2. Configure auto-sync (5 min commit, 30 min push)
3. Set up hotkeys
4. Test with a small change
5. Monitor status bar

## 📚 Commands Reference

### Via Command Palette

```
Git: Commit all changes           - Commit staged files
Git: Commit all changes with...   - Commit with custom message
Git: Push                         - Push to remote
Git: Pull                         - Pull from remote
Git: Backup                       - Commit + Push
Git: List changed files           - See modifications
Git: Open diff view               - View changes
Git: Initialize repo              - Create new repo
Git: Clone                        - Clone from URL
Git: Branch                       - Manage branches
Git: Checkout                     - Switch branches
```

### Via Terminal (Advanced)

```bash
cd /Users/user/Repository/sandy_knowledge

# View status
git status

# View history
git log --oneline -10

# View changes
git diff

# Undo last commit (keep changes)
git reset --soft HEAD~1

# View remote
git remote -v

# View branches
git branch -a
```

## 🔐 Security Tips

1. **Use SSH keys instead of HTTPS**
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   # Add to GitHub: Settings → SSH Keys
   git remote set-url origin git@github.com:sandy1618/sandy_knowledge.git
   ```

2. **Never commit API keys**
   - Already in `.gitignore`
   - Store separately in password manager

3. **Review before pushing**
   - Use "List changed files" command
   - Check diff view

## 📖 Resources

- [Obsidian Git Plugin Docs](https://github.com/denolehov/obsidian-git)
- [Git Documentation](https://git-scm.com/doc)
- [[Setup Guide]] - Vault configuration
- [[REST API Usage Guide]] - API integration

## 🎓 Quick Start Checklist

- [ ] Install Obsidian Git plugin
- [ ] Enable auto-pull on startup
- [ ] Set auto-commit interval (5 min)
- [ ] Set auto-push interval (30 min)
- [ ] Configure commit message template
- [ ] Set up hotkeys
- [ ] Test commit + push manually
- [ ] Verify on GitHub
- [ ] Enable status bar monitoring

---

**Status:** Ready to install and configure
**Last Updated:** 2025-11-24



