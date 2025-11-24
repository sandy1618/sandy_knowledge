---
title: Obsidian Publishing Plugins
tags: [obsidian, plugins, publishing, automation]
created: 2025-11-24
---

# Obsidian Publishing Plugins

Complete guide to Obsidian plugins for publishing your vault online.

## 🎯 Why Use Plugins?

**Benefits:**
- ✅ Publish directly from Obsidian
- ✅ No terminal commands needed
- ✅ Right-click to publish notes
- ✅ Selective publishing
- ✅ Automatic updates

## 🔌 Top Publishing Plugins

### 1. **Obsidian Digital Garden** ⭐⭐⭐

**Best for:** Complete beginners, one-click publishing

#### Installation

1. Open Obsidian Settings (`Cmd + ,`)
2. Navigate to **Community Plugins**
3. Click **Browse**
4. Search "**Digital Garden**"
5. Click **Install**
6. Click **Enable**

#### Setup Guide

**Step 1: Create GitHub Repository**
```bash
# Go to: github.com/new
# Repository name: digital-garden
# Make it public
# Initialize with README: No
```

**Step 2: Get GitHub Token**
```
1. Visit: github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Note: "Obsidian Digital Garden"
4. Scopes: Check "repo" (all repo permissions)
5. Generate token
6. COPY TOKEN (you won't see it again!)
```

**Step 3: Configure Plugin**
```
Settings → Digital Garden

Required Settings:
├─ GitHub Username: sandy1618
├─ GitHub Repo: digital-garden
├─ GitHub Token: [paste your token]
└─ Base URL: https://sandy1618.github.io/digital-garden

Optional Settings:
├─ Base Theme: dark/light
├─ Note Icon Type: emoji/lucide
└─ Default Note Icon: 📝
```

**Step 4: Deploy to Netlify**
```
1. Visit: app.netlify.com
2. Click "Add new site" → "Import an existing project"
3. Connect to GitHub
4. Select "digital-garden" repo
5. Build settings:
   - Build command: (leave empty)
   - Publish directory: dist
6. Click "Deploy"

Your site: https://[random-name].netlify.app
```

**Step 5: Custom Domain (Optional)**
```
In Netlify:
1. Site settings → Domain management
2. Add custom domain: notes.yourdomain.com
3. Configure DNS (Netlify provides instructions)
```

#### Publishing Notes

**Method 1: Right-Click Menu**
```
1. Right-click any note
2. Select "Publish to Digital Garden"
3. Wait a few seconds
4. Note is live! 🎉
```

**Method 2: Command Palette**
```
1. Open Command Palette (Cmd + P)
2. Type "Digital Garden: Publish"
3. Select note(s) to publish
```

**Method 3: Frontmatter (Auto-publish)**
```yaml
---
dg-publish: true
dg-home: true  # Make it homepage
---

# Your Note Content
```

#### Features

**✅ Wikilinks Support**
```markdown
[[Other Note]]  # Works automatically!
![[image.png]]  # Images embedded
```

**✅ Graph View**
- Interactive note connections
- Backlinks displayed
- Visual knowledge graph

**✅ Selective Publishing**
```yaml
---
dg-publish: true   # Publish this note
dg-hide: true      # Hide from graph
---
```

**✅ Custom Styling**
```css
/* In settings → Custom CSS */
.content {
  max-width: 800px;
  font-family: 'Inter', sans-serif;
}
```

#### Example Workflow

```
Morning:
1. Write notes in Obsidian
2. Right-click → "Publish to Digital Garden"
3. Check site: notes.yourdomain.com
4. Share links with others!

Automatic:
- Images auto-uploaded
- Links auto-converted
- Site auto-rebuilds
- No manual steps!
```

#### Troubleshooting

**Issue: "GitHub token invalid"**
```
Solution:
1. Regenerate token at github.com/settings/tokens
2. Ensure "repo" scope is checked
3. Copy new token to plugin settings
```

**Issue: "Note not appearing"**
```
Solution:
1. Check frontmatter: dg-publish: true
2. Wait 1-2 minutes for build
3. Clear browser cache
4. Check Netlify deploy logs
```

**Issue: "Images not loading"**
```
Solution:
1. Ensure images are in vault
2. Use relative paths: ![[image.png]]
3. Check image file size (< 1MB recommended)
4. Re-publish the note
```

---

### 2. **Obsidian Enveloppe** (Advanced)

**Best for:** Multi-platform, advanced users

#### Installation

```
Settings → Community Plugins → Browse → "Enveloppe"
```

#### Configuration

**Basic Setup:**
```yaml
# In plugin settings:
Repository Type: GitHub
Owner: sandy1618
Repository: sandy_knowledge
Branch: gh-pages
Root folder: docs/

GitHub Token: [your token]
```

**Publishing Rules:**
```yaml
# In note frontmatter:
---
share: true          # Must be true to publish
category: blog       # Organize by category
path: articles/      # Custom path
---
```

#### Features

**✅ Multi-Platform Support**
- GitHub
- GitLab
- Gitea
- Self-hosted Git

**✅ Image Management**
- Auto-upload images
- Resize large images
- Convert to WebP
- Optimize for web

**✅ Path Remapping**
```yaml
# Map vault paths to site paths
Obsidian Knowledge/ → docs/guides/
Git Knowledge/ → docs/git/
```

**✅ Compatible with:**
- Jekyll
- Hugo
- MkDocs
- Quartz
- Any static site generator

#### Publishing Workflow

**Single Note:**
```
Cmd + P → "Enveloppe: Upload file"
```

**Multiple Notes:**
```
Cmd + P → "Enveloppe: Upload all shared notes"
```

**Automatic:**
```yaml
# Enable auto-upload in settings
Auto-upload on save: true
```

---

