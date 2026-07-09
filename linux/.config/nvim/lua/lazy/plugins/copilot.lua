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

        

        require("copilot_cmp").setup({
            method = "getCompletionsCycling",
        })
    end,
}
