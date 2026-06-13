-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

local CURRENT_TEST_CONFIG = 'Run current test'
local CURRENT_TEST_FILE_CONFIG = 'Run current test file'

-- Helper function to run a DAP config by name, resolving any functions in the config
local function run_config(config_name)
  local dap = require 'dap'
  local ft = vim.bo.filetype
  local target = vim.tbl_filter(function(c) return c.name == config_name end, dap.configurations[ft] or {})[1]
  if not target then
    vim.notify('Config "' .. config_name .. '" not found for ' .. ft, vim.log.levels.WARN)
    return
  end
  local resolved = {}
  for k, v in pairs(target) do
    resolved[k] = type(v) == 'function' and v() or v
  end
  dap.run(resolved)
end

vim.pack.add {
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/mason-org/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim',
  'https://github.com/leoluz/nvim-dap-go',
}

-- Basic debugging keymaps, feel free to change to your liking!
vim.keymap.set('n', '<F5>', function() require('dap').continue() end, { desc = 'Debug: Start/Continue' })
vim.keymap.set('n', '<F1>', function() require('dap').step_into() end, { desc = 'Debug: Step Into' })
vim.keymap.set('n', '<F2>', function() require('dap').step_over() end, { desc = 'Debug: Step Over' })
vim.keymap.set('n', '<F3>', function() require('dap').step_out() end, { desc = 'Debug: Step Out' })
vim.keymap.set('n', '<leader>b', function() require('dap').toggle_breakpoint() end, { desc = 'Debug: Toggle Breakpoint' })
vim.keymap.set('n', '<leader>B', function() require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ') end, { desc = 'Debug: Set Breakpoint' })
-- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
vim.keymap.set('n', '<F7>', function() require('dapui').toggle() end, { desc = 'Debug: See last session result.' })
vim.keymap.set('n', '<leader>dr', function() require('dap').repl.open() end, { desc = 'Debug: Open REPL' })
vim.keymap.set('n', '<leader>dl', function() require('dap').run_last() end, { desc = 'Debug: Run Last' })
vim.keymap.set({ 'n', 'v' }, '<leader>de', function() require('dapui').eval() end, { desc = 'Debug: Eval expression' })
vim.keymap.set('n', '<leader>df', function() run_config(CURRENT_TEST_FILE_CONFIG) end, { desc = 'Debug: ' .. CURRENT_TEST_FILE_CONFIG })
vim.keymap.set('n', '<leader>dt', function() run_config(CURRENT_TEST_CONFIG) end, { desc = 'Debug: ' .. CURRENT_TEST_CONFIG })

local dap = require 'dap'
local dapui = require 'dapui'

require('mason-nvim-dap').setup {
  -- Makes a best effort to setup the various debuggers with
  -- reasonable debug configurations
  automatic_installation = true,

  -- You can provide additional configuration to the handlers,
  -- see mason-nvim-dap README for more information
  handlers = {},

  -- You'll need to check that you have the required things installed
  -- online, please don't ask me how to install them :)
  ensure_installed = {
    -- Update this to ensure that you have the debuggers for the langs you want
    'delve',
    'js',
  },
}

-- Dap UI setup
-- For more information, see |:help nvim-dap-ui|
---@diagnostic disable-next-line: missing-fields
dapui.setup {
  -- Set icons to characters that are more likely to work in every terminal.
  --    Feel free to remove or use ones that you like more! :)
  --    Don't feel like these are good choices.
  icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
  ---@diagnostic disable-next-line: missing-fields
  controls = {
    icons = {
      pause = '⏸',
      play = '▶',
      step_into = '⏎',
      step_over = '⏭',
      step_out = '⏮',
      step_back = 'b',
      run_last = '▶▶',
      terminate = '⏹',
      disconnect = '⏏',
    },
  },
}

-- Change breakpoint icons
vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
local breakpoint_icons = vim.g.have_nerd_font
    and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
  or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
for type, icon in pairs(breakpoint_icons) do
  local tp = 'Dap' .. type
  local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
  vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
end

dap.listeners.after.event_initialized['dapui_config'] = dapui.open
dap.listeners.before.event_terminated['dapui_config'] = dapui.close
dap.listeners.before.event_exited['dapui_config'] = dapui.close

-- Install golang specific config
require('dap-go').setup {
  delve = {
    -- On Windows delve must be run attached or it crashes.
    -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
    detached = vim.fn.has 'win32' == 0,
  },
}

dap.adapters = {
  ['pwa-node'] = {
    type = 'server',
    host = '127.0.0.1',
    port = '${port}',
    executable = {
      command = 'js-debug-adapter',
      args = {
        '${port}',
      },
    },
  },
}

for _, language in ipairs { 'typescript', 'javascript' } do
  require('dap').configurations[language] = {
    {
      type = 'pwa-node',
      request = 'launch',
      name = CURRENT_TEST_FILE_CONFIG,
      runtimeExecutable = 'node',
      runtimeArgs = function()
        return {
          -- '${workspaceFolder}/node_modules/jest/bin/jest.js',
          '${workspaceFolder}/node_modules/.bin/vitest',
          'run',
          -- '--no-coverage',
          '--testTimeout=60000',
          vim.fn.expand '%:.',
        }
      end,
      rootPath = '${workspaceFolder}',
      cwd = '${workspaceFolder}',
      console = 'integratedTerminal',
      internalConsoleOptions = 'neverOpen',
      resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
      skipFiles = { '<node_internals>/**', '**/node_modules/**' },
      sourceMaps = true,
    },
    {
      type = 'pwa-node',
      request = 'launch',
      name = CURRENT_TEST_CONFIG,
      runtimeExecutable = 'node',
      runtimeArgs = function()
        -- Walk up from cursor to find nearest it/test/describe name
        local function get_test_name()
          local linenr = vim.fn.line '.'
          for i = linenr, 1, -1 do
            local line = vim.fn.getline(i)
            local name = line:match '%f[%w_]it%s*%(%s*[\'"](.+)[\'"]'
              or line:match '%f[%w_]test%s*%(%s*[\'"](.+)[\'"]'
              or line:match '%f[%w_]describe%s*%(%s*[\'"](.+)[\'"]'
            if name then return name end
          end
          return ''
        end
        local name = get_test_name()
        local args = {
          -- './node_modules/jest/bin/jest.js',
          '${workspaceFolder}/node_modules/.bin/vitest',
          'run',
          -- '--runInBand',
          '--no-coverage',
          '--testTimeout=60000',
          vim.fn.expand '%:.',
        }
        if name ~= '' then vim.list_extend(args, { '--testNamePattern', name }) end
        return args
      end,
      rootPath = '${workspaceFolder}',
      cwd = '${workspaceFolder}',
      console = 'integratedTerminal',
      internalConsoleOptions = 'neverOpen',
      sourceMaps = true,
      skipFiles = { '<node_internals>/**', '**/node_modules/**' },
      resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
    },
  }
end
