{ pkgs, ... }:
{
    languages.json = {
        # vscode-json-language-server (jsonls): formats on save and validates against
        # SchemaStore.nvim's schemas.
        packages = [ pkgs.vscode-langservers-extracted ];
        servers = [ "jsonls" ];
        formatters = [ "jsonls" ];
        filetypes = [
            "json"
            "jsonc"
        ];
    };
}
