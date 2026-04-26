local assert = require("tests.helpers.assert")
local spy = require("tests.helpers.spy")

local SessionRegistry = require("agentic.session_registry")

describe("agentic.open_prompt_float", function()
    local get_session_stub

    after_each(function()
        if get_session_stub then
            get_session_stub:revert()
            get_session_stub = nil
        end
    end)

    it("opens the detached prompt float for the current tab session", function()
        local show_prompt_float_spy = spy.new(function() end)

        get_session_stub = spy.stub(SessionRegistry, "get_session_for_tab_page")
        get_session_stub:invokes(function(_tab_page_id, callback)
            callback({
                widget = {
                    show_prompt_float = show_prompt_float_spy,
                },
            })
        end)

        require("agentic").open_prompt_float({ focus_prompt = false })

        assert.spy(show_prompt_float_spy).was.called(1)
        local call_args = show_prompt_float_spy.calls[1]
        assert.equal(false, call_args[2].focus_prompt)
    end)
end)

describe("agentic.open_prompt_history", function()
    local get_session_stub

    after_each(function()
        if get_session_stub then
            get_session_stub:revert()
            get_session_stub = nil
        end
    end)

    it("opens the prompt history float for the current tab session", function()
        local show_prompt_history_spy = spy.new(function() end)

        get_session_stub = spy.stub(SessionRegistry, "get_session_for_tab_page")
        get_session_stub:invokes(function(_tab_page_id, callback)
            callback({
                widget = {
                    show_prompt_history = show_prompt_history_spy,
                },
            })
        end)

        require("agentic").open_prompt_history()

        assert.spy(show_prompt_history_spy).was.called(1)
    end)
end)
