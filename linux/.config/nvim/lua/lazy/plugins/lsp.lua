return {
    "neovim/nvim-lspconfig",
    dependencies = {
        "mason-org/mason.nvim",
        "mason-org/mason-lspconfig.nvim",
    },

    config = function()
        local capabilities = require("cmp_nvim_lsp").default_capabilities()
        local lsp_servers = require("utils").lsp_servers

        require("mason-lspconfig").setup({
            ensure_installed = lsp_servers,
            handlers = {
                function(server_name)
                    require("lspconfig")[server_name].setup({
                        capabilities = capabilities,
                    })
                end,
            },
        })
    end
}
