vim.api.nvim_create_user_command(
    'IndentToggle',
    function() require('indentmini').toggle() end,
    { desc = 'Toggle indent guides' }
)

vim.api.nvim_create_user_command(
    'IndentEnable',
    function() require('indentmini').enable() end,
    { desc = 'Enable indent guides' }
)

vim.api.nvim_create_user_command(
    'IndentDisable',
    function() require('indentmini').disable() end,
    { desc = 'Disable indent guides' }
)

if vim.g.indentmini_key then
    vim.keymap.set('n', vim.g.indentmini_key, '<Cmd>IndentToggle<CR>', {
        desc = 'Toggle indent guides',
        noremap = true,
        silent = true,
    })
end
