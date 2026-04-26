local assert = require("tests.helpers.assert")

describe("agentic.ui.PromptHistory", function()
    local PromptHistory = require("agentic.ui.prompt_history")

    local temp_dir
    local original_cwd

    before_each(function()
        temp_dir = vim.fn.tempname()
        vim.fn.mkdir(temp_dir, "p")
        original_cwd = vim.fn.getcwd()
    end)

    after_each(function()
        if original_cwd then
            vim.cmd.lcd(original_cwd)
        end

        if temp_dir then
            vim.fn.delete(temp_dir, "rf")
        end
    end)

    it("uses different temp json files for different cwd values", function()
        local path_a = PromptHistory.get_file_path("/tmp/project-a")
        local path_b = PromptHistory.get_file_path("/tmp/project-b")

        assert.are_not.equal(path_a, path_b)
        assert.truthy(path_a:match("%.json$"))
        assert.truthy(path_b:match("%.json$"))
        assert.truthy(vim.startswith(path_a, vim.uv.os_tmpdir()))
        assert.truthy(vim.startswith(path_b, vim.uv.os_tmpdir()))
    end)

    it("appends submitted prompts and reads them back from json", function()
        local cwd = temp_dir .. "/project"
        vim.fn.mkdir(cwd, "p")

        assert.is_true(PromptHistory.append("first line", cwd))
        assert.is_true(PromptHistory.append("hello\nworld", cwd))

        local prompts = PromptHistory.read(cwd)

        assert.equal(2, #prompts)
        assert.equal("first line", prompts[1])
        assert.equal("hello\nworld", prompts[2])
    end)

    it("escapes newlines and truncates long display lines", function()
        local display =
            PromptHistory.to_display_line("line 1\nline 2 is very long", 16)

        assert.equal("line 1\\nline ...", display)
    end)
end)
