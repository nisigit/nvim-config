-- Working alongside a Claude Code session running in another cmux pane.

local function gh(repo) return 'https://github.com/' .. repo end

-- [[ Pick up files changed outside nvim ]]
-- FocusGained alone is not enough: the agent edits files while nvim sits idle
-- in a focused or unfocused pane, so a timer polls as well.
vim.o.autoread = true

local function checktime()
  local in_cmdline = vim.fn.mode():match '^[cr!]' ~= nil or vim.fn.getcmdwintype() ~= ''
  if not in_cmdline then vim.cmd 'silent! checktime' end
end

local autoread_group = vim.api.nvim_create_augroup('agent-autoread', { clear = true })

vim.api.nvim_create_autocmd({ 'FocusGained', 'BufEnter' }, {
  group = autoread_group,
  callback = checktime,
})

-- Without this handler a change to a buffer with unsaved edits opens a blocking
-- prompt, which the timer could trigger while you are typing.
vim.api.nvim_create_autocmd('FileChangedShell', {
  group = autoread_group,
  callback = function(ev)
    local name = vim.fn.fnamemodify(ev.file, ':~:.')
    if vim.v.fcs_reason == 'deleted' then
      vim.v.fcs_choice = ''
      vim.notify(name .. ' was deleted on disk', vim.log.levels.WARN)
    elseif vim.bo[ev.buf].modified then
      vim.v.fcs_choice = ''
      vim.notify(name .. ' changed on disk; keeping your unsaved edits', vim.log.levels.WARN)
    else
      vim.v.fcs_choice = 'reload'
    end
  end,
})

local autoread_timer = assert(vim.uv.new_timer())
autoread_timer:start(2000, 2000, vim.schedule_wrap(checktime))

-- [[ Connect to Claude Code ]]
-- The server only listens for the Claude session in the cmux pane; 'none' stops
-- the plugin from opening its own terminal.
vim.pack.add({ gh 'coder/claudecode.nvim' }, { confirm = false })
require('claudecode').setup { terminal = { provider = 'none' } }

vim.keymap.set('v', '<leader>a', '<cmd>ClaudeCodeSend<cr>', { desc = 'Send selection to [A]gent' })
vim.keymap.set('n', '<leader>ab', '<cmd>ClaudeCodeAdd %<cr>', { desc = '[A]gent: add current [b]uffer' })
vim.keymap.set('n', '<leader>aa', '<cmd>ClaudeCodeDiffAccept<cr>', { desc = '[A]gent: [a]ccept diff' })
vim.keymap.set('n', '<leader>ad', '<cmd>ClaudeCodeDiffDeny<cr>', { desc = '[A]gent: [d]eny diff' })

-- [[ Review a whole branch ]]
vim.pack.add({ gh 'sindrets/diffview.nvim' }, { confirm = false })
require('diffview').setup { use_icons = false }

-- Diffing from the merge base shows only this branch's work, plus anything
-- uncommitted, even if the default branch has moved on.
local function open_branch_diff()
  for _, base in ipairs { 'origin/HEAD', 'main', 'master' } do
    local result = vim.system({ 'git', 'merge-base', 'HEAD', base }, { text = true }):wait()
    if result.code == 0 then
      vim.cmd('DiffviewOpen ' .. vim.trim(result.stdout))
      return
    end
  end
  vim.cmd 'DiffviewOpen'
end

vim.keymap.set('n', '<leader>gd', open_branch_diff, { desc = '[G]it: [d]iff branch' })
vim.keymap.set('n', '<leader>gq', '<cmd>DiffviewClose<cr>', { desc = '[G]it: [q]uit diff' })
