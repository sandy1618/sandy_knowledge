---
title: Free Obsidian Publishing Options
tags: [obsidian, publishing, web, free, hosting]
created: 2025-11-24
---

# Free Obsidian Publishing Options

Complete guide to publishing your Obsidian vault online for **FREE** (no $8/month Obsidian Publish cost).

## 🆚 Obsidian Publish (Paid) vs Free Alternatives

| Feature | Obsidian Publish | Free Alternatives |
|---------|------------------|-------------------|
| **Cost** | $8/month | ✅ Free |
| **Setup** | 1-click | Manual setup |
| **Hosting** | Obsidian | GitHub Pages / Netlify / Vercel |
| **Custom Domain** | ✅ Yes | ✅ Yes (free) |
| **Maintenance** | ✅ Automatic | Manual updates |
| **Speed** | ⚡ Fast | ⚡ Fast (CDN) |

## 🏆 Top Free Solutions

## 🔌 Obsidian Plugins (Easiest!)

### 1. **Obsidian Digital Garden** ⭐⭐⭐ (EASIEST)

**Best for:** One-click publishing from Obsidian

**Installation:**
1. Settings → Community Plugins → Browse
2. Search "Digital Garden"
3. Install & Enable

**Setup:**

```bash
# 1. Create GitHub repo: username/digital-garden

# 2. Get GitHub token
# Go to: github.com/settings/tokens
# Generate new token (classic)
# Scopes: repo (all)

# 3. Configure plugin in Obsidian:
Settings → Digital Garden
- GitHub Username: sandy1618
- Repository Name: digital-garden
- GitHub Token: [paste token]
- Base URL: https://username.github.io/digital-garden

# 4. Deploy to Netlify
# Visit: app.netlify.com
# New site from Git → Connect repo
# Done!
```

**Usage:**
```
1. Right-click any note
2. Select "Publish to Digital Garden"
3. Note appears on your site instantly! 🎉
```

**Features:**
- ✅ Publish from Obsidian directly
- ✅ Wikilinks work automatically
- ✅ Graph view included
- ✅ Dark mode
- ✅ Mobile responsive
- ✅ Select which notes to publish

**Live Example:** https://notes.ole.dev

---

### 2. **Obsidian Enveloppe** (Flexible)

**Best for:** Multi-platform publishing (GitHub, GitLab, etc.)

**Installation:**
1. Settings → Community Plugins → Browse
2. Search "Enveloppe"
3. Install & Enable

**Features:**
- ✅ Publish to GitHub/GitLab
- ✅ Automatic image upload
- ✅ Frontmatter control
- ✅ Path remapping
- ✅ Works with Jekyll/Hugo/MkDocs

**Configuration:**
```yaml
# In plugin settings:
GitHub Repository: sandy1618/sandy_knowledge
Branch: gh-pages
Upload path: docs/

# Frontmatter in notes:
---
share: true  # Only publish if true
---
```

**Usage:**
```
Cmd+P → "Enveloppe: Upload file"
```

---

### 3. **Obsidian GitHub Publisher**

**Best for:** Publishing to existing GitHub repos

**Installation:**
1. Community Plugins → "GitHub Publisher"
2. Configure with GitHub token

**Features:**
- ✅ Push notes to GitHub
- ✅ Automatic commit messages
- ✅ Image embedding
- ✅ Selective publishing

---

### 4. **Obsidian Webpage Export**

**Best for:** Standalone HTML export

**Installation:**
1. Community Plugins → "Webpage Export"

**Features:**
- ✅ Export to HTML
- ✅ Self-contained files
- ✅ Works offline
- ✅ No build process needed

**Usage:**
```
Right-click note → "Export to HTML"
```

---

## 🛠️ Static Site Generators

### 1. **Quartz** ⭐ (Most Popular)

**Best for:** Beautiful, feature-rich sites with graph view

**Features:**
- ✅ Graph view (like Obsidian)
- ✅ Backlinks
- ✅ Search functionality
- ✅ Dark/light mode
- ✅ Mobile responsive
- ✅ Wikilinks support
- ✅ Fast static site

