# indentmini.nvim
A minimal and blazing fast indentline plugin by using `nvim_set_decoration_provide` api

## Install

- Lazy.nvim

```lua
require('lazy').setup({
    'nvimdev/indentmini.nvim',
    event = 'BufEnter',
    config = function()
        require('indentmini').setup()
    end,
})
```

## Config

- char     -- string type default is  `│`,
- exclude  -- table  type add exclude filetype in this table
- hi_group -- table  type highlight groups to use

highlight groups for indentation markers are created automatically by passing in a list
of groups. Indentation colors will appear in the order they are passed in.

```lua
config = function()
    require("indentmini").setup({
        char = "|",
        exclude = {
            "erlang",
            "markdown",
        }
        hi_group = {
            'Comment',
            'Function',
            'Constant',
            'MyIndentation'
        }
    })
    vim.cmd.highlight('MyIndentation guifg=#32a852')
end,
```

## License MIT
