local slimu = require("slimu")

vim.api.nvim_set_hl(0, "SlimuHighlight", {
	fg = "#9399b2", -- Your chosen foreground color
	-- fg = "#9370DB",
	-- fg = "#85EEA7",
	-- bg = "#9399b2",
	underline = true, -- Add underline style
	bold = true,
})

vim.api.nvim_set_hl(0, "SlimuHighlightSign", {
	fg = "#85EEA7",
	-- bg = "#9399b2",
	underline = false, -- Add underline style
	bold = true,
})

-- vim.api.nvim_create_namespace("SlimeeSign")

vim.fn.sign_define("SlimuCell", {
	-- text = "▶", -- The symbol to show
	text = "☳",
	texthl = "SlimuHighlightSign", -- Highlight group for the sign
	linehl = "SlimuHighlight", -- Optional: highlight for the whole line
	-- numhl = "", -- Optional: highlight for the line number
})

vim.api.nvim_create_user_command("SlimuConfig", slimu.config, {
	nargs = "?",
	force = true,
	complete = function()
		return vim.tbl_keys(slimu.Targets)
	end,
})

vim.api.nvim_create_user_command("SlimuSendCell", slimu.send_cell, { force = true })
vim.api.nvim_create_user_command("SlimuSendLine", slimu.send_line, { force = true })
vim.api.nvim_create_user_command("SlimuSendSelection", slimu.send_selection, { force = true })
vim.api.nvim_create_user_command("SlimuSendToCursor", slimu.send_to_cursor, { force = true })
