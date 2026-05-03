local BufHelpers = require("agentic.utils.buf_helpers")
local Logger = require("agentic.utils.logger")
local PromptHistory = require("agentic.ui.prompt_history")

local HEIGHT_RATIO = 0.6
local FOOTER_HL = "AgenticPromptHistoryFooter"

--- @class agentic.ui.PromptHistoryFloat.Entry
--- @field prompt string
--- @field display string

--- @class agentic.ui.PromptHistoryFloat
--- @field tab_page_id integer
--- @field _on_select fun(prompt: string): nil
--- @field _winid number|nil
--- @field _bufnr integer|nil
--- @field _entries agentic.ui.PromptHistoryFloat.Entry[]
local PromptHistoryFloat = {}
PromptHistoryFloat.__index = PromptHistoryFloat

local function ensure_footer_highlight()
    local footer_hl = vim.api.nvim_get_hl(0, { name = FOOTER_HL })
    if vim.tbl_count(footer_hl) > 0 then
        return
    end

    local border_hl = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
    local comment_hl = vim.api.nvim_get_hl(0, { name = "Comment" })

    vim.api.nvim_set_hl(0, FOOTER_HL, {
        bg = border_hl.bg,
        fg = comment_hl.fg,
    })
end

--- @param tab_page_id integer
--- @param on_select fun(prompt: string): nil
--- @return agentic.ui.PromptHistoryFloat
function PromptHistoryFloat:new(tab_page_id, on_select)
    return setmetatable({
        tab_page_id = tab_page_id,
        _on_select = on_select,
        _winid = nil,
        _bufnr = nil,
        _entries = {},
    }, self)
end

--- @return number|nil
function PromptHistoryFloat:get_winid()
    local winid = self._winid
    if winid and vim.api.nvim_win_is_valid(winid) then
        return winid
    end
end

--- @return integer|nil
function PromptHistoryFloat:_ensure_buffer()
    local bufnr = self._bufnr
    if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
        return bufnr
    end

    bufnr = vim.api.nvim_create_buf(false, true)
    self._bufnr = bufnr

    vim.bo[bufnr].bufhidden = "wipe"
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].modifiable = false
    vim.bo[bufnr].filetype = "AgenticPromptHistory"

    BufHelpers.keymap_set(bufnr, "n", "q", function()
        self:close()
    end, { desc = "Agentic: Close prompt history" })
    BufHelpers.keymap_set(bufnr, "n", "<Esc>", function()
        self:close()
    end, { desc = "Agentic: Close prompt history" })
    BufHelpers.keymap_set(bufnr, "n", "<CR>", function()
        self:_select_current_entry()
    end, { desc = "Agentic: Use selected prompt history entry" })

    return bufnr
end

--- @return integer width
function PromptHistoryFloat:_calculate_width()
    return math.max(40, math.min(120, math.floor(vim.o.columns * 0.7)))
end

--- @param display_lines string[]
function PromptHistoryFloat:_render_buffer(display_lines)
    local bufnr = self:_ensure_buffer()
    if not bufnr then
        return
    end

    BufHelpers.with_modifiable(bufnr, function()
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, display_lines)
    end)
end

function PromptHistoryFloat:_select_current_entry()
    local winid = self:get_winid()
    if not winid then
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(winid)
    local entry = self._entries[cursor[1]]
    if not entry then
        return
    end

    self:close()
    self._on_select(entry.prompt)
end

function PromptHistoryFloat:open()
    if not vim.api.nvim_tabpage_is_valid(self.tab_page_id) then
        return
    end

    local prompts = PromptHistory.read()
    if #prompts == 0 then
        Logger.notify("No saved prompt history found", vim.log.levels.INFO)
        return
    end

    self._entries = {}
    local width = self:_calculate_width()
    local display_lines = {}

    for index = #prompts, 1, -1 do
        local prompt = prompts[index]
        local display_index = #prompts - index + 1
        local number_prefix = display_index .. ". "
        local prefix_width = vim.fn.strdisplaywidth(number_prefix)
        local display =
            PromptHistory.to_display_line(prompt, width - 4 - prefix_width)
        local full_display = number_prefix .. display
        table.insert(self._entries, {
            prompt = prompt,
            display = full_display,
        })
        table.insert(display_lines, full_display)
    end

    self:_render_buffer(display_lines)

    local bufnr = self:_ensure_buffer()
    if not bufnr then
        return
    end

    local height = math.floor(vim.o.lines * HEIGHT_RATIO)
    local row = math.max(0, math.floor((vim.o.lines - (height + 2)) / 2))
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))

    local winid = self:get_winid()
    local config = {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        row = row,
        col = col,
        width = width,
        height = height,
        title = " Prompt History ",
        title_pos = "center",
        footer = " <CR>: use | q: close ",
        footer_pos = "right",
        noautocmd = true,
        zindex = 65,
    }

    if winid then
        vim.api.nvim_win_set_config(winid, config)
        vim.api.nvim_set_current_win(winid)
    else
        self._winid = vim.api.nvim_open_win(bufnr, true, config)
    end

    if self._winid and vim.api.nvim_win_is_valid(self._winid) then
        ensure_footer_highlight()
        vim.wo[self._winid].wrap = false
        vim.wo[self._winid].linebreak = false
        vim.wo[self._winid].cursorline = true
        vim.api.nvim_set_option_value(
            "winhighlight",
            "FloatFooter:" .. FOOTER_HL,
            { win = self._winid }
        )
        vim.api.nvim_win_set_cursor(self._winid, { 1, 0 })
    end
end

function PromptHistoryFloat:close()
    local winid = self._winid
    self._winid = nil

    if winid and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_close, winid, true)
    end
end

return PromptHistoryFloat
