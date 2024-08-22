# indentmini.nvim

An indentation plugin born for the pursuit of **minimal**(~120 lines), **speed**(blazing fastest on files with tens of thousands of lines) and **stability**.
It renders in the neovim screen redraw circle and will never make your neovim slow.

![indentmini](https://github.com/nvimdev/indentmini.nvim/assets/41671631/99fb6dd4-8e61-412f-aa4c-c83ee7ce3206)

## Install

install with any plugin management or default vim package.

## Config

available config values in setup table.

- char     -- string type default is `│`,
- exclude  -- table  type add exclude filetype in this table ie `{ 'markdown', 'xxx'}`
- minlevel -- number the min level that show indent line default is 1
- only_current -- boolean default is false when true will only highlight current range

```lua
config = function()
    require("indentmini").setup() -- use default config
end,
```

## Highlight

if your colorscheme not config the `IndentLine*` relate highlight group you should config it in
your neovim config.

```lua
-- Colors are applied automatically based on user-defined highlight groups.
-- There is no default value.
vim.cmd.highlight('IndentLine guifg=#123456')
-- Current indent line highlight
vim.cmd.highlight('IndentLineCurrent guifg=#123456')
```

## License MIT
