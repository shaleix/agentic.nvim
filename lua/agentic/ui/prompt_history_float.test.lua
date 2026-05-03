local assert = require("tests.helpers.assert")
local PromptHistory = require("agentic.ui.prompt_history")
local PromptHistoryFloat = require("agentic.ui.prompt_history_float")

describe("agentic.ui.PromptHistoryFloat", function()
    local original_cwd
    local temp_dir

    before_each(function()
        original_cwd = vim.fn.getcwd()
        temp_dir = vim.fn.tempname()
        vim.fn.mkdir(temp_dir, "p")
        vim.cmd("tabnew")
        vim.cmd.cd(temp_dir)
    end)

    after_each(function()
        if original_cwd then
            vim.cmd.cd(original_cwd)
        end

        pcall(function()
            vim.cmd("tabclose")
        end)

        if temp_dir then
            vim.fn.delete(temp_dir, "rf")
        end
    end)

    it(
        "uses a ratio-based height and footer colors from float border and comment",
        function()
            assert.is_true(PromptHistory.append("only one prompt", temp_dir))

            local prompt_history_float = PromptHistoryFloat:new(
                vim.api.nvim_get_current_tabpage(),
                function() end
            )

            prompt_history_float:open()

            local winid = prompt_history_float:get_winid()
            assert.is_not_nil(winid)

            local config = vim.api.nvim_win_get_config(winid)
            local winhighlight =
                vim.api.nvim_get_option_value("winhighlight", { win = winid })
            local footer_hl =
                vim.api.nvim_get_hl(0, { name = "AgenticPromptHistoryFooter" })
            local border_hl = vim.api.nvim_get_hl(0, { name = "FloatBorder" })
            local comment_hl = vim.api.nvim_get_hl(0, { name = "Comment" })

            local expected_height = math.floor(vim.o.lines * 0.6)
            assert.equal(expected_height, config.height)
            assert.truthy(
                winhighlight:match("FloatFooter:AgenticPromptHistoryFooter")
            )
            assert.equal(border_hl.bg, footer_hl.bg)
            assert.equal(comment_hl.fg, footer_hl.fg)

            prompt_history_float:close()
        end
    )
end)
