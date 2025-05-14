# 🚀 suda.nvim

Neovim plugin for seamless sudo file editing with permissions preservation.  
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- 🔄 Automatic sudo detection for protected files
- 📝 Edit files with `sudo://` protocol
- 🔒 Preserves original permissions/ownership
- 💾 Save with regular `:w` command
- 🛡️ Atomic writes with temp file safety
- 🖥️ Supports Linux/macOS/\*nix systems

## Installation

Using lazy.nvim:

```lua
{
  'masajinobe-ef/suda.nvim',
  dependencies = { 'nvim-lua/plenary.nvim' },
  config = function()
    require('suda').setup {}
  end,
}
```
