# indentmini.nvim
A minimal less than ~100 lines and blazing fast indentline plugin. no much more features.

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
    vim.cmd.highlight('IndentLine guifg=#123456')
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
          '#AD7021',
          '#8887C3',
          '#738A05',
          '#5F819D',
          '#9E8FB2',
          '#907AA9',
          '#CDA869',
          '#8F9D6A',
        }

        -- you could add some logic here to conditionally set the
        -- highlight colors based on what scheme you're switching to.

        for i, val in pairs(hi_colors) do
          vim.api.nvim_set_hl(0, 'IndentLine' .. i, { fg = val })
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
