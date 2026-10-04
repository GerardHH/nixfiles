{ pkgs, ... }:
{
    languages.bash = {
        packages = with pkgs; [
            bash-language-server
            shellcheck
            shfmt
        ];
        servers = [ "bashls" ];
        formatters = [ "null-ls" ]; # shfmt
        filetypes = [
            "bash"
            "sh"
        ];
    };
}
