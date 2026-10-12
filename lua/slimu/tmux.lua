local util = require("slimu.util")

local M = {}

M.defaults = { socket_name = "default", target_pane = "" }

--- Build the tmux argv prefix from a socket name.
--- Absolute path -> { "tmux", "-S", path }; otherwise { "tmux", "-L", name }.
local function target_cmd(socket_name)
	if socket_name:sub(1, 1) == "/" then
		return { "tmux", "-S", socket_name }
	end
	return { "tmux", "-L", socket_name }
end

--- Run a tmux subcommand. `args` is a list of strings appended to the prefix.
--- `input` is optional stdin.
local function run(cfg, args, input)
	local argv = vim.list_extend(target_cmd(cfg.socket_name), args)
	return util.system(argv, input)
end

local function run_silent(cfg, args, input)
	local argv = target_cmd(cfg.socket_name)
	vim.list_extend(argv, args)
	return vim.system(argv, { text = true, stdin = input }):wait()
end

M.send = function(cfg, text)
	-- 1. strip one trailing newline, remember whether there was one
	local trimmed = text:gsub("(\r\n|\r|\n)$", "")
	local had_newline = #trimmed ~= #text
	if #trimmed == 0 then
		return
	end

	local t = cfg.target_pane

	-- 2. leave copy-mode / any mode on the target pane
	run(cfg, { "send-keys", "-X", "-t", t, "cancel" })

	-- 3. chunk + paste
	local chunk_size = 1000
	for i = 1, #trimmed, chunk_size do
		local chunk = trimmed:sub(i, i + chunk_size - 1)
		run(cfg, { "load-buffer", "-" }, chunk)

		if cfg.bracketed then
			run(cfg, { "paste-buffer", "-d", "-p", "-t", t })
		else
			run(cfg, { "paste-buffer", "-d", "-t", t })
		end
	end

	-- 4. trailing newline as Enter
	if had_newline then
		-- run(cfg, { "send-keys", "-t", t, "Enter" })
		run_silent(cfg, { "send-keys", "-X", "-t", t, "cancel" })
	end
end

M.configure = function(cfg)
	vim.ui.input({ prompt = "tmux socket name or path: ", default = cfg.socket_name }, function(name)
		if name == nil then
			return
		end
		cfg.socket_name = name

		local panes = M.list_panes(cfg)
		vim.ui.select(panes, {
			prompt = "tmux target pane:",
			format_item = function(item)
				return item
			end,
		}, function(choice)
			if choice == nil then
				return
			end
			-- vim-slime parity: take first whitespace-delimited token
			cfg.target_pane = vim.split(choice, "%s+")[1]
			vim.notify(("slimu tmux: %s @ %s"):format(cfg.target_pane, cfg.socket_name))
		end)
	end)
end

M.list_panes = function(cfg)
	local out = run(cfg, {
		"list-panes",
		"-a",
		"-F",
		"#{pane_id} #{session_name}:#{window_index}.#{pane_index} #{window_name}#{?window_active, (active),}",
	})
	return vim.split(out or "", "\n", { trimempty = true })
end

return M
