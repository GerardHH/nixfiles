{ pkgs, ... }:
{
  languages.python = {
    packages = with pkgs; [
      black
      mypy
      pyright
      ruff
    ];
    servers = [ "pyright" "ruff" ];
  };
}
