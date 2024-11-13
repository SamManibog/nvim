local M = {}

local diagnosticSeverityMap = {
    "ERROR",
    "WARNING",
    "INFO",
    "HINT",
}

function M.gotoFirstDiagnostic(bufnr, severity)
    local diags = {}
    if severity then
        diags = vim.diagnostic.get(bufnr, { severity = severity })
    else
        diags = vim.diagnostic.get(bufnr)
    end

    local first = diags[1]
    if first == nil then
        print("No diagnostic found")
        return
    end

    vim.api.nvim_win_set_cursor(
        0,
        {
            first.lnum + 1,
            first.col
        }
    )

    print(diagnosticSeverityMap[severity] .. ": " .. first.message)
end

return M
