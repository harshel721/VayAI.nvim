# VayAI.nvim 🤖

A lightweight Neovim plugin for interacting with Vayavya Labs' internal LLM API server. Get AI-powered code assistance directly in your editor!

![Neovim](https://img.shields.io/badge/NeoVim-%2357A143.svg?&style=for-the-badge&logo=neovim&logoColor=white)
![Lua](https://img.shields.io/badge/lua-%232C2D72.svg?style=for-the-badge&logo=lua&logoColor=white)

## ✨ Features

- 🤖 **Multiple LLM Models**: Support for gemma3, gpt-oss, deepseek-r1, llama3.3, qwen3-coder, and more
- 💬 **Ask Questions**: Get instant answers from AI
- 🔍 **Code Explanation**: Understand complex code with detailed AI explanations
- 💡 **Custom Queries**: Ask specific questions about selected code
- ⌨️ **Customizable Keybindings**: Set up shortcuts that work for you

## 📋 Requirements

- Neovim >= 0.8.0
- `curl` command-line tool (pre-installed on most systems)
- Access to Vayavya Labs LLM server
- Valid API key and SSL certificate

## 📦 Installation

### Step 1: Get API Credentials

#### 1.1 Get your API Key

1. Log into [Open WebUI](https://open-webui.vayavyalabs.com:3000)
2. Go to **Profile Icon** → **Settings** → **Account**
3. Copy your **API Key**

#### 1.2 Download SSL Certificate

Download the `combined_bundle.pem` file from your admin and save it to a secure location:
```bash
# Example location
mkdir -p ~/.config/nvim/certs
# Save combined_bundle.pem to ~/.config/nvim/certs/
```

#### 1.3 Install the Certificate

To avoid SSL errors, the certificate must be trusted by your operating system.

Run the following commands in your terminal:
```bash
sudo cp -v combined_bundle.pem /usr/local/share/ca-certificates/DigiCertCA.crt
sudo update-ca-certificates
```

**Note:** Make sure to run these commands from the directory where `combined_bundle.pem` is located, or provide the full path.

### Step 2: Set Environment Variables

Add these to your shell configuration file (`~/.bashrc`, `~/.zshrc`, or `~/.profile`):
```bash
# VayAI Configuration
export LLM_API_KEY="sk-your-actual-api-key-here"
export LLM_API_BASE="https://open-webui.vayavyalabs.com:3000"
export LLM_CA_BUNDLE="$HOME/.config/nvim/certs/combined_bundle.pem"
```

**Important:** 
- Replace `sk-your-actual-api-key-here` with your actual API key from Step 1.1
- Use the absolute path to your `.pem` file
- The `$HOME` variable will expand to your home directory

Then reload your shell:
```bash
source ~/.bashrc  # or ~/.zshrc
```

### Step 3: Install with Lazy.nvim

Create or edit `~/.config/nvim/lua/plugins/vayai.lua`:
```lua
return {
  'harshel721/vayai.nvim',
  config = function()
    require('vayai').setup()
  end
}
```

Then restart Neovim and run:
```vim
:Lazy install
```

### Step 4: Verify Installation

Test the connection:
```vim
:LLMTest
```

You should see: **"✓ Connection successful! API is reachable."**

If you see an error, check the troubleshooting section below.

## 🚀 Usage

### Available Commands

| Command | Description |
|---------|-------------|
| `:LLMAsk [question]` | Ask the LLM a question |
| `:LLMExplain` | Explain selected code (visual mode) |
| `:LLMQuery [question]` | Ask custom question about selected code (visual mode) |
| `:LLMModel <model>` | Switch to a different model |
| `:LLMModels` | List all available models |
| `:LLMTest` | Test API connection |
| `:LLMCancel` | Cancel current request |

### Default Keybindings

**Normal Mode:**
- `<leader>la` - Ask a question
- `<leader>lm` - List available models

**Visual Mode** (select code first):
- `<leader>le` - Explain selected code
- `<leader>lq` - Ask custom question about code

### Response Window Controls

When a response window opens:
- **`y`** - Copy response to clipboard
- **`q`** or **`<Esc>`** - Close window

## ⚙️ Configuration

### Basic Configuration
```lua
require('vayai').setup({
  -- API settings (optional if using environment variables)
  api_key = "your-api-key",
  api_base = "https://open-webui.vayavyalabs.com:3000",
  ca_bundle_path = "~/.config/nvim/certs/combined_bundle.pem",
  
  -- Default model
  default_model = "deepseek-r1:latest",
  
  -- API parameters
  temperature = 0.7,
  max_tokens = 1000,
  timeout = 90,
})
```

### Disable Default Keymaps
```lua
require('vayai').setup({
  keymaps = false  -- Disable all default keymaps
})

-- Then set your own
vim.keymap.set('n', '<leader>ai', ':LLMAsk<CR>')
vim.keymap.set('v', '<leader>ae', ':LLMExplain<CR>')
```

### UI Customization
```lua
require('vayai').setup({
  window = {
    width = 100,
    height = 30,
    border = "rounded"  -- Options: rounded, single, double, solid, shadow
  }
})
```

### Available Models
```lua
require('vayai').setup({
  models = {
    "gemma3:4b",
    "gpt-oss:120b",
    "deepseek-r1:latest",
    "gemma3:27b",
    "llama3.3:70b",
    "qwen3-coder:30b"
  },
  default_model = "deepseek-r1:latest"
})
```

## 🤖 Available Models

| Model | Best For | Speed |
|-------|----------|-------|
| `gemma3:4b` | Quick questions, fast responses | ⚡⚡⚡ |
| `gemma3:27b` | Balanced performance | ⚡⚡ |
| `qwen3-coder:30b` | Code-specific tasks | ⚡⚡ |
| `deepseek-r1:latest` | Deep reasoning tasks (default) | ⚡ |
| `llama3.3:70b` | Complex reasoning | ⚡ |
| `gpt-oss:120b` | Most powerful | 🐌 |

**Tip:** Start with `gemma3:4b` for speed, switch to `llama3.3:70b` or `deepseek-r1:latest` for complex tasks.

## 🐛 Troubleshooting

### "API key not set" Warning

**Problem:** Environment variable not loaded.

**Solution:**
```bash
# Check if set
echo $LLM_API_KEY

# If empty, add to shell config and reload
source ~/.bashrc
```

### "CA bundle file not found"

**Problem:** Wrong path or file doesn't exist.

**Solution:**
```bash
# Check if file exists
ls -la ~/.config/nvim/certs/combined_bundle.pem

# Verify environment variable
echo $LLM_CA_BUNDLE

# Use absolute path, not relative
export LLM_CA_BUNDLE="$HOME/.config/nvim/certs/combined_bundle.pem"
```

### SSL/Certificate Errors

**Problem:** Certificate not trusted by system.

**Solution:**
```bash
# Install certificate system-wide
sudo cp -v combined_bundle.pem /usr/local/share/ca-certificates/DigiCertCA.crt
sudo update-ca-certificates

# Verify
:LLMTest
```

## 🔒 Security Notes

- Use environment variables for credentials
- Don't share your `combined_bundle.pem` file
```bash
# Set proper permissions on certificate
chmod 600 ~/.config/nvim/certs/combined_bundle.pem
```

## Acknowledgments

- Vayavya Labs for providing the LLM infrastructure

---
