{ pkgs, ... }:
{
    languages.xml = {
        packages = [ pkgs.lemminx ];
        servers = [ "lemminx" ];
        formatters = [ "lemminx" ];
    };
}
