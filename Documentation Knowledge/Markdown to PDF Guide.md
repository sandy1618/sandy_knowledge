---
title: Markdown to PDF Export Guide
tags: [documentation, pdf, export, pandoc, markdown]
created: 2025-11-24
---

# Markdown to PDF Export Guide

Complete guide for converting Markdown documentation to professional PDF files using Pandoc.

## 🎯 Overview

This guide explains how to merge multiple Markdown files into a single, professional PDF document suitable for sharing with clients, teams, or stakeholders.

## 📋 Prerequisites

### Required Tools

#### 1. **Pandoc** - Universal Document Converter
- Converts between 40+ document formats
- Handles Markdown, HTML, LaTeX, PDF, DOCX, etc.

#### 2. **PDF Engine** - Rendering Backend
Choose one:
- **pdflatex** (most common)
- **xelatex** (better Unicode support)
- **tectonic** (modern, faster)
- **wkhtmltopdf** (HTML-based)

---

## 🔧 Installation

### macOS

**Option A: Using Homebrew (Recommended)**
```bash
# Install Pandoc
brew install pandoc

# Install BasicTeX (lightweight TeX distribution)
brew install basictex

# Add TeX binaries to PATH
export PATH="/Library/TeX/texbin:$PATH"
# Add to ~/.zshrc or ~/.bash_profile for permanent:
echo 'export PATH="/Library/TeX/texbin:$PATH"' >> ~/.zshrc

# Update TeX package manager
sudo tlmgr update --self

# Install required LaTeX packages
sudo tlmgr install latexmk collection-fontsrecommended
```

**Option B: Full TeXLive**
```bash
brew install pandoc
brew install --cask mactex  # Full TeX distribution (~4GB)
```

**Option C: Lightweight (Tectonic)**
```bash
brew install pandoc tectonic
```

**Verify Installation:**
```bash
pandoc --version
pdflatex --version  # or: tectonic --version
```

---

### Linux (Ubuntu/Debian)

```bash
# Update package list
sudo apt update

# Install Pandoc and LaTeX
sudo apt install pandoc texlive-latex-extra texlive-fonts-recommended

# Verify
pandoc --version
pdflatex --version
```

**Lightweight alternative:**
```bash
sudo apt install pandoc
cargo install tectonic  # Requires Rust
```

---

### Windows

**Option A: Using Chocolatey (Recommended)**
```powershell
# Install Chocolatey if not installed:
# Follow: https://chocolatey.org/install

# Install packages
choco install pandoc miktex

# Open MiKTeX Console once to configure auto-install
```

**Option B: Manual Installation**
1. Download Pandoc: https://pandoc.org/installing.html
2. Download MiKTeX: https://miktex.org/download
3. Add to PATH via System Environment Variables

**Verify:**
```powershell
pandoc --version
pdflatex --version
```

---

## 📝 Basic Usage

### Single File Conversion

```bash
# Simple conversion
pandoc input.md -o output.pdf

# With specific PDF engine
pandoc input.md -o output.pdf --pdf-engine=pdflatex

# With table of contents
pandoc input.md -o output.pdf --toc

# With numbered sections
pandoc input.md -o output.pdf --number-sections
```

### Multiple Files Merge

**Method 1: Concatenate then Convert**
```bash
# Merge files in order
cat file1.md file2.md file3.md > combined.md

# Convert to PDF
pandoc combined.md -o output.pdf --pdf-engine=pdflatex
```

**Method 2: Direct Multi-file**
```bash
# Pandoc can take multiple inputs
pandoc file1.md file2.md file3.md -o output.pdf
```

---

## 🚀 Automation Script

### Create Export Script

