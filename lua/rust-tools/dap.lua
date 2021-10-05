local config = require 'rust-tools.config'

local M = {}

---For the heroes who want to use it
---@param codelldb_path string
---@param liblldb_path string
function M.get_codelldb_adapter(codelldb_path, liblldb_path)
    return function(callback, _)
        local stdout = vim.loop.new_pipe(false)
        local handle
        local pid_or_err
        local port

        local opts = {
            stdio = {nil, stdout},
            args = {"--liblldb", liblldb_path},
            detached = true
        }

        handle, pid_or_err = vim.loop.spawn(codelldb_path, opts, function(code)
            stdout:close()
            handle:close()
            if code ~= 0 then
                print('codelldb exited with code', code)
            end
        end)

        assert(handle, 'Error running codelldb: ' .. tostring(pid_or_err))

        stdout:read_start(function(err, chunk)
            assert(not err, err)
            if chunk then
                if not port then
                    local chunks = {}
                    for substring in chunk:gmatch("%S+") do
                        table.insert(chunks, substring)
                    end
                    port = tonumber(chunks[#chunks])
                    vim.schedule(function()
                        callback({
                            type = "server",
                            host = "127.0.0.1",
                            port = port
                        })
                    end)
                else
                    vim.schedule(function()
                        require('dap.repl').append(chunk)
                    end)
                end
            end
        end)

    end
end

function M.setup_adapter()
    local dap = require('dap')
    dap.adapters.rt_lldb = config.options.dap.adapter
end

local function get_cargo_args_from_runnables_args(runnable_args)
    local cargo_args = runnable_args.cargoArgs

    table.insert(cargo_args, '--message-format=json')

    for _, value in ipairs(runnable_args.cargoExtraArgs) do
        table.insert(cargo_args, value)
    end

    if not vim.tbl_isempty(runnable_args.executableArgs) then
        table.insert(cargo_args, "--")
        for _, value in ipairs(runnable_args.executableArgs) do
            table.insert(cargo_args, value)
        end
    end

    return cargo_args
end

local function scheduled_error(err)
    vim.schedule(function() vim.notify(err, vim.log.levels.ERROR) end)
end

function M.start(args)
    if not pcall(require, 'dap') then
        scheduled_error("nvim-dap not found.")
        return
    end

    if not pcall(require, 'plenary.job') then
        scheduled_error("plenary not found.")
        return
    end

    local dap = require('dap')
    local Job = require('plenary.job')

    local cargo_args = get_cargo_args_from_runnables_args(args)

    vim.notify(
        "Compiling a debug build for debugging. This might take some time...")

    Job:new({
        command = "cargo",
        args = cargo_args,
        cwd = args.workspaceRoot,
        on_exit = function(j, code)
            if code and code > 0 then
                scheduled_error(
                    "An error occured while compiling. Please fix all compilation issues and try again.")
            end
            vim.schedule(function()
                for _, value in pairs(j:result()) do
                    local json = vim.fn.json_decode(value)
                    if type(json) == "table" and json.executable ~= vim.NIL and
                        json.executable ~= nil then
                        local config = {
                            name = "Rust tools debug",
                            type = "rt_lldb",
                            request = "launch",
                            program = json.executable,
                            args = {},
                            cwd = args.workspaceRoot,
                            stopOnEntry = false,

                            -- if you change `runInTerminal` to true, you might need to change the yama/ptrace_scope setting:
                            --
                            --    echo 0 | sudo tee /proc/sys/kernel/yama/ptrace_scope
                            --
                            -- Otherwise you might get the following error:
                            --
                            --    Error on launch: Failed to attach to the target process
                            --
                            -- But you should be aware of the implications:
                            -- https://www.kernel.org/doc/html/latest/admin-guide/LSM/Yama.html
                            runInTerminal = false
                        }
                        dap.run(config)
                        break
                    end
                end
            end)
        end
    }):start()
end

return M
