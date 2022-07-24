local api = vim.api
local uv = vim.loop


local M = {
    BUFFER_OPTIONS = {
        swapfile = false,
        -- buftype = "nofile",
        modifiable = false,
        filetype = "markdown",
        bufhidden = "wipe",
        buflisted = false,
    }
}

function M.arrange_wins(script_path, result_path)
    vim.cmd("wincmd k")
    vim.cmd("e " .. vim.fn.fnameescape(script_path))
    local winnr_up = api.nvim_get_current_win()
    vim.cmd("99wincmd j")
    local winnr = api.nvim_get_current_win()
    if winnr_up == winnr then
        vim.cmd("sp")
        vim.cmd("wincmd j")
    end
    vim.cmd("e " .. vim.fn.fnameescape(result_path))
    winnr = api.nvim_get_current_win()
    local bufnr = api.nvim_get_current_buf()
    for option, value in pairs(M.BUFFER_OPTIONS) do
        vim.bo[bufnr][option] = value
    end
    local height = math.floor(vim.o.lines * 0.7)
    if api.nvim_win_get_height(winnr) ~= height then
        api.nvim_win_set_height(winnr, height)
    end
    return winnr, bufnr
end

function M.run_script(script_path)
    -- process arguments
    if not script_path or script_path == "" then
        script_path = vim.fn.expand("%:p")
    end
    local suffix = ".result/" .. os.date('%Y-%m-%dT%H-%M-%S') .. ".md"
    if script_path:match("%.result/%d%d%d%d%-%d%d%-%d%dT%d%d%-%d%d%-%d%d%.md$") then
        script_path = script_path:sub(0, - #suffix - 1)
    end
    local result_path = script_path .. suffix
    -- make sure result folder exists
    os.execute("mkdir -p '" .. script_path .. ".result'")
    -- arrange windows for viewing sciprt / result
    local winnr, bufnr = M.arrange_wins(script_path, result_path)


    local stdin = uv.new_pipe(false)
    local stdout = uv.new_pipe(false)
    local stderr = uv.new_pipe(false)

    local output_buf = {
        stdout = '',
        stderr = '',
        all = '',
    }
    local function update_buf(lines, move_to_line)
        api.nvim_buf_set_option(bufnr, "modifiable", true)
        api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
        api.nvim_buf_set_option(bufnr, "modifiable", false)
        api.nvim_buf_set_option(bufnr, "modified", false)
        if api.nvim_win_is_valid(winnr) then
            api.nvim_win_set_cursor(winnr, { move_to_line, 0 })
        end
    end

    local function update_chunk(key, chunk)
        if chunk then
            output_buf[key] = output_buf[key] .. chunk
            output_buf.all = output_buf.all .. chunk
            local lines = vim.split(output_buf.all, '\n', true)
            update_buf(lines, #lines)
        end
    end

    update_chunk = vim.schedule_wrap(update_chunk)

    local handle, pid, started_at
    started_at = os.time()
    handle, pid = uv.spawn("sh", {
        stdio = { stdin, stdout, stderr };
        -- cwd = cwd;
    }, function(code, signal)
        stdin:close()
        stdout:close()
        stderr:close()
        handle:close()

        vim.schedule(function()
            local stdout_lines = vim.split(output_buf.stdout, '\n', true)
            local stderr_lines = vim.split(output_buf.stderr, '\n', true)

            local stdout_fmt = "json"
            for _, line in ipairs(stderr_lines) do
                local fmt = line:lower():match '^.*%s*content%-type%p.*(json)'
                if not fmt then
                    fmt = line:lower():match '^.*%s*content%-type%p.*(xml)'
                end
                if not fmt then
                    fmt = line:lower():match '^.*%s*content%-type%p.*(yml)'
                end
                if not fmt then
                    fmt = line:lower():match '^.*%s*content%-type%p.*(yaml)'
                end
                if fmt then
                    stdout_fmt = fmt
                end
            end

            local lines = vim.tbl_flatten {
                "stderr:",
                "```sh",
                stderr_lines,
                "```",
                "",
                "Total Elapsed Time: " .. os.difftime(os.time(), started_at) .. "s",
                "Exit Code:" .. code .. "  Signal: " .. signal,
                "",
                "stdout:",
                "```" .. stdout_fmt,
                stdout_lines,
                "```",
            }
            update_buf(lines, #stderr_lines + 7)
            api.nvim_buf_call(bufnr, function()
                vim.cmd "w"
                vim.cmd "e"
            end)
        end)
    end)

    update_buf({ string.format("Started %s   PID: %d", script_path, pid) }, 1)

    -- If the buffer closes, then kill our process.
    api.nvim_buf_attach(bufnr, false, {
        on_detach = function()
            if not handle:is_closing() then
                handle:kill(15)
            end
        end;
    })

    stdout:read_start(function(_, chunk) update_chunk("stdout", chunk) end)
    stderr:read_start(function(_, chunk) update_chunk("stderr", chunk) end)
    stdin:write(script_path)
    stdin:write("\n")
    stdin:shutdown()
end

function M.setup()
    vim.api.nvim_create_user_command("RunScript", function(res)
        M.run_script(res.args)
    end, { nargs = "?" })
end

return M
