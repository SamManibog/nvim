--note: installslive-server node.js package via npm
return {
    'barrett-ruth/live-server.nvim',
    build = 'npm install -g live-server',
    cmd = { 'LiveServerStart', 'LiveServerStop' },
    config = function()
        require('live-server').setup()

        vim.api.nvim_create_autocmd({ "ExitPre" }, { command = "LiveServerStop" });
    end
}
