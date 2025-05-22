-- using lazy.nvim
plugin = {'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'}
function plugin.config()
    require("bufferline").setup{}
end
return plugin
