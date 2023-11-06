local rt = require("rust-tools")

local M = {}

function M.setup_lsp_commands()
  vim.lsp.commands["rust-analyzer.runSingle"] = function(command)
    rt.runnables.run_command(1, command.arguments)
  end

  vim.lsp.commands["rust-analyzer.gotoLocation"] = function(command, ctx)
    local client = vim.lsp.get_client_by_id(ctx.client_id)
    vim.lsp.util.jump_to_location(command.arguments[1], client.offset_encoding)
  end

  vim.lsp.commands["rust-analyzer.showReferences"] = function(_)
    vim.lsp.buf.implementation()
  end

  vim.lsp.commands["rust-analyzer.debugSingle"] = function(command)
    rt.utils.sanitize_command_for_debugging(command.arguments[1].args.cargoArgs)
    local args = command.arguments[1].args

    if vim.fn.getenv("RUST_EXECUTABLE_ARGS") ~= vim.NIL then
      args.executableArgs = vim.split(vim.fn.getenv("RUST_EXECUTABLE_ARGS"), " ")
    end


    -- {
    --   cargoArgs = { "build", "--package", "rust-playground", "--bin", "rust-playground" },
    --   cargoExtraArgs = {},
    --   executableArgs = {},
    --   workspaceRoot = "/Users/pg/github/rust-playground"
    -- }
    rt.dap.start(args)
  end
end

return M
