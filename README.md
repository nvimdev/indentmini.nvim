# indentmini.nvim

An indentation plugin born for the pursuit of minimalism, speed and stability.<br>
It renders in the NeoVim screen redraw circle and should keep the NeoVim fast.

## Install

Install with any plugin manager or as a NeoVim package.

## Configuration

| Key              | Description                                   | Default                   |
|------------------|-----------------------------------------------|---------------------------|
| char             | Character to draw the indentation guides      | `<BAR>`                   |
| enabled          | Default state of the plugin                   | `true`                    |
| exclude          | Disable in these filetypes                    | `{}`                      |
| exclude_nodetype | TreeSitter classes where guides are not drawn | `{}` |
| key              | Hotkey to toggle the guides                   | `''`                      |
| minlevel         | Minimum level where indentation is drawn      | `0`                       |
| only_current     | only highlight current indentation level      | `false`                   |

### Example

The plugin supports lazy-loading:

```lua
-- Either declare `vim.g.indentmini_key` before you load the plugin:
vim.g.indentmini_key = '<F5>'

-- or use your plugin manager, for example Lazy.nvim:
{
    url = 'https://github.com/nvimdev/indentmini.nvim',
    cmd = { 'IndentToggle', 'IndentEnable', 'IndentDisable' },
    keys = {
        {'<F5>', '<Cmd>IndentToggle<CR>', desc = 'Toggle indent guides'},
    },
    lazy = true,
    config = function()
        require("indentmini").setup({
            only_current = false,
            enabled = false,
            char = '▏',
            key = '<F5>', -- optional, can be set here if you don't lazy-load
            minlevel = 2,
            exclude = { 'markdown', 'help', 'text', 'rst' },
            exclude_nodetype = { 'string', 'comment' }
        })
    end
}
```

## Toggle functionality

You can toggle the guides via:

#### Commands

- `:IndentToggle` - Toggle indent guides on/off
- `:IndentEnable` - Enable indent guides
- `:IndentDisable` - Disable indent guides

#### Hotkey

For lazy-loading setups, set the global variable before the plugin loads:
```lua
vim.g.indentmini_key = '<F5>'
```

For non-lazy setups, use the `key` option in `setup()`:
```lua
require("indentmini").setup({
    key = '<F5>',
})
```

#### API

```lua
local indentmini = require("indentmini")
indentmini.toggle()
indentmini.enable()
indentmini.disable()
```

## Colours

The plugin uses `IndentLine*` highlight groups and provides no default values.

```lua
vim.cmd.highlight('IndentLine guifg=#123456')
vim.cmd.highlight('IndentLineCurrent guifg=#123456')
```

## Licence

MIT
