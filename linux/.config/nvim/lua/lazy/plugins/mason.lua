-- useful commands:
-- :checkhealth mason
return {
	"williamboman/mason.nvim",
    config = function()
        require("mason").setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗",
                }
            },
            registries = {
                "github:mason-org/mason-registry",
                "github:Crashdummyy/mason-registry",
            },
        })

        local formatters = require("utils").formatters
        local registry = require("mason-registry")
        for _, pkg_name in ipairs(formatters) do
            if registry.has_package(pkg_name) and not registry.is_installed(pkg_name) then
                registry.get_package(pkg_name):install()
            end
        end
    end,
}