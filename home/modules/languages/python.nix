{ pkgs, ... }:
{
  home.packages = with pkgs; [
    black
    mypy
    pyright
    ruff
  ];
}
