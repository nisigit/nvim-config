-- lazygit in a floating window, for staging and committing after a review.
--
--   <leader>gg  open lazygit for the current repo (again = jump back to it)
--   q           while lazygit is focused: quit lazygit and close the float
--   <Esc>       if you ever end up in normal mode in the float, puts you back
--               into lazygit; <C-\><C-n> gets you back to normal mode
--
-- Inside lazygit, `e` on a file closes the float and opens that file in this nvim
-- rather than starting a nested nvim inside the terminal.

local M = {}

-- Track the float so we never end up with two lazygits stacked on top of each
-- other, and so closing it by any route also stops the job.
M.win = nil
M.buf = nil
M.job = nil

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
  pcall(vim.cmd, 'silent! checktime')
  pcall(function() require('gitsigns').refresh() end)
  pcall(function() require('neo-tree.sources.manager').refresh 'git_status' end)
end

function M.close()
  local job, win, buf = M.job, M.win, M.buf
  M.job, M.win, M.buf = nil, nil, nil

  if job then pcall(vim.fn.jobstop, job) end
  if win and vim.api.nvim_win_is_valid(win) then vim.api.nvim_win_close(win, true) end
  if buf and vim.api.nvim_buf_is_valid(buf) then pcall(vim.api.nvim_buf_delete, buf, { force = true }) end

  refresh_after_lazygit()
end

function M.open()
  if vim.fn.executable 'lazygit' == 0 then
    vim.notify('lazygit is not installed (brew install lazygit)', vim.log.levels.ERROR)
    return
  end

  -- Already open (maybe sitting behind another window): just focus it.
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_set_current_win(M.win)
    vim.cmd.startinsert()
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

  M.win, M.buf = win, buf

  -- Closing the window by any route (:q, <C-w>c, mouse) must also stop lazygit,
  -- otherwise the job keeps running headless and its output goes nowhere.
  vim.api.nvim_create_autocmd('WinClosed', {
    once = true,
    pattern = tostring(win),
    callback = function() M.close() end,
  })

  -- A terminal buffer still inherits this config's *normal mode* maps. In normal
  -- mode, space/tm/e/- would fire and open windows *behind* the float, so the
  -- float looks frozen while your keys do something invisible. Shadow them.
  vim.keymap.set('n', 'q', M.close, { buffer = buf, desc = 'lazygit: quit and close float' })
  vim.keymap.set('n', '<Esc>', '<cmd>startinsert<cr>', { buffer = buf, desc = 'lazygit: back into lazygit' })

  -- Declared first so the on_exit closure below captures this local, not a global.
  local job
  job = vim.fn.jobstart({ 'lazygit' }, {
    term = true,
    env = lazygit_env(),
    on_exit = function()
      vim.schedule(function()
        -- Only react if this is still the lazygit we opened (not a stale job).
        if M.job == job then M.close() end
      end)
    end,
  })

  if job <= 0 then
    vim.notify('lazygit failed to start', vim.log.levels.ERROR)
    M.close()
    return
  end

  M.job = job
  vim.cmd.startinsert()
end

vim.keymap.set('n', '<leader>gg', M.open, { desc = '[G]it: lazy[g]it' })
pcall(function() require('which-key').add { { '<leader>g', group = '[G]it' } } end)

return M