Create `scripts/export_docs_to_pdf.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

# Default values
OUTPUT="final_docs.pdf"
PDF_ENGINE="${PDF_ENGINE:-pdflatex}"
INPUT_FILES=()

# Function to display usage
usage() {
  cat << EOF
Usage: $0 [OPTIONS] <markdown-files...>

Convert and merge multiple Markdown files into a single PDF.

OPTIONS:
  -o, --output FILE       Output PDF path (default: final_docs.pdf)
  -e, --pdf-engine ENGINE PDF engine to use (default: pdflatex)
                          Options: pdflatex, xelatex, tectonic, wkhtmltopdf
  -h, --help             Display this help message

EXAMPLES:
  $0 -o docs.pdf chapter1.md chapter2.md chapter3.md
  $0 --pdf-engine=tectonic -o guide.pdf *.md
  PDF_ENGINE=xelatex $0 -o output.pdf intro.md main.md

EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -o|--output)
      OUTPUT="$2"
      shift 2
      ;;
    -e|--pdf-engine)
      PDF_ENGINE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Error: Unknown option: $1" >&2
      usage
      ;;
    *)
      INPUT_FILES+=("$1")
      shift
      ;;
  esac
done

# Validate inputs
if [[ ${#INPUT_FILES[@]} -eq 0 ]]; then
  echo "Error: No input files specified" >&2
  usage
fi

# Check if tools exist
if ! command -v pandoc &> /dev/null; then
  echo "Error: pandoc not found. Please install pandoc." >&2
  exit 1
fi

if ! command -v "$PDF_ENGINE" &> /dev/null; then
  echo "Error: PDF engine '$PDF_ENGINE' not found." >&2
  echo "Install it or set PDF_ENGINE to a different engine." >&2
  exit 1
fi

# Create temporary combined file
TEMP_FILE=$(mktemp /tmp/pandoc_combined_XXXXXX.md)
trap "rm -f $TEMP_FILE" EXIT

echo "Merging ${#INPUT_FILES[@]} file(s)..."
for file in "${INPUT_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    echo "Error: File not found: $file" >&2
    exit 1
  fi
  cat "$file" >> "$TEMP_FILE"
  echo -e "\n\n---\n\n" >> "$TEMP_FILE"  # Page break between files
done

# Convert to PDF
echo "Converting to PDF using $PDF_ENGINE..."
pandoc "$TEMP_FILE" \
  -o "$OUTPUT" \
  --pdf-engine="$PDF_ENGINE" \
  --toc \
  --number-sections \
  -V geometry:margin=1in \
  -V linkcolor:blue \
  -V urlcolor:blue

echo "✅ PDF created successfully: $OUTPUT"
```

**Make executable:**
```bash
chmod +x scripts/export_docs_to_pdf.sh
```

---

## 📚 Usage Examples

### Example 1: Simple Documentation Export

```bash
# Export single file
./scripts/export_docs_to_pdf.sh -o guide.pdf README.md

# Export multiple files
./scripts/export_docs_to_pdf.sh \
  -o complete_guide.pdf \
  intro.md \
  setup.md \
  usage.md \
  api.md
```

### Example 2: Obsidian Vault Export

```bash
# Export specific notes from your vault
./scripts/export_docs_to_pdf.sh \
  -o obsidian_guide.pdf \
  "Obsidian Knowledge/Setup Guide.md" \
  "Obsidian Knowledge/Git Plugin Tutorial.md" \
  "Obsidian Knowledge/Keyboard Shortcuts.md"
```

### Example 3: Custom PDF Engine

```bash
# Use Tectonic (faster, better Unicode)
./scripts/export_docs_to_pdf.sh \
  -e tectonic \
  -o output.pdf \
  docs/*.md

# Use XeLaTeX (best for non-Latin scripts)
./scripts/export_docs_to_pdf.sh \
  -e xelatex \
  -o chinese_docs.pdf \
  chinese_guide.md
```

### Example 4: Project Documentation

```bash
# Export all markdown files in order
./scripts/export_docs_to_pdf.sh \
  -o project_docs.pdf \
  docs/01-overview.md \
  docs/02-architecture.md \
  docs/03-components.md \
  docs/04-api.md \
  docs/05-deployment.md
```

---

## 🎨 Advanced Customization

### Custom Pandoc Options

```bash
pandoc input.md -o output.pdf \
  --pdf-engine=pdflatex \
  --toc \
  --toc-depth=3 \
  --number-sections \
  --highlight-style=tango \
  -V geometry:margin=1in \
  -V fontsize=12pt \
  -V linkcolor:blue \
  -V documentclass=report \
  --metadata title="My Documentation" \
  --metadata author="Your Name" \
  --metadata date="2025-11-24"
```