**Setup:**

```bash
# 1. Install Quartz
git clone https://github.com/jackyzha0/quartz.git
cd quartz
npm i

# 2. Link your vault
npx quartz create

# Choose option 2: "Link an existing folder"
# Point to: /Users/user/Repository/sandy_knowledge

# 3. Build and preview
npx quartz build --serve

# 4. Deploy to GitHub Pages (free hosting)
npx quartz sync
```

**GitHub Pages Deploy:**
```bash
# One-time setup
npx quartz create
# Follow prompts to connect to GitHub

# Future updates (automatic via GitHub Actions)
git add .
git commit -m "Update content"
git push
```

**Live in 5 minutes!** 🚀

**Example Sites:**
- https://quartz.jzhao.xyz (Quartz creator's site)
- https://notes.nicolevanderhoeven.com

### 2. **Obsidian Publish with MkDocs** (Most Versatile)

**Best for:** Documentation-style sites, material design

**Features:**
- ✅ Material Design theme
- ✅ Search
- ✅ Navigation
- ✅ Plugins (diagrams, math, etc.)
- ✅ Multiple themes

**Setup:**

```bash
# 1. Clone template
git clone https://github.com/jobindjohn/obsidian-publish-mkdocs.git
cd obsidian-publish-mkdocs

# 2. Copy your vault content
cp -r /Users/user/Repository/sandy_knowledge/* docs/

# 3. Install dependencies
pip install mkdocs-material
pip install mkdocs-roamlinks-plugin

# 4. Preview locally
mkdocs serve

# 5. Deploy to GitHub Pages
mkdocs gh-deploy
```

**GitHub Actions (Auto-deploy):**

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy MkDocs
on:
  push:
    branches:
      - master
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: 3.x
      - run: pip install mkdocs-material mkdocs-roamlinks-plugin
      - run: mkdocs gh-deploy --force
```

**Your site:** `https://<username>.github.io/<repo>/`

### 3. **Jekyll Garden** (GitHub Native)

**Best for:** Minimal setup, GitHub integration

**Features:**
- ✅ One-click deploy
- ✅ Wikilinks support
- ✅ Backlinks
- ✅ Graph view
- ✅ Clean design

**Setup:**

```bash
# 1. Use template
# Go to: https://github.com/Jekyll-Garden/jekyll-garden.github.io
# Click "Use this template" → "Create a new repository"

# 2. Clone your new repo
git clone https://github.com/<username>/<repo>.git
cd <repo>

# 3. Copy your notes
cp -r /Users/user/Repository/sandy_knowledge/_notes/ ./_notes/

# 4. Push to GitHub
git add .
git commit -m "Add my notes"
git push

# 5. Enable GitHub Pages
# Settings → Pages → Source: main branch
```

**Done!** Your site is live at `https://<username>.github.io/<repo>/`

### 4. **Obsidian Digital Garden** (Netlify)

**Best for:** Netlify hosting, note-centric design

**Features:**
- ✅ Beautiful card-based design
- ✅ Wikilinks
- ✅ Graph view
- ✅ Dark mode
- ✅ Instant deploy

**Setup:**

```bash
# 1. Install Digital Garden plugin in Obsidian
# Settings → Community Plugins → Browse → "Digital Garden"

# 2. Configure in plugin settings:
# - GitHub repo: your-username/digital-garden
# - GitHub token: (create at github.com/settings/tokens)

# 3. In Obsidian, right-click any note
# Select "Publish to Digital Garden"

# 4. Connect to Netlify
# Visit: app.netlify.com
# "New site from Git" → Connect GitHub repo
# Deploy!
```

**Auto-publish:** Just click "Publish" in Obsidian!

### 5. **Hugo + Obsidian** (Fastest)

**Best for:** Speed, customization, blogs

**Features:**
- ✅ Blazing fast
- ✅ Many themes
- ✅ Blog support
- ✅ SEO optimized

