vim.filetype.add({
    filename = {
        -- Dev Containers allow comments; treat them appropiatelly.
        ["devcontainer.json"] = "jsonc",
        [".devcontainer.json"] = "jsonc",
    },
    pattern = {
        -- VS Code's settings, launch and tasks files take comments as well.
        [".*/%.vscode/.*%.json"] = "jsonc",
        -- config/git/gitconfig and gitconfig-lely-guard: nvim only knows names like
        -- .gitconfig and git/config.
        [".*/gitconfig[^/]*"] = "gitconfig",
        -- compose.yaml, docker-compose.yml, podman-compose.yaml, …:
        -- docker_language_server only attaches to this filetype. yamlls and the yaml
        -- ftplugin still apply, through the "yaml" part.
        [".*/[^/]*compose[^/]*%.ya?ml"] = "yaml.docker-compose",
    },
})

-- Treesitter looks parsers up by the whole filetype name, so the compound
-- filetype above has to be pointed at the yaml parser.
vim.treesitter.language.register("yaml", "yaml.docker-compose")
