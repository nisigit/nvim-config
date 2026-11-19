-- File explorers, set up to review the work of an agent in another cmux pane.
--
--   <leader>e   project tree (neo-tree), follows the current file
--   <leader>ge  tree of only the files git sees as changed: what the agent touched
--   <leader>be  open buffers
--   -           edit the current file's directory as a buffer (oil)
--   <leader>bd  close the current file but keep nvim and the layout open
--
-- Inside the tree: l/<cr> open, h collapse, P preview, s/S split, a/d/r/m add/delete/rename/move,
-- H toggle hidden, / filter, < > switch tree, ? all keys.
-- Added here: Y copy relative path, D (changed-files tree) diff the file,
-- <leader>as send it to Claude
-- (or select several and press <leader>a).

local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add({
  { src = gh 'nvim-neo-tree/neo-tree.nvim', version = vim.version.range '*' },
  gh 'nvim-lua/plenary.nvim',
  gh 'MunifTanjim/nui.nvim',
  gh 'stevearc/oil.nvim',
}, { confirm = false })

-- [[ Project tree ]]
local function node_path(state) return state.tree:get_node():get_id() end

require('neo-tree').setup {
  close_if_last_window = true,
  sources = { 'filesystem', 'git_status', 'buffers' },
  source_selector = { winbar = true },
  window = {
    -- nvim shares the screen with the Claude pane, so keep the sidebar narrow.
    width = 32,
    mappings = {
      -- neo-tree binds <space> to fold by default, which would swallow <leader>.
      ['<space>'] = 'none',
      -- LazyVim-style: l opens a folder or file, h collapses the folder.
      ['l'] = 'open',
      ['h'] = 'close_node',
      ['Y'] = function(state)
        local path = vim.fn.fnamemodify(node_path(state), ':.')
        vim.fn.setreg('+', path)
        vim.notify('Copied ' .. path)
      end,
    },
  },
  filesystem = {
    follow_current_file = { enabled = true },
    -- Show files the agent creates or deletes without a manual refresh.
    use_libuv_file_watcher = true,
    group_empty_dirs = true,
    -- Directories open in oil instead, so `nvim .` and `:e src/` go there.
    hijack_netrw_behavior = 'disabled',
    filtered_items = {
      hide_dotfiles = false,
      hide_gitignored = true,
      never_show = { '.DS_Store' },
    },
  },
  git_status = {
    group_empty_dirs = true,
    window = {
      mappings = {
        ['D'] = function(state) vim.cmd('DiffviewOpen -- ' .. vim.fn.fnameescape(node_path(state))) end,
      },
    },
  },
}

-- Reveal only works for real files. From an oil buffer (`oil:///...`) neo-tree
-- reads the path as outside the cwd and asks to change directory every time.
-- follow_current_file implies reveal unless it is explicitly false, which the
-- :Neotree command cannot express, hence the Lua API.
local function toggle_file_tree()
  local is_file = vim.bo.buftype == '' and vim.uv.fs_stat(vim.api.nvim_buf_get_name(0)) ~= nil
  require('neo-tree.command').execute { toggle = true, source = 'filesystem', position = 'left', reveal = is_file }
end

vim.keymap.set('n', '<leader>e', toggle_file_tree, { desc = 'File [E]xplorer' })
vim.keymap.set('n', '<leader>ge', '<cmd>Neotree toggle git_status left<cr>', { desc = '[G]it: changed files [e]xplorer' })
vim.keymap.set('n', '<leader>be', '<cmd>Neotree toggle buffers left<cr>', { desc = '[B]uffer [e]xplorer' })

-- The file watcher only covers the filesystem tree. Re-run git status when you
-- come back from the Claude pane so the changed-files tree stays current.
vim.api.nvim_create_autocmd('FocusGained', {
  group = vim.api.nvim_create_augroup('explorer-git-refresh', { clear = true }),
  callback = function() pcall(require('neo-tree.sources.manager').refresh, 'git_status') end,
})

-- [[ Directory as a buffer ]]
-- Rename, move, create and delete files by editing text, then :w to apply.
require('oil').setup {
  default_file_explorer = true,
  watch_for_changes = true,
  view_options = { show_hidden = true },
  keymaps = { ['q'] = 'actions.close' },
}

vim.keymap.set('n', '-', '<cmd>Oil<cr>', { desc = 'Open parent directory' })

-- [[ Close a file without closing nvim ]]
-- :q and :bd close the window. When that window is the only one beside the tree,
-- close_if_last_window then quits nvim. mini.bufremove deletes the buffer but
-- keeps the window, showing the previous buffer (or an empty one) in it.
require('mini.bufremove').setup()
vim.keymap.set('n', '<leader>bd', function() require('mini.bufremove').delete() end, { desc = '[B]uffer [d]elete' })
vim.keymap.set('n', '<leader>bD', function() require('mini.bufremove').delete(0, true) end, { desc = '[B]uffer [D]elete, discard changes' })
pcall(function() require('which-key').add { { '<leader>b', group = '[B]uffer' } } end)

-- [[ Send files to Claude ]]
-- Sends the file under the cursor. For several files, select them in visual
-- mode and use the existing <leader>a, which understands tree selections.
vim.api.nvim_create_autocmd('FileType', {
  group = vim.api.nvim_create_augroup('explorer-claude', { clear = true }),
  pattern = { 'neo-tree', 'oil' },
  callback = function(ev)
    vim.keymap.set('n', '<leader>as', '<cmd>ClaudeCodeTreeAdd<cr>', { buffer = ev.buf, desc = '[A]gent: [s]end file' })
  end,
})
