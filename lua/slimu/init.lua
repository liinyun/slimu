local util = require("slimu.util")
local M = {}

local defaults = { cell_delimiter = nil, target = "zmx" }

local zmx = require("slimu.zmx")
local tmux = require("slimu.tmux")

Targets = { zmx = zmx, tmux = tmux }

local function get_cfg()
	local cfg = vim.b.slimu_config or {}
	if not cfg.target then
		cfg.target = util.resolve("target")
	end
	for name, t in pairs(Targets) do
		cfg[name] = vim.tbl_deep_extend("force", t.defaults or {}, cfg[name] or {})
	end
	vim.b.slimu_config = cfg
	return cfg
end

local function slimu_config(opts)
	local cfg = get_cfg()
	local function configure_target(name)
		local t = Targets[name]
		if not t then
			vim.notify(
				("slimu: unknown target %q (available: %s)"):format(name, table.concat(vim.tbl_keys(Targets), ", ")),
				vim.log.levels.WARN
			)
			return
		end
		cfg.target = name
		vim.b.slimu_config = cfg
		vim.notify("slimu target: " .. name)
		if t.configure then
			t.configure(cfg[name])
		end
	end

	if opts.args ~= "" then
		configure_target(opts.args)
		return
	end

	vim.ui.input({ prompt = "slimu target: ", default = cfg.target }, function(text)
		if text == nil or text == "" then
			return
		end
		configure_target(text)
	end)
end

-- ─── dispatcher ────────────────────────────────────────────────

local function slimu_send(text)
	local cfg = vim.b.slimu_config
	local name = cfg.target
	local t = Targets[name]
	if not t then
		error(("slimu: unknown target %q (available: %s)"):format(name, table.concat(vim.tbl_keys(Targets), ", ")))
	end
	t.send(cfg[name], text)
end

local function send_line()
	-- 1. Fail early if connection isn't configured, matching your send_cell logic
	if not vim.b.slimu_config then
		vim.api.nvim_echo({
			{ "connection didn't set, please run :SlimuConfig first", "WarningMsg" },
		}, true, {})
		return
	end

	-- 2. Get the 0-based index of the current cursor line
	local current_line_idx = vim.api.nvim_win_get_cursor(0)[1] - 1

	-- 3. Retrieve just that single line from the buffer
	local lines = vim.api.nvim_buf_get_lines(0, current_line_idx, current_line_idx + 1, false)
	local current_line_text = lines[1]

	-- 4. Send it to the terminal if the line isn't empty or nil
	if current_line_text then
		slimu_send(current_line_text)
	end
end

---@param startline integer  1-based, inclusive
---@param endline   integer  1-based, inclusive
local function send_range(startline, endline)
	if startline > endline then
		return
	end
	local lines = vim.api.nvim_buf_get_lines(0, startline - 1, endline, false)
	if #lines == 0 then
		return
	end
	slimu_send(table.concat(lines, "\n"))
end

local function send_cell()
	if not vim.b.slimu_config then
		vim.api.nvim_echo({
			{ "connection didn't set, please run :SlimuConfig first", "WarningMsg" },
		}, true, {})
		return
	end
	local delim = util.resolve("cell_delimiter")
	if delim == nil then
		return
	end

	local line_ini = vim.fn.search(delim, "bcnW")
	local line_end = vim.fn.search(delim, "nW")
	line_ini = line_ini ~= 0 and line_ini + 1 or 1
	line_end = line_end ~= 0 and line_end - 1 or vim.fn.line("$")

	if line_ini <= line_end then
		send_range(line_ini, line_end)
	end
end

local function send_selection()
	-- 1. Fail early if connection isn't configured
	if not vim.b.slimu_config then
		vim.api.nvim_echo({
			{ "connection didn't set, please run :SlimuConfig first", "WarningMsg" },
		}, true, {})
		return
	end

	-- 2. Get the 1-based line numbers for the start and end of the visual selection
	-- '< and '> represent the start and end boundaries of the last visual selection
	local startline = vim.fn.getpos("'<")[2]
	local endline = vim.fn.getpos("'>")[2]

	-- 3. Pass the line boundaries straight to your existing range function
	if startline > 0 and endline > 0 then
		send_range(startline, endline)
	end
end

--- Returns every cell in the buffer as {start, end} pairs, 1-based inclusive.
--- A cell is a run of lines separated by delimiter lines matching `delim`.
local function cell_ranges(bufnr, delim)
	bufnr = bufnr or 0
	local last = vim.api.nvim_buf_line_count(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, last, false)

	local delims = {}
	for i, line in ipairs(lines) do
		if vim.fn.match(line, delim) ~= -1 then
			delims[#delims + 1] = i
		end
	end

	local cells = {}
	local prev = 0
	for _, d in ipairs(delims) do
		if prev + 1 <= d - 1 then
			cells[#cells + 1] = { prev + 1, d - 1 }
		end
		prev = d
	end
	if prev + 1 <= last then
		cells[#cells + 1] = { prev + 1, last }
	end
	return cells
end

-- I adopted this design purely out of necessity.
-- Because of the buffer limitation of pty
local function send_to_cursor()
	if not vim.b.slimu_config then
		vim.api.nvim_echo({
			{ "connection didn't set, please run :SlimuConfig first", "WarningMsg" },
		}, true, {})
		return
	end
	local delim = util.resolve("cell_delimiter")
	if delim == nil then
		vim.api.nvim_echo({
			{ "cell_delimiter isn't configured", "WarningMsg" },
		}, true, {})

		return
	end

	local cursor_line = vim.api.nvim_win_get_cursor(0)[1]

	for _, cell in ipairs(cell_ranges(0, delim)) do
		local s, e = cell[1], cell[2]
		if s > cursor_line then
			break
		end
		send_range(s, math.min(e, cursor_line))
		if e >= cursor_line then
			break
		end
	end
end

M.config = slimu_config
M.send_line = send_line
M.send_range = send_range
M.send_cell = send_cell
M.send_selection = send_selection
M.send_to_cursor = send_to_cursor
M.target_names = function()
	return vim.tbl_keys(Targets)
end

return M
