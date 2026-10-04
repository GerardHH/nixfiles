{ pkgs, ... }:
{
    languages.lua = {
        packages = with pkgs; [
            lua-language-server
            stylua
        ];
        servers = [ "lua_ls" ];
        formatters = [ "null-ls" ]; # stylua
    };
}
