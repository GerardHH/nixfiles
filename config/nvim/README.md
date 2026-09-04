<!--toc:start-->
- [Dependencies](#dependencies)
- [How to use](#how-to-use)
- [TODO](#todo)
<!--toc:end-->

# Dependencies
- ripgrep for fzf-lua.
- Language servers (LS) are not installed, mason is not used. Either install manually or use the home-manager config.
- Tree-sitter config doesn't auto install correctly yet, if some are not installed use `TSInstall <language>` or `TSInstall all`.

# How to use
- Use '<leader>' which is '<space>' for most plugin actions. Wait 1 second for Which-Key to show all possible combinations.
- Almost all other vim keybindings are left as is.

# TODO
- Add c++ debugger
- nvim-treesitter-textobjects.nvim for improved "block" movements(see https://www.youtube.com/watch?v=CEMPq_r8UYQ)
- Buffer management remains suboptimal.
    - Perhaps the new fzf-lua plugin can play a role?
