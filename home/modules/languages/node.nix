{ pkgs, ... }:
{
  languages.node = {
    packages = [ pkgs.nodejs ];
    # A runtime, not a language I edit here: no server, grammar or filetype.
    grammars = [ ];
    filetypes = [ ];
  };
}