### Custom CSS (for HTML-based engines)

```bash
pandoc input.md -o output.pdf \
  --pdf-engine=wkhtmltopdf \
  --css=custom.css
```

**custom.css:**
```css
body {
  font-family: 'Georgia', serif;
  max-width: 800px;
  margin: 0 auto;
  line-height: 1.6;
}

h1 {
  color: #2c3e50;
  border-bottom: 2px solid #3498db;
}

code {
  background: #f4f4f4;
  padding: 2px 5px;
  border-radius: 3px;
}
```

### LaTeX Template

Create `template.tex`:
```latex
\documentclass[12pt]{article}
\usepackage{geometry}
\geometry{margin=1in}
\usepackage{hyperref}
\hypersetup{
  colorlinks=true,
  linkcolor=blue,
  urlcolor=blue
}
\title{$title$}
\author{$author$}
\date{$date$}

\begin{document}
\maketitle
\tableofcontents
\newpage

$body$

\end{document}
```

**Use template:**
```bash
pandoc input.md -o output.pdf --template=template.tex
```

---

## 🐛 Troubleshooting

### Common Issues

#### 1. `pdflatex not found`

**Symptoms:**
```
pandoc: pdflatex not found. Please select a different --pdf-engine
```

**Solutions:**
```bash
# macOS
export PATH="/Library/TeX/texbin:$PATH"
# Add to ~/.zshrc for permanent fix

# Linux
sudo apt install texlive-latex-extra

# Windows
# Add MiKTeX bin directory to PATH
```

#### 2. Unicode Character Errors

**Symptoms:**
```
! Package inputenc Error: Unicode character ├ (U+251C) not set up for use with LaTeX.
```

**Solutions:**

**Option A: Use XeLaTeX**
```bash
pandoc input.md -o output.pdf --pdf-engine=xelatex
```

**Option B: Replace special characters**
```bash
# Replace box-drawing characters
sed -i 's/├/+/g' input.md
sed -i 's/└/+/g' input.md
sed -i 's/│/|/g' input.md
sed -i 's/─/-/g' input.md
```

**Option C: Use Tectonic**
```bash
pandoc input.md -o output.pdf --pdf-engine=tectonic
```

#### 3. Missing LaTeX Packages

**Symptoms:**
```
! LaTeX Error: File `package.sty' not found.
```

**Solutions:**
```bash
# macOS
sudo tlmgr install <package-name>
sudo tlmgr install collection-fontsrecommended

# Linux
sudo apt install texlive-latex-extra texlive-fonts-recommended

# Windows
# Open MiKTeX Console → Updates → Update now
# Enable: "Install missing packages on-the-fly"
```

#### 4. Images Not Embedding

**Symptoms:**
Images missing or errors about file paths

**Solutions:**
```bash
# Use relative paths
![Image](./images/diagram.png)

# Or absolute paths
![Image](/absolute/path/to/image.png)

# Run pandoc from project root
cd /path/to/project
pandoc docs/file.md -o output.pdf
```

#### 5. Large File / Memory Issues

**Symptoms:**
Pandoc crashes or runs out of memory

**Solutions:**
```bash
# Split into smaller PDFs, then merge
pdftk part1.pdf part2.pdf cat output final.pdf

# Or use wkhtmltopdf (uses less memory)
pandoc input.md -o output.pdf --pdf-engine=wkhtmltopdf
```

---

## 📊 Comparison of PDF Engines

| Engine | Speed | Unicode | Quality | Size | Best For |
|--------|-------|---------|---------|------|----------|
| **pdflatex** | ⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ | Small | English docs |
| **xelatex** | ⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Medium | Multi-language |
| **tectonic** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Small | Modern docs |
| **wkhtmltopdf** | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Large | HTML-heavy |

---

## 🔄 Workflow Integration

### Git Hook (Auto-export on commit)

Create `.git/hooks/pre-commit`:
```bash
#!/bin/bash

