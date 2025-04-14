# 🚀 sudo.nvim

A Neovim plugin to read/write files with `sudo` privileges seamlessly.
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

## Features

- 📖 Read protected files via `:SudaRead`
- 📝 Write to protected files via `:SudaWrite`
- 🧠 Smart edit detection for unwritable files
- 🔒 Safe temp file handling
- ⚙️ Simple setup with configurable options

## Installation

Using lazy.nvim:
{
'masajinobe-ef/sudo.nvim',
config = function()
require('sudo').setup({
smart_edit = true,
})
end
}

Using packer.nvim:
use({
'masajinobe-ef/sudo.nvim',
config = function()
require('sudo').setup()
end
})

## Usage

### Commands

:SudaRead [file] - Open file with sudo privileges
:SudaWrite [file] - Write file with sudo privileges

### Examples

:SudaRead /etc/hosts
:SudaWrite /etc/nginx/nginx.conf
:SudaRead %

## Configuration

### Setup Options

require('sudo').setup({ smart_edit = false })

### Global Variables

let g:suda#prompt = 'Admin password: '
let g:suda#noninteractive = 0

## Smart Edit

When enabled:
nvim /etc/protected_file.conf
[Prompt] Read-only file. Edit with sudo?
• Yes
• No

## Windows Support

Requires gsudo/mattn/sudo. Verify with:
:echo executable('sudo')

## Implementation

1. Reading: Creates temp file via `sudo cat`
2. Writing: Copies temp file via `sudo cp`
3. Preserves original permissions

## License

MIT © masajinobe-ef
