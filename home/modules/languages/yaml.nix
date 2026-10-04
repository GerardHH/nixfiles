{ pkgs, ... }:
{
    languages.yaml = {
        # yamlls: formats on save (prettier inside the server) and validates against
        # SchemaStore.nvim's schemas.
        packages = [ pkgs.yaml-language-server ];
        servers = [ "yamlls" ];
        formatters = [ "yamlls" ];
    };
}
