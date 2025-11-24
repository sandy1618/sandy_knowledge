---
title: Obsidian REST API Usage Guide
tags: [obsidian, api, integration]
created: 2025-11-24
---

# Obsidian REST API Usage Guide

This vault has the Local REST API plugin configured for programmatic access.

## 🔑 Configuration

**Base URL:** `http://localhost:27123`
**API Key:** `acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809`

⚠️ **Important:** Obsidian must be running for the API to work!

## 📡 Basic Operations

### Authentication

All requests require the API key in the `Authorization` header:

```bash
Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809
```

### 1. List All Files

```bash
curl -H "Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809" \
  http://localhost:27123/vault/
```

**Response:** JSON array of all files in the vault

### 2. Read a Note

```bash
curl -H "Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809" \
  http://localhost:27123/vault/Welcome.md
```

**Response:** Raw markdown content of the note

### 3. Create/Update a Note

```bash
curl -X PUT \
  -H "Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809" \
  -H "Content-Type: text/markdown" \
  -d "# My New Note

This is the content of my note." \
  http://localhost:27123/vault/my-new-note.md
```

### 4. Search Notes

```bash
curl -H "Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809" \
  "http://localhost:27123/search/simple/?query=knowledge"
```

**Response:** Array of matching notes with context

### 5. Delete a Note

```bash
curl -X DELETE \
  -H "Authorization: Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809" \
  http://localhost:27123/vault/note-to-delete.md
```

## 🐍 Python Client

```python
import requests

class ObsidianVault:
    def __init__(self):
        self.base_url = "http://localhost:27123"
        self.headers = {
            "Authorization": "Bearer acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809"
        }
    
    def list_notes(self):
        """Get all files in vault"""
        response = requests.get(f"{self.base_url}/vault/", headers=self.headers)
        return response.json()
    
    def read_note(self, path):
        """Read a specific note"""
        response = requests.get(f"{self.base_url}/vault/{path}", headers=self.headers)
        return response.text
    
    def create_note(self, path, content):
        """Create or update a note"""
        response = requests.put(
            f"{self.base_url}/vault/{path}",
            headers={**self.headers, "Content-Type": "text/markdown"},
            data=content
        )
        return response.status_code == 200
    
    def search(self, query):
        """Search notes by text"""
        response = requests.get(
            f"{self.base_url}/search/simple/",
            headers=self.headers,
            params={"query": query}
        )
        return response.json()
    
    def delete_note(self, path):
        """Delete a note"""
        response = requests.delete(
            f"{self.base_url}/vault/{path}",
            headers=self.headers
        )
        return response.status_code == 200

# Usage Example
vault = ObsidianVault()

# List all notes
notes = vault.list_notes()
print(f"Found {len(notes)} notes")

# Read a note
content = vault.read_note("Welcome.md")
print(content)

# Create a new note
vault.create_note("daily/2025-11-24.md", """---
title: Daily Note
date: 2025-11-24
---

# Today's Tasks

- [ ] Review notes
- [ ] Add new knowledge
""")

# Search for notes
results = vault.search("obsidian")
for result in results:
    print(f"Found in: {result['filename']}")
```

## 📦 Node.js/TypeScript Client

```typescript
class ObsidianVault {
  private baseUrl = "http://localhost:27123";
  private apiKey = "acd407fe0bb3a9493e9a3975dcb0d6e4cef4dc7117f38ce106776911c5033809";

  private get headers() {
    return { Authorization: `Bearer ${this.apiKey}` };
  }

  async listNotes(): Promise<string[]> {
    const response = await fetch(`${this.baseUrl}/vault/`, {
      headers: this.headers
    });
    return response.json();
  }

  async readNote(path: string): Promise<string> {
    const response = await fetch(`${this.baseUrl}/vault/${path}`, {
      headers: this.headers
    });
    return response.text();
  }

  async createNote(path: string, content: string): Promise<boolean> {
    const response = await fetch(`${this.baseUrl}/vault/${path}`, {
      method: "PUT",
      headers: {
        ...this.headers,
        "Content-Type": "text/markdown"
      },
      body: content
    });
    return response.ok;
  }

  async search(query: string): Promise<any[]> {
    const response = await fetch(
      `${this.baseUrl}/search/simple/?query=${encodeURIComponent(query)}`,
      { headers: this.headers }
    );
    return response.json();
  }

  async deleteNote(path: string): Promise<boolean> {
    const response = await fetch(`${this.baseUrl}/vault/${path}`, {
      method: "DELETE",
      headers: this.headers
    });
    return response.ok;
  }
}

// Usage
const vault = new ObsidianVault();

// List notes
const notes = await vault.listNotes();
console.log(`Found ${notes.length} notes`);

// Create a note
await vault.createNote("test.md", "# Test Note\n\nContent here");

// Search
const results = await vault.search("knowledge");
console.log(results);
```

## 🔒 Security Considerations

1. **API Key Security**
   - Never commit API key to public repositories
   - Use environment variables in production
   - Rotate key if exposed

2. **Local Access Only**
   - API only accessible on localhost by default
   - For remote access, set up SSH tunnel or VPN

3. **Backup API Key**
   - Store securely in password manager
   - Regenerate in Obsidian settings if lost

## 🐛 Troubleshooting

### Connection Refused
- ✅ Check if Obsidian is running
- ✅ Verify plugin is enabled in Obsidian
- ✅ Check port (default: 27123)

### Unauthorized Error
- ✅ Verify API key is correct
- ✅ Check Authorization header format
- ✅ Regenerate API key in plugin settings

### CORS Issues (Web Apps)
- Enable CORS in plugin settings
- Or use backend proxy

## 📚 Related

- [[Setup Guide]] - Overall vault configuration
- [[MCP Integration Guide]] - AI agent access
- [[Git Plugin Tutorial]] - Version control integration
