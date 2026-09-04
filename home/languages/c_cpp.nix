{ pkgs, ... }:
{
  home.packages = with pkgs; [
    clang-tools
    cmake-language-server
  ];
}
