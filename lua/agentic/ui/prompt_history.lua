local FileSystem = require("agentic.utils.file_system")

--- @class agentic.ui.PromptHistory.Data
--- @field version integer
--- @field prompts string[]

--- @class agentic.ui.PromptHistory
local PromptHistory = {}

local HISTORY_DIR_NAME = "agentic.nvim"
local HISTORY_FILE_PREFIX = "prompt-history"

--- @param cwd string|nil
--- @return string resolved_cwd
local function resolve_cwd(cwd)
    return cwd or vim.fn.getcwd()
end

--- @param cwd string
--- @return string name
local function build_file_name(cwd)
    local base_name = vim.fn.fnamemodify(cwd, ":t")
    if base_name == "" then
        base_name = "root"
    end

    local safe_name = base_name:gsub("[^%w%-_]", "_")
    local hash = vim.fn.sha256(cwd):sub(1, 12)

    return string.format("%s-%s-%s.json", HISTORY_FILE_PREFIX, safe_name, hash)
end

--- @param path string
--- @return agentic.ui.PromptHistory.Data
local function read_data(path)
    local file = io.open(path, "r")
    if not file then
        return {
            version = 1,
            prompts = {},
        }
    end

    local content = file:read("*a")
    file:close()

    if content == nil or content == "" then
        return {
            version = 1,
            prompts = {},
        }
    end

    local ok, decoded = pcall(vim.json.decode, content)
    if
        not ok
        or type(decoded) ~= "table"
        or type(decoded.prompts) ~= "table"
    then
        return {
            version = 1,
            prompts = {},
        }
    end

    local prompts = {}
    for _, prompt in ipairs(decoded.prompts) do
        if type(prompt) == "string" then
            table.insert(prompts, prompt)
        end
    end

    return {
        version = 1,
        prompts = prompts,
    }
end

--- @param cwd string|nil
--- @return string path
function PromptHistory.get_file_path(cwd)
    local resolved_cwd = resolve_cwd(cwd)
    local temp_dir = vim.uv.os_tmpdir() or vim.fn.stdpath("cache")
    local history_dir = temp_dir .. "/" .. HISTORY_DIR_NAME
    FileSystem.mkdirp(history_dir)

    return history_dir .. "/" .. build_file_name(resolved_cwd)
end

--- @param cwd string|nil
--- @return string[] prompts
function PromptHistory.read(cwd)
    local path = PromptHistory.get_file_path(cwd)
    return read_data(path).prompts
end

--- @param prompt string
--- @param cwd string|nil
--- @return boolean success
function PromptHistory.append(prompt, cwd)
    local path = PromptHistory.get_file_path(cwd)
    local data = read_data(path)
    table.insert(data.prompts, prompt)

    local success = FileSystem.save_to_disk(path, vim.json.encode(data))
    return success
end

--- @param prompt string
--- @param max_width integer|nil
--- @return string line
function PromptHistory.to_display_line(prompt, max_width)
    local line = prompt:gsub("\n", "\\n")
    local width = max_width or 80

    if vim.fn.strdisplaywidth(line) <= width then
        return line
    end

    local target_width = math.max(0, width - 3)
    local truncated = line

    while
        truncated ~= "" and vim.fn.strdisplaywidth(truncated) > target_width
    do
        local char_count = vim.fn.strchars(truncated)
        truncated = vim.fn.strcharpart(truncated, 0, char_count - 1)
    end

    return truncated .. "..."
end

return PromptHistory
