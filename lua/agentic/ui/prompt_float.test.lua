local assert = require("tests.helpers.assert")
local Config = require("agentic.config")
local PromptFloat = require("agentic.ui.prompt_float")

describe("agentic.ui.PromptFloat", function()
    local original_width
    local original_input_height

    --- @param position number|table
    --- @return number
    local function unwrap_position(position)
        if type(position) == "table" then
            return position[false]
        end
        return position
    end

    before_each(function()
        original_width = Config.windows.width
        original_input_height = Config.windows.input.height
    end)

    after_each(function()
        Config.windows.width = original_width
        Config.windows.input.height = original_input_height
    end)

    it("centers the detached prompt in the editor", function()
        Config.windows.width = 80
        Config.windows.input.height = 6

        local input_bufnr = vim.api.nvim_create_buf(false, true)
        local files_bufnr = vim.api.nvim_create_buf(false, true)
        local prompt_float = PromptFloat:new(
            vim.api.nvim_get_current_tabpage(),
            {
                input = input_bufnr,
                files = files_bufnr,
            },
            function() end
        )

        prompt_float:open(false)

        local input_winid = prompt_float:get_input_winid()
        assert.is_not_nil(input_winid)

        local config = vim.api.nvim_win_get_config(input_winid)

        assert.equal(
            math.floor((vim.o.lines - (6 + 2)) / 2),
            unwrap_position(config.row)
        )
        assert.equal(
            math.floor((vim.o.columns - 80) / 2),
            unwrap_position(config.col)
        )
        assert.equal(80, config.width)
        assert.equal(6, config.height)

        prompt_float:close()
    end)
end)
