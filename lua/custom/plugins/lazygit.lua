-- lazygit in a floating window, for staging and committing after a review.
--
--   <leader>gg  open lazygit for the current repo (q closes it)
--
-- Inside lazygit, `e` on a file closes the float and opens that file in this nvim
-- rather than starting a nested nvim inside the terminal.

-- Layer an editor override on top of the user's own lazygit config, so this only
-- applies when lazygit runs inside nvim. nvim-remote uses $NVIM, which nvim sets
-- in every terminal it starts.
local function lazygit_env()
  local user_config = vim.fs.normalize '~/Library/Application Support/lazygit/config.yml'
  if vim.fn.has 'mac' == 0 then user_config = vim.fs.normalize '~/.config/lazygit/config.yml' end

  local overlay = vim.fs.joinpath(vim.fn.stdpath 'cache', 'lazygit-nvim.yml')
  vim.fn.writefile({ 'os:', '  editPreset: nvim-remote' }, overlay)

  local files = vim.uv.fs_stat(user_config) and (user_config .. ',' .. overlay) or overlay
  return { LG_CONFIG_FILE = files }
end

-- Lazygit may have staged, committed, checked out or discarded changes.
local function refresh_after_lazygit()
  vim.cmd 'silent! checktime'
  pcall(function() require('gitsigns').refresh() end)
  pcall(require('neo-tree.sources.manager').refresh, 'git_status')
end

local function open_lazygit()
  if vim.fn.executable 'lazygit' == 0 then
    vim.notify('lazygit is not installed (brew install lazygit)', vim.log.levels.ERROR)
    return
  end

  local width = math.floor(vim.o.columns * 0.9)
  local height = math.floor(vim.o.lines * 0.9)
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = 'minimal',
    border = 'rounded',
  })

  vim.fn.jobstart({ 'lazygit' }, {
    term = true,
    env = lazygit_env(),
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
        if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
        refresh_after_lazygit()
      end)
    end,
  })
  vim.cmd.startinsert()
end

vim.keymap.set('n', '<leader>gg', open_lazygit, { desc = '[G]it: lazy[g]it' })
pcall(function() require('which-key').add { { '<leader>g', group = '[G]it' } } end)
