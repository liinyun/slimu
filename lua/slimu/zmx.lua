local util = require("slimu.util")

local M = {}

M.defaults = { target = "zmx", session = "ipython", cell_delimiter = "#%%" }

function M.bracketed_paste(text)
	local trimmed = text:gsub("(\r\n|\r|\n)$", "")
	local had = #trimmed ~= #text
	return "\27[200~" .. trimmed .. "\27[201~", had
end

M.send = function(cfg, text)
	local wrapped, had_newline = M.bracketed_paste(text)
	util.system({ "zmx", "send", cfg.session }, wrapped)
	-- if had_newline then
	util.system({ "zmx", "send", cfg.session }, "\r")
	-- end
end

-- M.configure = function(cfg)
-- 	vim.ui.input({ prompt = "zmx session: ", default = cfg.session }, function(text)
-- 		if text == nil or text == "" then
-- 			return
-- 		end
--
-- 		cfg.session = text
-- 		local c = vim.b.slimu_config or {} -- read (copy)
-- 		c.zmx = cfg
-- 		vim.b.slimu_config = c
--
-- 		-- print(vim.inspect(cfg))
-- 		-- print(vim.inspect(c))
-- 		-- print(vim.inspect(vim.b.slimu_config.zmx))
-- 		-- print(vim.inspect(vim.b.slimu_config))
--
-- 		vim.notify("slimu zmx session: " .. text)
-- 	end)
-- end

M.list_sessions = function(cfg)
	local out = util.system({ "zmx", "list" })
	return vim.split(out or "", "\n", { trimempty = true })
end

M.configure = function(cfg)
	vim.ui.select(M.list_sessions(cfg), {
		prompt = "zmx session:",
		format_item = function(item)
			return item:match("name=([^\t]+)") or item
		end,
	}, function(choice)
		if choice == nil then
			print("choise is nil, you should input number next time")
			return
		end
		local name = choice:match("name=([^\t]+)")
		if not name then
			return
		end
		cfg.session = name
		local c = vim.b.slimu_config or {} -- read (copy)
		c.zmx = cfg
		vim.b.slimu_config = c

		-- print(vim.inspect(name))
		-- print(vim.inspect(cfg))
		-- print(vim.inspect(c))
		-- print(vim.inspect(vim.b.slimu_config.zmx))
		-- print(vim.inspect(vim.b.slimu_config))
		vim.notify("slimu zmx session: " .. name)
	end)
end

return M
