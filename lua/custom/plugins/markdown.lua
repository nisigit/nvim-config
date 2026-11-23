-- Pretty markdown rendering, in place in the normal buffer (no separate viewer).
--
--   <leader>tm   toggle rendering for this buffer: rendered <-> raw
--
-- You mostly won't need that key, though: with `render_modes` below the file is
-- rendered while you are in normal mode and turns back into raw markdown the
-- moment you press `i` (and while in visual mode). So reading looks nice, and
-- editing shows exactly the real text.
--
-- Commands, if you prefer typing them:
--   :RenderMarkdown buf_toggle        same as <leader>tm, this buffer only
--   :RenderMarkdown enable|disable    turn it on/off for every buffer
--   :RenderMarkdown preview           read-only rendered copy in a side split
--   :checkhealth render-markdown      if something ever looks off
--
-- To remove it entirely: delete this file. Nothing else references it.

local function gh(repo) return 'https://github.com/' .. repo end

vim.pack.add({ { src = gh 'MeanderingProgrammer/render-markdown.nvim' } }, { confirm = false })

require('render-markdown').setup {
  -- Render in normal/command/terminal mode only. Insert and visual mode show the
  -- raw markdown, so what you type is what is actually in the file.
  render_modes = { 'n', 'c', 't' },
  -- Checkbox / callout completion through blink.cmp.
  completions = { lsp = { enabled = true } },
}

vim.keymap.set('n', '<leader>tm', '<cmd>RenderMarkdown buf_toggle<cr>', { desc = '[M]arkdown render toggle (buffer)' })
