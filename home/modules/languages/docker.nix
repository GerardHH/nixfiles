{ pkgs, ... }:
{
    languages.docker = {
        packages = [
            pkgs.docker-language-server
            pkgs.dockerfile-language-server
        ];
        servers = [
            "docker_language_server"
            "dockerls"
        ];
        formatters = [ "dockerls" ];
        grammars = [ "dockerfile" ];
        filetypes = [
            "dockerfile"
            "yaml.docker-compose"
        ];
    };
}
