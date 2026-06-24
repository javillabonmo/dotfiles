return {
    "zbirenbaum/copilot.lua",
    event = "InsertEnter",
    dependencies = {
        "zbirenbaum/copilot-cmp",
    },
    config = function()
        require("copilot").setup({
            suggestion = {
                enabled = true,
                auto_trigger = false,
                debounce = 75,
                keymap = {
                    accept = "<C-CR>",
                    next = "<M-]>",
                    prev = "<M-[>",
                    dismiss = "<C-]>",
                },
            },
            panel = {
                enabled = true,
                auto_refresh = true,
            },
        })

        vim.keymap.set('i', '<M-Space>', '<Cmd>Copilot suggestion<CR>',
            { noremap = true, silent = true, desc = 'Copilot manual suggestion' })

        require("copilot_cmp").setup({
            method = "getCompletionsCycling",
        })
    end,
}
