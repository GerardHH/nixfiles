{ pkgs, ... }:
{
    languages.c_cpp = {
        packages = with pkgs; [
            clang-tools
            cmake
            cmake-language-server
        ];
        servers = [
            "clangd"
            "cmake"
        ];
        formatters = [ "null-ls" ]; # clang-format
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
