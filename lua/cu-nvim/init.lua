local CU = {}
local Window = require("cu-nvim.window")
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

function CU.handle()
	local data = CU.get_endpoint_data()
	local env = CU.get_endpoint_env()
	CU.render_fuzzy(data, env)
end

function CU.reuse()
	local cmd = vim.g.cureuse
	local output = vim.g.cureuse_output
	CU.execute(cmd, output)
end

function CU.get_endpoint_data()
	local file = io.open("/home/kristiaan/Octo/api_urls", "r")
	local arr = {}
	for line in file:lines() do
		table.insert(arr, line)
	end
	return arr
end

function CU.get_endpoint_env()
	local file = io.open("/home/kristiaan/Octo/api_env", "r")
	local arr = {}
	for line in file:lines() do
		local split_line = vim.fn.split(line, ";")
		local split_trimmed = {}
		for _, split in ipairs(split_line) do
			local trim = vim.fn.trim(split)
			table.insert(split_trimmed, trim)
		end
		table.insert(arr, split_trimmed)
	end
	return arr
end

function CU.render_fuzzy(data, env)
	local fuzzy_cu = function(opts)
		opts = opts or {}
		pickers.new(opts, {
			prompt_title = "Curl Fuzzy Finder",
			finder = finders.new_table({
				results = data,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, _)
				actions.select_default:replace(function()
					actions.close(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					local cmd, output = CU.create_cmd(selection[1], env)
					CU.execute(cmd, output)
					vim.g.cureuse = cmd
					vim.g.cureuse_output = output
				end)
				return true
			end,
			-- TODO: Implement previewr to display columns
			-- previewer = previewers.new_buffer_previewer(opts)
		}):find()
	end
	-- to execute the function
	fuzzy_cu()
end

function CU.create_cmd(selection, env)
	local url = ""
	local key = ""
	local output = ""

	local sections = vim.fn.split(selection, ";")
	for _, api in ipairs(env) do
		if api[1] == vim.fn.trim(sections[1]) then
			url = api[2]
			key = api[3]
			output = api[4]
		end
	end

	local cmd = '"' .. url .. string.sub(vim.fn.trim(sections[2]), 2)
	if key ~= "" then
		cmd = cmd .. ' -H "x-api-key: ' .. key .. '"'
	end

	return cmd, output
end

function CU.execute(cmd, output)
	JobId = vim.fn.jobstart("curl --silent --show-error " .. cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			local all = {}
			if data[1] ~= "" then
				if (string.sub(data[1], 1, 1) == "{" or string.sub(data[1], 1, 1) == "[") and output == "jq" then
					CU.prettify(data, cmd)
				else
					table.insert(all, "curl " .. cmd)
					table.insert(all, "")
					table.insert(all, data[1])
					CU.render(all)
				end
			end
		end,
		on_stderr = function(_, err, _)
			if err[1] ~= "" then
				print("Error: ", vim.inspect(err))
			end
		end,
	})
end

function CU.prettify(resp, cmd)
	JobId = vim.fn.jobstart("jq <<< '" .. resp[1] .. "'", {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data, _)
			local all = {}
			if data[1] ~= "" then
				table.insert(all, "curl " .. cmd)
				table.insert(all, "")
				for _, v in ipairs(data) do
					table.insert(all, v)
				end
				CU.render(all)
			end
		end,
		on_stderr = function(_, err, _)
			if err[1] ~= "" then
				print("Error: ", vim.inspect(err))
			end
		end,
	})
end

function CU.render(data, opts)
	opts = opts or {}
	opts["lines"] = data
	opts["buf"] = vim.g.cubuf
	local window = Window:new(opts)

	if not CU.window_valid() then
		window:create()
		window:fill()
		vim.g.cubuf = window.buf
		vim.g.cuwin = window.win
	else
		window:fill(vim.g.cubuf, vim.g.cuwin)
	end
end

function CU.window_valid()
	if vim.g.cubuf then
		return vim.api.nvim_buf_is_valid(vim.g.cubuf)
	end
	return false
end

return CU
