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

- char    -- string type default is  `│`,
- exclude -- table  type add exclude filetype in this table

highlight group is `IndentLine`. you can use this to link it to `Comment`

```lua
config = function()
    require("indentmini").setup({
        char = "|",
        exclude = {
            "erlang",
            "markdown",
        }
    })
    -- use comment color
    vim.cmd.highlight("default link IndentLine Comment")
end,
```

## License MIT
