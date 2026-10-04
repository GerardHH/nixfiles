{ pkgs, ... }:
{
    languages.markdown = {
        packages = [
            pkgs.marksman
            pkgs.rumdl
        ];
        servers = [
            "marksman"
            "rumdl"
        ];
        grammars = [
            "markdown"
            "markdown_inline"
        ];
    };
}
