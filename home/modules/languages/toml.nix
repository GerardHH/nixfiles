{ pkgs, ... }:
{
    languages.toml = {
        # taplo: language server and formatter in one binary. It brings its own
        # schema catalog (fetched from schemastore.org), so SchemaStore.nvim isn't
        # involved here.
        packages = [ pkgs.taplo ];
        servers = [ "taplo" ];
        formatters = [ "taplo" ];
    };
}