# Auto-generate PDF from docs
if git diff --cached --name-only | grep -q "docs/.*\.md"; then
  echo "Generating PDF from documentation..."
  ./scripts/export_docs_to_pdf.sh -o docs/documentation.pdf docs/*.md
  git add docs/documentation.pdf
fi
```

```bash
chmod +x .git/hooks/pre-commit
```

### GitHub Actions (CI/CD)

Create `.github/workflows/build-pdf.yml`:
```yaml
name: Build Documentation PDF

on:
  push:
    branches: [master]
    paths:
      - 'docs/**/*.md'

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Install Pandoc
        run: |
          sudo apt update
          sudo apt install -y pandoc texlive-latex-extra
      
      - name: Build PDF
        run: |
          chmod +x scripts/export_docs_to_pdf.sh
          ./scripts/export_docs_to_pdf.sh -o documentation.pdf docs/*.md
      
      - name: Upload PDF
        uses: actions/upload-artifact@v3
        with:
          name: documentation
          path: documentation.pdf
      
      - name: Create Release
        uses: softprops/action-gh-release@v1
        if: startsWith(github.ref, 'refs/tags/')
        with:
          files: documentation.pdf
```

### Makefile

Create `Makefile`:
```makefile
.PHONY: pdf clean help

DOCS_DIR := docs
OUTPUT := documentation.pdf
MARKDOWN_FILES := $(wildcard $(DOCS_DIR)/*.md)

pdf: $(OUTPUT)

$(OUTPUT): $(MARKDOWN_FILES)
	@echo "Building PDF from Markdown files..."
	./scripts/export_docs_to_pdf.sh -o $@ $(MARKDOWN_FILES)
	@echo "✅ PDF created: $@"

clean:
	rm -f $(OUTPUT)

help:
	@echo "Available targets:"
	@echo "  pdf   - Build documentation PDF"
	@echo "  clean - Remove generated PDF"
	@echo "  help  - Show this help message"
```

**Usage:**
```bash
make pdf      # Build PDF
make clean    # Remove PDF
```

---

## 💡 Best Practices

### 1. **Organize Files Logically**
```
docs/
├── 01-introduction.md
├── 02-setup.md
├── 03-usage.md
├── 04-api-reference.md
└── 05-troubleshooting.md
```

### 2. **Use Frontmatter for Metadata**
```yaml
---
title: "Complete Documentation"
author: "Your Name"
date: "2025-11-24"
toc: true
numbersections: true
---
```

### 3. **Consistent Heading Levels**
```markdown
# Chapter (Level 1)
## Section (Level 2)
### Subsection (Level 3)
```

### 4. **Optimize Images**
```bash
# Compress images before including
mogrify -resize 1200x -quality 85 images/*.png
```

### 5. **Test Output Regularly**
```bash
# Quick preview during development
pandoc draft.md -o preview.pdf && open preview.pdf
```

---

## 📋 Quick Reference

### Essential Commands

```bash
# Basic conversion
pandoc input.md -o output.pdf

# With TOC and numbering
pandoc input.md -o output.pdf --toc --number-sections

# Multiple files
pandoc *.md -o output.pdf

# Custom engine
pandoc input.md -o output.pdf --pdf-engine=xelatex

# With metadata
pandoc input.md -o output.pdf --metadata title="My Doc"

# Custom margins
pandoc input.md -o output.pdf -V geometry:margin=1.5in
```

---

## 🔗 Related Documentation

- [[Git Submodules]] - Version control for documentation
- [[Setup Guide]] - Vault organization
- [[Free Publishing Options]] - Web publishing alternatives

---

## 📚 Resources

- [Pandoc Official Documentation](https://pandoc.org/MANUAL.html)
- [Pandoc PDF Options](https://pandoc.org/MANUAL.html#options-for-pdf-engines)
- [LaTeX Packages](https://ctan.org/)
- [Tectonic Documentation](https://tectonic-typesetting.github.io/)

---

**Last Updated:** 2025-11-24
**Tested On:** macOS Sequoia (Apple Silicon), Ubuntu 22.04, Windows 11
**Pandoc Version:** 3.8.2+
