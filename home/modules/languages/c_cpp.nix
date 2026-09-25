{ pkgs, ... }:
{
  languages.c_cpp = {
    packages = with pkgs; [
      clang-tools
      cmake-language-server
    ];
    servers = [
      "clangd"
      "cmake"
    ];
    grammars = [
      "c"
      "cpp"
      "cmake"
    ];
    filetypes = [
      "c"
      "cpp"
      "cmake"
    ];
  };
}
