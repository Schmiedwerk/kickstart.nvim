-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

return {
  -- NOTE: Yes, you can install new plugins here!
  'mfussenegger/nvim-dap',
  -- NOTE: And you can specify dependencies as well
  dependencies = {
    -- Creates a beautiful debugger UI
    'rcarriga/nvim-dap-ui',

    -- Required dependency for nvim-dap-ui
    'nvim-neotest/nvim-nio',

    -- Installs the debug adapters for you
    'mason-org/mason.nvim',
    'jay-babu/mason-nvim-dap.nvim',

    -- Add your own debuggers here
    -- 'leoluz/nvim-dap-go',
  },
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<F5>',
      function()
        require('dap').continue()
      end,
      desc = 'Debug: Start/Continue',
    },
    {
      '<F1>',
      function()
        require('dap').step_into()
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<F2>',
      function()
        require('dap').step_over()
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<F3>',
      function()
        require('dap').step_out()
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>b',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = 'Debug: Toggle Breakpoint',
    },
    {
      '<leader>B',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = 'Debug: Set Breakpoint',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<F7>',
      function()
        require('dapui').toggle()
      end,
      desc = 'Debug: See last session result.',
    },
  },
  config = function()
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
        -- 'delve',
        'cppdbg',
      },
    }

    -- Dap UI setup
    -- For more information, see |:help nvim-dap-ui|
    dapui.setup {
      -- Set icons to characters that are more likely to work in every terminal.
      --    Feel free to remove or use ones that you like more! :)
      --    Don't feel like these are good choices.
      icons = { expanded = '▾', collapsed = '▸', current_frame = '*' },
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
    -- vim.api.nvim_set_hl(0, 'DapBreak', { fg = '#e51400' })
    -- vim.api.nvim_set_hl(0, 'DapStop', { fg = '#ffcc00' })
    -- local breakpoint_icons = vim.g.have_nerd_font
    --     and { Breakpoint = '', BreakpointCondition = '', BreakpointRejected = '', LogPoint = '', Stopped = '' }
    --   or { Breakpoint = '●', BreakpointCondition = '⊜', BreakpointRejected = '⊘', LogPoint = '◆', Stopped = '⭔' }
    -- for type, icon in pairs(breakpoint_icons) do
    --   local tp = 'Dap' .. type
    --   local hl = (type == 'Stopped') and 'DapStop' or 'DapBreak'
    --   vim.fn.sign_define(tp, { text = icon, texthl = hl, numhl = hl })
    -- end

    dap.listeners.after.event_initialized['dapui_config'] = dapui.open
    dap.listeners.before.event_terminated['dapui_config'] = dapui.close
    dap.listeners.before.event_exited['dapui_config'] = dapui.close

    -- Monkey-patch dap.terminate to reliably close dapui
    local orig_terminate = dap.terminate
    dap.terminate = function(...)
      local res = orig_terminate(...)
      dapui.close()
      return res
    end

    -- New tab instead of split terminal for debugging output
    -- dap.defaults.fallback.terminal_win_cmd = 'tabnew'

    -- Install golang specific config
    -- require('dap-go').setup {
    --   delve = {
    --     -- On Windows delve must be run attached or it crashes.
    --     -- See https://github.com/leoluz/nvim-dap-go/blob/main/README.md#configuring
    --     detached = vim.fn.has 'win32' == 0,
    --   },
    -- }

    -- =================================================================================================================
    -- C++ Debug Adapter Setup (cppdbg / GDB)
    -- =================================================================================================================

    -- Prompt the user for the target executable
    local function prompt_executable_path(prefix_msg)
      local prompt = 'Path to executable: '

      if prefix_msg then
        prompt = prefix_msg .. ' ' .. prompt
      end

      return vim.fn.input(prompt, vim.fn.getcwd() .. '/', 'file')
    end

    -- Prompt the user for program arguments
    local last_args = ''
    local function prompt_args()
      local input = vim.fn.input('Args: ', last_args)
      last_args = input

      return vim.fn.split(input, ' \\+')
    end

    -- Prompt the user for environment variables
    local last_env = ''
    local function prompt_env()
      local input = vim.fn.input('Env vars (KEY=VAL KEY=VAL): ', last_env)
      last_env = input

      local vars = {}
      for _, pair in ipairs(vim.fn.split(input, ' \\+')) do
        local kv = vim.fn.split(pair, '=', true)

        if #kv == 2 then
          -- vars[kv[1]] = kv[2]
          table.insert(vars, { name = kv[1], value = kv[2] })
        end
      end

      return vars
    end

    -- Prompt the user to pick an executable from a build directory
    local function pick_executable(build_dir)
      build_dir = build_dir or vim.fn.getcwd() .. '/build-x86_64/bin'

      local candidates = vim.fn.glob(build_dir .. '/*', false, true)
      local executables = {}

      -- Filter only files that are executable
      for _, file in ipairs(candidates) do
        if vim.fn.executable(file) == 1 then
          table.insert(executables, file)
        end
      end

      -- Fallback if no executables found
      if #executables == 0 then
        return prompt_executable_path 'No executables found.'
      end

      -- Build numbered list for inputlist
      local input_list = { 'Select executable.' }
      for i, exe in ipairs(executables) do
        table.insert(input_list, string.format('%d: %s', i, vim.fn.fnamemodify(exe, ':t')))
      end

      -- Let the user pick an executable
      local choice = vim.fn.inputlist(input_list)

      -- Handle the choice
      if choice < 1 or choice > #executables then
        return prompt_executable_path 'Fallback.'
      end

      return executables[choice]
    end

    -- Common setup variables
    local cppdbg_id = 'cppdbg'
    local cpp_setup_commands = {
      {
        text = '-enable-pretty-printing',
        description = 'enable pretty printing',
        ignoreFailures = false,
      },
    }

    -- Register the cppdbg adapter
    dap.adapters.cppdbg = {
      id = cppdbg_id,
      type = 'executable',
      command = vim.fn.stdpath 'data' .. '/mason/packages/cpptools/extension/debugAdapters/bin/OpenDebugAD7',
    }

    -- Launch configurations for C++
    dap.configurations.cpp = {
      setmetatable({
        name = 'Launch file',
        type = cppdbg_id,
        request = 'launch',
      }, {
        -- Using __call instead of separate functions for the user-specified keys ensures the functions are executed in a
        -- predictable, fixed order
        __call = function(cfg)
          local program = pick_executable()
          local args = prompt_args()
          local env = prompt_env()

          return {
            name = cfg.name,
            type = cfg.type,
            request = cfg.request,
            program = program,
            args = args,
            environment = env,
            cwd = '${workspaceFolder}',
            stopAtEntry = true,
            setupCommands = cpp_setup_commands,
          }
        end,
      }),
      {
        name = 'Attach to gdbserver :1234',
        type = cppdbg_id,
        request = 'attach',
        MIMode = 'gdb',
        miDebuggerServerAddress = 'localhost:1234',
        miDebuggerPath = '/usr/bin/gdb',
        cwd = '${workspaceFolder}',
        program = prompt_executable_path,
        setupCommands = cpp_setup_commands,
      },
    }

    -- Apply the same configurations to C files
    dap.configurations.c = dap.configurations.cpp
  end,
}
