local BufHelpers = require("agentic.utils.buf_helpers")
local Config = require("agentic.config")
local WindowDecoration = require("agentic.ui.window_decoration")
local WidgetLayout = require("agentic.ui.widget_layout")

local FLOAT_BORDER_HEIGHT = 2

--- @class agentic.ui.PromptFloat
--- @field tab_page_id integer
--- @field buf_nrs agentic.ui.ChatWidget.BufNrs
--- @field _input_winid number|nil
--- @field _files_winid number|nil
--- @field _close_callback? fun(): nil
local PromptFloat = {}
PromptFloat.__index = PromptFloat

--- @param tab_page_id integer
--- @param buf_nrs agentic.ui.ChatWidget.BufNrs
--- @param close_callback fun(): nil
--- @return agentic.ui.PromptFloat
function PromptFloat:new(tab_page_id, buf_nrs, close_callback)
    local instance = setmetatable({
        tab_page_id = tab_page_id,
        buf_nrs = buf_nrs,
        _input_winid = nil,
        _files_winid = nil,
        _close_callback = close_callback,
    }, self)

    return instance
end

--- @return boolean
function PromptFloat:is_open()
    local input_winid = self._input_winid
    return input_winid ~= nil and vim.api.nvim_win_is_valid(input_winid)
end

--- @return number|nil
function PromptFloat:get_input_winid()
    if self._input_winid and vim.api.nvim_win_is_valid(self._input_winid) then
        return self._input_winid
    end
end

--- @return number|nil
function PromptFloat:get_files_winid()
    if self._files_winid and vim.api.nvim_win_is_valid(self._files_winid) then
        return self._files_winid
    end
end

function PromptFloat:_bind_float_keymaps(bufnr)
    BufHelpers.keymap_set(bufnr, "n", "<Tab>", function()
        local current_winid = vim.api.nvim_get_current_win()
        local input_winid = self:get_input_winid()
        local files_winid = self:get_files_winid()

        if current_winid == input_winid and files_winid then
            vim.api.nvim_set_current_win(files_winid)
            return
        end

        if current_winid == files_winid and input_winid then
            vim.api.nvim_set_current_win(input_winid)
        end
    end, { desc = "Agentic: Switch detached float panel" })
end

--- @return integer width
function PromptFloat:_calculate_width()
    return WidgetLayout.calculate_width(Config.windows.width)
end

--- @return integer row
--- @return integer col
--- @return integer width
--- @return integer files_height
--- @return integer input_height
function PromptFloat:_get_layout()
    local width = math.max(30, self:_calculate_width())
    local input_height = math.max(3, Config.windows.input.height)
    local files_height = 0

    if not BufHelpers.is_buffer_empty(self.buf_nrs.files) then
        local max_height = math.max(1, Config.windows.files.max_height)
        local line_count = vim.api.nvim_buf_line_count(self.buf_nrs.files)
        files_height = math.min(line_count + 1, max_height)
    end

    local total_height = input_height + FLOAT_BORDER_HEIGHT
    if files_height > 0 then
        total_height = total_height + files_height + FLOAT_BORDER_HEIGHT
    end
    local anchor_row = math.max(0, math.floor((vim.o.lines - total_height) / 2))
    local col = math.max(0, math.floor((vim.o.columns - width) / 2))

    return anchor_row, col, width, files_height, input_height
end

--- @param bufnr integer
--- @param enter boolean
--- @param win_config table<string, any>
--- @param panel_name "files"|"input"
--- @return integer winid
function PromptFloat:_open_or_reuse_window(bufnr, enter, win_config, panel_name)
    local winid
    if panel_name == "input" then
        winid = self._input_winid
    else
        winid = self._files_winid
    end

    if winid and vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_set_config(winid, win_config)
        if enter then
            vim.api.nvim_set_current_win(winid)
        end
        return winid
    end

    winid = vim.api.nvim_open_win(bufnr, enter, win_config)
    if panel_name == "input" then
        self._input_winid = winid
    else
        self._files_winid = winid
    end

    vim.api.nvim_set_option_value("wrap", true, { win = winid })
    vim.api.nvim_set_option_value("linebreak", true, { win = winid })
    vim.api.nvim_set_option_value("winfixbuf", true, { win = winid })
    vim.api.nvim_set_option_value("winfixheight", true, { win = winid })

    WindowDecoration.render_header(bufnr, panel_name)

    if self._close_callback then
        BufHelpers.multi_keymap_set(
            Config.keymaps.widget.close,
            bufnr,
            function()
                self._close_callback()
            end,
            { desc = "Agentic: Close detached prompt float" }
        )
    end

    self:_bind_float_keymaps(bufnr)

    return winid
end

--- @param focus_prompt boolean
function PromptFloat:open(focus_prompt)
    if not vim.api.nvim_tabpage_is_valid(self.tab_page_id) then
        return
    end

    local row, col, width, files_height, input_height = self:_get_layout()
    local zindex = 60

    if files_height > 0 then
        self:_open_or_reuse_window(self.buf_nrs.files, false, {
            relative = "editor",
            style = "minimal",
            border = "rounded",
            row = row,
            col = col,
            width = width,
            height = files_height,
            noautocmd = true,
            zindex = zindex,
        }, "files")
        WindowDecoration.render_header(self.buf_nrs.files, "files")
    else
        self:close_panel("files")
    end

    local input_row = row + files_height
    if files_height > 0 then
        input_row = input_row + FLOAT_BORDER_HEIGHT
    end

    local input_winid =
        self:_open_or_reuse_window(self.buf_nrs.input, focus_prompt == true, {
            relative = "editor",
            style = "minimal",
            border = "rounded",
            row = input_row,
            col = col,
            width = width,
            height = input_height,
            noautocmd = true,
            zindex = zindex,
        }, "input")

    WindowDecoration.render_header(self.buf_nrs.input, "input")

    if
        focus_prompt
        and input_winid
        and vim.api.nvim_win_is_valid(input_winid)
    then
        vim.schedule(function()
            if vim.api.nvim_win_is_valid(input_winid) then
                vim.api.nvim_set_current_win(input_winid)
                BufHelpers.start_insert_on_last_char()
            end
        end)
    end
end

--- @param panel_name "files"|"input"
function PromptFloat:close_panel(panel_name)
    local winid
    if panel_name == "input" then
        winid = self._input_winid
    else
        winid = self._files_winid
    end

    if panel_name == "input" then
        self._input_winid = nil
    else
        self._files_winid = nil
    end

    if winid and vim.api.nvim_win_is_valid(winid) then
        pcall(vim.api.nvim_win_close, winid, true)
    end
end

function PromptFloat:close()
    self:close_panel("input")
    self:close_panel("files")
end

return PromptFloat