**Setup:**

```bash
# 1. Install Hugo
brew install hugo

# 2. Create site
hugo new site my-obsidian-site
cd my-obsidian-site

# 3. Add theme (e.g., PaperMod)
git submodule add https://github.com/adityatelange/hugo-PaperMod.git themes/PaperMod

# 4. Configure (config.toml)
echo 'theme = "PaperMod"' >> config.toml

# 5. Link your vault
ln -s /Users/user/Repository/sandy_knowledge/content content

# 6. Convert wikilinks (use obsidian-to-hugo)
pip install obsidian-to-hugo
obsidian-to-hugo content/

# 7. Build and serve
hugo server -D

# 8. Deploy to Netlify/Vercel
# Just push to GitHub, connect repo in Netlify
```

### 6. **Gatsby + Obsidian** (React-based)

**Best for:** Developers, React fans, complex sites

**Setup:**

```bash
# 1. Use template
git clone https://github.com/hikerpig/foam-template-gatsby-kb.git
cd foam-template-gatsby-kb

# 2. Install dependencies
npm install

# 3. Copy notes
cp -r /Users/user/Repository/sandy_knowledge/* content/

# 4. Develop
npm run develop

# 5. Deploy to Netlify
npm run build
# Push to GitHub, connect in Netlify
```

## 📊 Comparison Table

| Solution | Difficulty | Features | Best For |
|----------|-----------|----------|----------|
| **Quartz** | ⭐⭐ | 🌟🌟🌟🌟🌟 | Graph view lovers |
| **MkDocs** | ⭐⭐ | 🌟🌟🌟🌟 | Documentation |
| **Jekyll Garden** | ⭐ | 🌟🌟🌟 | Quick setup |
| **Digital Garden** | ⭐ | 🌟🌟🌟🌟 | One-click publish |
| **Hugo** | ⭐⭐⭐ | 🌟🌟🌟🌟 | Speed & customization |
| **Gatsby** | ⭐⭐⭐⭐ | 🌟🌟🌟🌟🌟 | React developers |

## 🎯 Recommended Setup for Your Vault

### **Option A: Quartz (Recommended)** ⭐

**Why:** Best balance of features and ease

```bash
# 1. Install Quartz in your repo
cd /Users/user/Repository/sandy_knowledge
git clone https://github.com/jackyzha0/quartz.git quartz-publish
cd quartz-publish

# 2. Initialize
npx quartz create
# Choose: "Link an existing folder"
# Point to: ../

# 3. Configure (quartz.config.ts)
# Set site title, description, etc.

# 4. Build
npx quartz build --serve

# 5. Deploy
npx quartz sync --push
```

**Your site:** Live on GitHub Pages!

### **Option B: MkDocs (Documentation Style)**

Perfect if you want a structured docs site.

### **Option C: Digital Garden Plugin (Easiest)**

1-click publishing from Obsidian itself!

## 🚀 Deployment Platforms (All Free)

### GitHub Pages
- ✅ Free
- ✅ Custom domain
- ✅ 100GB bandwidth/month
- ✅ HTTPS included

**Setup:**
```bash
# In repo settings:
Settings → Pages → Source: gh-pages branch
```

### Netlify
- ✅ Free
- ✅ 100GB bandwidth
- ✅ Instant preview
- ✅ Custom domain

**Setup:**
```bash
# Connect GitHub repo at netlify.com
# Auto-deploys on git push
```

### Vercel
- ✅ Free
- ✅ Fast global CDN
- ✅ Instant deploys
- ✅ Custom domain

**Setup:**
```bash
# Import GitHub repo at vercel.com
# Configure build command
```

### Cloudflare Pages
- ✅ Free unlimited bandwidth
- ✅ Fastest CDN
- ✅ Custom domain

## 🔧 Workflow Integration

### Auto-Publish on Git Push

**With GitHub Actions:**

Create `.github/workflows/publish.yml`:

