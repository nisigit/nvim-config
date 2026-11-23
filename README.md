# nvim-config

My personal Neovim configuration, based on [kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim).
It is a single `init.lua` plus extra plugins in `lua/custom/plugins/`, so it is easy to read and change.

## Requirements

- Neovim stable (or nightly) — `:version` should be recent
- `git`, `make`, `unzip`, a C compiler
- [ripgrep](https://github.com/BurntSushi/ripgrep), [fd](https://github.com/sharkdp/fd), [tree-sitter CLI](https://github.com/tree-sitter/tree-sitter)
- A clipboard tool (`xclip`/`xsel`/`win32yank` — macOS has it built in)
- Optional: a [Nerd Font](https://www.nerdfonts.com/) (icons are on by default via `vim.g.have_nerd_font`)
- Optional language toolchains: Go, Python, Node/TypeScript, Lua

Language servers, formatters and linters are installed automatically by **Mason**
(`gopls`, `pyright`, `ruff`, `ts_ls`, `eslint`, `jsonls`, `cssls`, `emmet_language_server`,
`gofumpt`, `goimports`, `prettier`, `stylua`, ...).

## Install on a new machine

macOS / Linux:

```sh
# Back up an existing config first, if you have one.
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null

git clone https://github.com/nisigit/nvim-config.git ~/.config/nvim
nvim
```

Windows (PowerShell):

```powershell
git clone https://github.com/nisigit/nvim-config.git "$env:LOCALAPPDATA\nvim"
```

On first start Neovim installs the pinned plugins from `nvim-pack-lock.json`
and Mason downloads the tools. Let it finish, then restart Neovim.

## Layout

```
init.lua                 -- options, keymaps, core plugins, LSP, formatting
lua/custom/plugins/      -- my extra plugins
  agent.lua              -- Claude Code integration + git branch diffs
  explorer.lua           -- neo-tree file/buffer explorers
  lazygit.lua            -- lazygit in a floating window
  markdown.lua           -- in-buffer markdown rendering
nvim-pack-lock.json      -- pinned plugin revisions
```

## Handy keymaps

Leader is `<Space>`.

| Keys | Action |
| --- | --- |
| `<leader>e` | file explorer (follows current file) |
| `<leader>ge` | explorer showing only git-changed files |
| `<leader>be` | open buffers |
| `<leader>bd` | close buffer, keep layout |
| `<leader>gg` | lazygit float |
| `<leader>gd` / `<leader>gq` | branch diff / close diff |
| `<leader>a` | send selection to Claude Code |
| `<leader>ab` / `<leader>ad` | agent: add buffer / accept diff |
| `<leader>tm` | toggle markdown rendering |
| `<leader>th` | toggle inlay hints |

Press `<Space>` and wait for which-key to list everything.

## Syncing between machines

This repository is the source of truth. Pull before you start editing on a
machine, and push when you are done:

```sh
git -C ~/.config/nvim pull --rebase
# ...edit config...
git -C ~/.config/nvim add -A
git -C ~/.config/nvim commit -m "describe the change"
git -C ~/.config/nvim push
```

Commit `nvim-pack-lock.json` whenever a plugin update changes it, so every
machine runs the same plugin revisions.

## Updating

```sh
nvim --headless "+packupdate" +qa     # update plugins
git -C ~/.config/nvim diff            # review, then commit nvim-pack-lock.json
```

To pull in upstream kickstart changes:

```sh
git fetch upstream
git merge upstream/master
```

(`upstream` points at `nvim-lua/kickstart.nvim`.)
