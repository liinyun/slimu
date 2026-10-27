local M = {}

M.defaults = { cell_delimiter = nil, target = "zmx" }

function M.resolve(key)
	local buf = vim.b["slimu_" .. key]
	if buf ~= nil then
		return buf
	end
	local glob = vim.g["slimu_" .. key]
	if glob ~= nil then
		return glob
	end
	return M.defaults[key]
end

--- Run argv, optionally feeding stdin, notify on failure, return stdout.
function M.system(argv, input)
	local result = vim.system(argv, { text = true, stdin = input }):wait()

	if result.code ~= 0 then
		vim.notify(("slimu: %s failed (code %d)\n%s"):format(argv[1], result.code, result.stderr), vim.log.levels.WARN)
	end

	return result.stdout
end

--- Wrap text in bracketed-paste markers, stripping one trailing newline.
--- Returns (payload, had_newline).
-- lua/slimu/util.lua
function M.bracketed_paste(text)
	local trimmed = text:gsub("(\r\n|\r|\n)$", "")
	local had = #trimmed ~= #text
	return {
		raw = trimmed,
		wrapped = "\27[200~" .. trimmed .. "\27[201~",
		had_newline = had,
	}
end

function M.get_config()
	local config = vim.b.slimu_config

	if not config or not config.target or not config[config.target] or not config[config.target].session then
		vim.api.nvim_echo({
			{ "connection didn't set, please run :SlimuConfig to configure", "WarningMsg" },
		}, true, {})
		return nil
	end

	return config[config.target].session
end

return M
