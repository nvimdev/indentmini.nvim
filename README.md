# indentmini.nvim
A minimal less than ~100 lines and blazing fast indentline plugin. no much more features.

![old](https://github.com/nvimdev/indentmini.nvim/assets/41671631/d836db79-4c41-45bc-99cb-d9f807dfe9af)

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

```lua
config = function()
    require("indentmini").setup({
        char = "|",
        current = true,
        exclude = {
            "erlang",
            "markdown",
        }
    })

    -- Colors are applied automatically based on user-defined highlight groups.
    -- There is no default value.
    vim.cmd.highlight('IndentLine guifg=#123456')
    -- Current indent line highlight
    vim.cmd.highlight('IndentLineCurrent guifg=#123456')
end,
```


## License MIT
