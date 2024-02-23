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

```lua
config = function()
    require("indentmini").setup({
        char = "|",
        exclude = {
            "erlang",
            "markdown",
        }
    })

    -- Colors are applied automatically based on user-defined highlight groups.
    -- There is no default value.
    vim.cmd.highlight('IndentLine1 guifg=#123456')
    vim.cmd([[highlight IndentLine2 guifg=#123456]])
end,
```

## Recipies

By default, if you switch colorschemes your indent colors will be cleared out.
To fix this, create an autocommand that will set them again on change. You can
also set it up with different colors per-scheme if you'd like.

```lua
    config = function()
    -- create a function to set the colors
      local setColors = function()
        local hi_colors = {
          'guifg=#AD7021',
          'guifg=#8887C3',
          'guifg=#738A05',
          'guifg=#5F819D',
          'guifg=#9E8FB2',
          'guifg=#907AA9',
          'guifg=#CDA869',
          'guifg=#8F9D6A',
        }

        -- you could add some logic here to conditionally set the
        -- highlight colors based on what scheme you're switching to.

        for i, val in pairs(hi_colors) do
          vim.cmd.highlight('IndentLine' .. i .. ' ' .. val)
        end
      end

      -- set up an autocommand to set the colors when the colorscheme changes
      vim.api.nvim_create_autocmd('ColorScheme', {
        pattern = '*',
        callback = setColors,
      })

      -- don't forget to call it on startup!  
      setColors()

      require('indentmini').setup()
    end,
```

## License MIT
