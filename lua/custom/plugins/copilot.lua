vim.pack.add { 'https://github.com/zbirenbaum/copilot.lua' }

vim.api.nvim_create_autocmd('InsertEnter', {
  once = true,
  callback = function()
    require('copilot').setup {
      suggestion = { enabled = false }, -- handled by blink-cmp-copilot
      panel = { enabled = false },
    }
  end,
})
