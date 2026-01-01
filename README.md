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
| exclude_nodetype | TreeSitter classes where guides are not drawn | `{ 'string', 'comment' }` |
| key              | Hotkey to toggle the guides                   | `''`                      |
| minlevel         | Minimum level where indentation is drawn      | `0`                       |
| only_current     | only highlight current indentation level      | `false`                   |

### Example

The plugin supports lazy-loading:

```lua
cmd = { 'IndentToggle', 'IndentEnable', 'IndentDisable' },
config = function()
    require("indentmini").setup({
        only_current = false,
        enabled = false,
        char = '▏',
        minlevel = 2,
        key = '<F5>',
        exclude = { 'markdown', 'help', 'text', 'rst' },
        exclude_nodetype = { 'string', 'comment' }
    })
end
```

## Toggle functionality

You can toggle the guides via:

#### Commands

- `:IndentToggle` - Toggle indent guides on/off
- `:IndentEnable` - Enable indent guides
- `:IndentDisable` - Disable indent guides

#### Hotkey

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
