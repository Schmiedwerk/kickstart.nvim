-- debug.lua
--
-- Shows how to use the DAP plugin to debug your code.
--
-- Primarily focused on configuring the debugger for Go, but can
-- be extended to other languages as well. That's why it's called
-- kickstart.nvim and not kitchen-sink.nvim ;)

local function is_currently_debugging()
  return require('dap').session() ~= nil
end

local function check_currently_debugging()
  local currently_debugging = is_currently_debugging()

  if not currently_debugging then
    vim.notify('No debug session active.', vim.log.levels.INFO)
  end

  return currently_debugging
end

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
  init = function()
    -- Register the '[D]ebug' group with which-key
    local ok, which_key = pcall(require, 'which-key')
    if ok then
      which_key.add { { '<leader>d', group = '[D]ebug', icon = '🐞 ' } }
    end
  end,
  keys = {
    -- Basic debugging keymaps, feel free to change to your liking!
    {
      '<up>',
      function()
        if check_currently_debugging() then
          require('dap').continue()
        end
      end,
      desc = 'Debug: Continue',
    },
    {
      '<right>',
      function()
        if check_currently_debugging() then
          require('dap').step_into()
        end
      end,
      desc = 'Debug: Step Into',
    },
    {
      '<down>',
      function()
        if check_currently_debugging() then
          require('dap').step_over()
        end
      end,
      desc = 'Debug: Step Over',
    },
    {
      '<left>',
      function()
        if check_currently_debugging() then
          require('dap').step_out()
        end
      end,
      desc = 'Debug: Step Out',
    },
    {
      '<leader>ds',
      function()
        require('dap').continue()
      end,
      desc = '[D]ebug: [S]tart / Continue',
    },
    {
      '<leader>dt',
      function()
        if check_currently_debugging() then
          require('dap').terminate()
        end
      end,
      desc = '[D]ebug: [T]erminate',
    },
    {
      '<leader>db',
      function()
        require('dap').toggle_breakpoint()
      end,
      desc = '[D]ebug: Toggle [B]reakpoint',
    },
    {
      '<leader>dB',
      function()
        require('dap').set_breakpoint(vim.fn.input 'Breakpoint condition: ')
      end,
      desc = '[D]ebug: Set [B]reakpoint',
    },
    {
      '<leader>dl',
      function()
        if is_currently_debugging() then
          local choice = vim.fn.confirm('Debug session active. Terminate it and start a new one?', '&Yes\n&No', 2)
          if choice ~= 1 then
            vim.notify('Run last configuration aborted.', vim.log.levels.INFO)
            return
          end
        end
        require('dap').run_last()
      end,
      desc = '[D]ebug: Run [L]ast Configuration',
    },
    -- Toggle to see last session result. Without this, you can't see session output in case of unhandled exception.
    {
      '<leader>du',
      function()
        require('dapui').toggle()
      end,
      desc = '[D]ebug: Toggle dap-[u]i',
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

    -- Persistence of the last user inputs to prefill prompts

    local last_inputs_name = 'cpp_conf_last_inputs.lua'
    local last_inputs_path = vim.fn.stdpath 'data' .. '/persistence/nvim-dap/' .. last_inputs_name

    -- Load the saved last user inputs
    local function load_last_inputs()
      local ok_load, func_or_err, err_load = pcall(loadfile, last_inputs_path)

      if not ok_load or not func_or_err then
        -- Uses pcall's error when loadfile raised, otherwise loadfile's returned error message
        local actual_err = not ok_load and func_or_err or err_load
        vim.notify(string.format('Failed to load %s: "%s"', last_inputs_name, actual_err or 'unknown error'), vim.log.levels.WARN)
        return {}
      end

      local ok_exec, last_inputs_or_err = pcall(func_or_err)

      if not ok_exec then
        vim.notify(string.format('Failed to execute %s: "%s"', last_inputs_name, last_inputs_or_err or 'unknown error'), vim.log.levels.ERROR)
        return {}
      end

      if type(last_inputs_or_err) ~= 'table' then
        vim.notify(string.format('%s did not return a table (got %s)', last_inputs_name, type(last_inputs_or_err)), vim.log.levels.ERROR)
        return {}
      end

      return last_inputs_or_err
    end

    -- Save the last user inputs
    local function save_last_inputs(tbl)
      local dir = vim.fn.fnamemodify(last_inputs_path, ':h') -- Get parent directory
      vim.fn.mkdir(dir, 'p') -- Create all missing parent directories if needed

      local file, err = io.open(last_inputs_path, 'w')
      if not file then
        vim.notify(string.format('Failed to open %s for writing: "%s"', last_inputs_name, err or 'unknown error'), vim.log.levels.ERROR)
        return
      end

      file:write('return ' .. vim.inspect(tbl))
      file:close()
    end

    -- Prompt the user for the target executable
    local function prompt_executable_path(prefix_msg)
      local prompt = 'Path to executable: '

      if prefix_msg then
        prompt = prefix_msg .. ' ' .. prompt
      end

      return vim.fn.input(prompt, vim.fn.getcwd() .. '/', 'file')
    end

    -- Prompt the user for program arguments
    local function prompt_args(last_args)
      last_args = last_args or ''
      local input = vim.fn.input('Args: ', last_args)

      local new_args = vim.fn.split(input, ' \\+')
      local normalized_input = vim.fn.join(new_args, ' ')

      return new_args, normalized_input
    end

    -- Prompt the user for environment variables
    local function prompt_envs(last_envs)
      last_envs = last_envs or ''
      local input = vim.fn.input('Env vars (KEY=VAL KEY=VAL): ', last_envs)

      local new_envs = {}
      for _, pair in ipairs(vim.fn.split(input, ' \\+')) do
        local kv = vim.fn.split(pair, '=', true)

        if #kv == 2 then
          -- vars[kv[1]] = kv[2]
          table.insert(new_envs, { name = kv[1], value = kv[2] })
        end
      end

      local normalized_input = table.concat(
        vim.tbl_map(function(kv)
          return kv.name .. '=' .. kv.value
        end, new_envs),
        ' '
      )

      return new_envs, normalized_input
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
        -- Using __call instead of separate functions for the user-specified keys ensures that user prompts are executed in a
        -- predictable, fixed order
        __call = function(cfg)
          local last_inputs = load_last_inputs()

          local program = pick_executable()
          local args, args_input = prompt_args(last_inputs.args)
          local envs, envs_input = prompt_envs(last_inputs.envs)

          last_inputs.args = args_input
          last_inputs.envs = envs_input
          save_last_inputs(last_inputs)

          return {
            name = cfg.name,
            type = cfg.type,
            request = cfg.request,
            program = program,
            args = args,
            environment = envs,
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