```yaml
name: Publish Site
on:
  push:
    branches: [master]
jobs:
  build-and-deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Quartz
      - name: Setup Node
        uses: actions/setup-node@v3
      - name: Build Quartz
        run: |
          cd quartz-publish
          npm ci
          npx quartz build
      
      - name: Deploy to GitHub Pages
        uses: peaceiris/actions-gh-pages@v3
        with:
          github_token: ${{ secrets.GITHUB_TOKEN }}
          publish_dir: ./quartz-publish/public
```

**Now:**
1. Edit notes in Obsidian
2. Git plugin auto-commits
3. GitHub Actions auto-publishes
4. Site updates automatically! 🎉

## 🎨 Customization

### Add Custom Domain

**GitHub Pages:**
```bash
# 1. Add CNAME file
echo "notes.yourdomain.com" > CNAME
git add CNAME
git commit -m "Add custom domain"
git push

# 2. Configure DNS
# Add CNAME record: notes → username.github.io
```

**Netlify/Vercel:**
Just add domain in dashboard (even easier!)

### Themes & Styling

Most solutions support custom CSS:

```css
/* custom.css */
:root {
  --primary-color: #6366f1;
  --background: #0f172a;
  --text: #e2e8f0;
}

body {
  font-family: 'Inter', sans-serif;
}
```

## 🔒 Privacy Considerations

### Private Notes

**Option 1: Use .gitignore**
```bash
# Don't publish private notes
echo "private/" >> .gitignore
```

**Option 2: Separate Repo**
```bash
# Create public-notes repo
# Only publish selected notes
```

**Option 3: Frontmatter Flag**
```yaml
---
published: false
---
```

Then filter in build script.

## 📱 Mobile App Access

Your published site works on mobile browsers, but for **app-like experience:**

### Progressive Web App (PWA)

Most solutions (Quartz, MkDocs) support PWA:

1. Readers can "Add to Home Screen"
2. Works offline
3. Fast loading
4. Native app feel

## 🔗 Integration with Your Current Setup

### With Git Plugin
```bash
# Your workflow:
1. Edit in Obsidian
2. Git plugin commits (every 5 min)
3. GitHub Actions builds site
4. Site updates automatically

# Zero manual work! 🎉
```

### With MCP Server
```bash
# AI can:
1. Create notes via MCP
2. Notes auto-commit via Git
3. Site auto-publishes
4. AI sees published site via REST API
```

### With REST API
```python
# Update note via API
vault.create_note("new-post.md", content)

# Git auto-commits
# Site auto-publishes

# Full automation loop! 🔄
```

## 🎓 Quick Start Checklist

- [ ] Choose solution (recommend: Quartz)
- [ ] Install dependencies
- [ ] Configure build
- [ ] Connect to GitHub
- [ ] Enable GitHub Pages
- [ ] Add custom domain (optional)
- [ ] Set up GitHub Actions for auto-deploy
- [ ] Test with sample notes
- [ ] Publish your full vault

## 💡 Pro Tips

1. **Start with Quartz** - Best all-around solution
2. **Use GitHub Actions** - Automate everything
3. **Combine with Git plugin** - Zero manual work
4. **Test locally first** - `npx quartz build --serve`
5. **Use custom domain** - More professional
6. **Enable analytics** - Track visitors (free with Plausible)

## 📚 Resources

### Official Guides
- [Quartz Documentation](https://quartz.jzhao.xyz)
- [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)
- [Jekyll Garden Setup](https://github.com/Jekyll-Garden/jekyll-garden.github.io)

### Example Sites
- [Quartz Demo](https://quartz.jzhao.xyz)
- [MkDocs Example](https://obsidian-publish.github.io)
- [Digital Garden](https://publish.obsidian.md/digitalgarden)

## 🔗 Related

- [[Setup Guide]] - Vault configuration
- [[Git Plugin Tutorial]] - Auto-commit setup
- [[REST API Usage Guide]] - Programmatic access

---

**Status:** Ready to publish!
**Cost:** $0/month forever 🎉
**Last Updated:** 2025-11-24
