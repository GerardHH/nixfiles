{ pkgs, ... }:
{
  languages.bash = {
    packages = with pkgs; [
      bash-language-server
      shellcheck
      shfmt
    ];
    servers = [ "bashls" ];
    filetypes = [
      "bash"
      "sh"
    ];
  };
}
