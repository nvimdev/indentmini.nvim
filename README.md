# indentmini.nvim
A minimal and blazing fast indentline plugin by using `nvim_set_decoration_provide` api

## Install

- Lazy.nvim

```lua
require('lazy').setup({
    'nvimdev/indentmini.nvim',
    event = 'BufEnter',
    config = function()
        require('indentmini').setup({})
    end,
    -- this is no required but if you want indent blanklink line this is needed
    dependencies = { 'nvim-treesitter/nvim-treesitter'}
})
```

## Config

- char    -- string type default is  `│`,
- exclude -- table  type add exclude filetype in this table

highlight group is `IndentLine`. you can use this to link it to `Comment`

```
vim.cmd('hi defaule link IndentLine Comment')
```

## License MIT
