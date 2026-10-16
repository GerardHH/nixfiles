{
    config,
    lib,
    link,
    pkgs,
    ...
}:
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

    xdg.configFile."clangd" = lib.mkIf config.languages.c_cpp.enable {
        source = link "config/clangd";
    };
}
