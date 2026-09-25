{ pkgs, ... }:
{
  languages.markdown = {
    packages = [ pkgs.marksman ];
    servers = [ "marksman" ];
    grammars = [ "markdown" "markdown_inline" ];
  };
}
