return {
  "kevinhwang91/nvim-ufo",
  dependencies = "kevinhwang91/promise-async",
  event = "BufReadPost", -- Load only when a buffer is read for better startup performance
  init = function()
    -- Fold options (required for ufo)
    vim.o.foldcolumn = "1" -- '0' is not bad
    vim.o.foldlevel = 99 -- High value required by ufo to unfold by default
    vim.o.foldlevelstart = 99
    vim.o.foldenable = true
    
    -- Recommended keymaps for nvim-ufo
    vim.keymap.set("n", "zR", require("ufo").openAllFolds)
    vim.keymap.set("n", "zM", require("ufo").closeAllFolds)
    vim.keymap.set("n", "zr", require("ufo").openFoldsExceptKinds)
    vim.keymap.set("n", "zm", require("ufo").closeFoldsWith) -- close fold automatically
    vim.keymap.set("n", "K", function()
      local winid = require("ufo").peekFoldedLinesUnderCursor()
      if not winid then
        vim.lsp.buf.hover() -- Fallback to hover if not peeking a fold
      end
    end, { desc = "Peek fold or hover" })
  end,
  config = function()
    -- Example setup for LSP providers
    -- (Make sure this is done BEFORE your LSP servers are set up)
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    capabilities.textDocument.foldingRange = {
      dynamicRegistration = false,
      lineFoldingOnly = true,
    }
    
    -- If you are using nvim-lspconfig, ensure your servers get the capabilities:
    -- require("lspconfig").[your_server].setup({ capabilities = capabilities })

    require("ufo").setup({
      provider_selector = function(bufnr, filetype, buftype)
        return { "lsp", "indent" } -- Uses LSP for folds, falling back to indent
      end,
    })
  end,
}