### 3. **GitHub Publisher**

**Best for:** Direct GitHub integration

#### Installation

```
Community Plugins → "GitHub Publisher"
```

#### Setup

**Plugin Configuration:**
```yaml
Main Repository:
- Username: sandy1618
- Repository: sandy_knowledge
- Branch: master

Publishing:
- Folder path: content/
- Automatically add timestamp: true
- Commit message: "Published from Obsidian"
```

#### Usage

**Publish Commands:**
```
Cmd + P → "GitHub Publisher: Upload current note"
Cmd + P → "GitHub Publisher: Upload all notes"
Cmd + P → "GitHub Publisher: Delete published note"
```

**Frontmatter Control:**
```yaml
---
share: true
title: My Published Note
date: 2025-11-24
---
```

#### Features

- ✅ Direct push to GitHub
- ✅ Automatic commits
- ✅ Delete from web
- ✅ Batch operations
- ✅ Image embedding

---

### 4. **Webpage Export**

**Best for:** Offline HTML export, no hosting needed

#### Installation

```
Community Plugins → "Webpage Export"
```

#### Features

**✅ Self-Contained HTML**
- Single HTML file
- Embedded CSS
- Embedded images
- No dependencies

**✅ Customization**
```css
/* Add custom styles */
body {
  font-family: 'Georgia', serif;
  max-width: 800px;
  margin: 0 auto;
}
```

#### Usage

**Export Single Note:**
```
Right-click note → "Export as webpage"
Select export location
Share HTML file!
```

**Bulk Export:**
```
Cmd + P → "Webpage Export: Export all notes"
```

**Perfect for:**
- Email attachments
- USB drives
- Archive purposes
- Offline viewing

---

### 5. **Obsidian Link Converter** (Helper)

**Best for:** Converting links for publishing

#### Features

**Convert between formats:**
```markdown
# Wikilinks → Markdown
[[note]] → [note](note.md)

# Absolute → Relative
/vault/note.md → ../note.md

# Fix broken links
```

#### Usage

```
Cmd + P → "Link Converter: Convert links"
Select conversion type
All links updated!
```

---

## 📊 Plugin Comparison

| Plugin | Ease | Features | Hosting | Best For |
|--------|------|----------|---------|----------|
| **Digital Garden** | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Netlify | Beginners |
| **Enveloppe** | ⭐⭐ | ⭐⭐⭐⭐⭐ | Any | Power users |
| **GitHub Publisher** | ⭐⭐ | ⭐⭐⭐⭐ | GitHub | GitHub fans |
| **Webpage Export** | ⭐⭐⭐ | ⭐⭐⭐ | None | Offline use |

## 🎯 Recommended Setup

### For Your Vault

**Best Option: Digital Garden Plugin**

**Why:**
1. ✅ Easiest to set up
2. ✅ Beautiful out of the box
3. ✅ Graph view included
4. ✅ Free Netlify hosting
5. ✅ Right-click to publish

**Setup Time:** 15 minutes
**Maintenance:** Zero

### Complete Workflow

```
Your Setup:
1. Obsidian (editing)
2. Digital Garden Plugin (publishing)
3. Git Plugin (version control)
4. Netlify (hosting)

Workflow:
1. Write notes in Obsidian
2. Right-click → "Publish to Digital Garden"
3. Git plugin auto-commits
4. Netlify auto-deploys
5. Site updates automatically

Result: Zero manual work! 🎉
```

## 🔧 Advanced Integration

### Combine All Tools

```
Obsidian
  ├─ Digital Garden Plugin (publish)
  ├─ Git Plugin (version control)
  ├─ MCP Server (AI access)
  └─ REST API (programmatic)

GitHub
  ├─ Repository (storage)
  └─ Actions (automation)

Netlify
  └─ Hosting (public site)

Result: Full automation + control
```

## 💡 Pro Tips

**1. Test Before Publishing**
```yaml
# Use frontmatter
---
dg-publish: false  # Draft mode
dg-test: true      # Test in preview
---
```

**2. Organize with Folders**
```
Published/
├─ Blog/
├─ Guides/
└─ Reference/

Private/
└─ Personal notes (not published)
```

**3. Use Templates**
```yaml
---
dg-publish: true
dg-home: false
tags: [{{tags}}]
---

# {{title}}

Created: {{date}}
```

**4. Monitor Analytics**
```
Add to Netlify:
Settings → Build & deploy → Post processing
Enable analytics (free tier)
```

**5. Backup Everything**
```bash
# Git already backs up content
# But also backup:
- Plugin settings (.obsidian/)
- Custom CSS
- Templates
```

## 🚨 Common Issues

### Publishing Fails

**Check:**
- [ ] GitHub token valid?
- [ ] Repository exists?
- [ ] Internet connection?
- [ ] Frontmatter correct?

### Images Not Showing

**Check:**
- [ ] Images in vault?
- [ ] Correct path format?
- [ ] File size < 1MB?
- [ ] Re-publish note?

### Site Not Updating

**Check:**
- [ ] Netlify deploy successful?
- [ ] Clear browser cache?
- [ ] Wait 1-2 minutes?
- [ ] Check deploy logs?

## 📚 Resources

- [Digital Garden Docs](https://dg-docs.ole.dev/)
- [Enveloppe GitHub](https://github.com/Enveloppe/obsidian-enveloppe)
- [Netlify Docs](https://docs.netlify.com/)

## 🔗 Related

- [[Free Publishing Options]] - All publishing methods
- [[Setup Guide]] - Vault configuration
- [[Git Plugin Tutorial]] - Version control

---

**Recommendation:** Start with Digital Garden Plugin
**Setup Time:** 15 minutes
**Cost:** $0/month
**Maintenance:** Zero

**Last Updated:** 2025-11-24
