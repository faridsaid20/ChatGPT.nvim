local job = require("plenary.job")
local Config = require("chatgpt.config")

local Api = {}

-- API URL
-- Api.COMPLETIONS_URL = "https://api.openai.com/v1/completions"
Api.COMPLETIONS_URL =
"https://openai-swce-dev-003.openai.azure.com/openai/deployments/gpt-4-1106-preview/chat/completions?api-version=2023-03-15-preview"

-- Api.CHAT_COMPLETIONS_URL = "https://api.openai.com/v1/chat/completions"
Api.CHAT_COMPLETIONS_URL =
"https://openai-swce-dev-003.openai.azure.com/openai/deployments/gpt-4-1106-preview/chat/completions?api-version=2023-03-15-preview"
-- Api.EDITS_URL = "https://api.openai.com/v1/edits"

Api.EDITS_URL =
"https://openai-swce-dev-003.openai.azure.com/openai/deployments/gpt-4-1106-preview/chat/completions?api-version=2023-03-15-preview"
-- API KEY
Api.OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")
if not Api.OPENAI_API_KEY then
    error("OPENAI_API_KEY environment variable not set")
end

function Api.completions(custom_params, cb)
    local params = vim.tbl_extend("force", custom_params, Config.options.openai_params)
    Api.make_call(Api.CHAT_COMPLETIONS_URL, params, cb)
end

function Api.chat_completions(custom_params, cb)

    -- print("CHAT CUSTOM: " .. vim.fn.json_encode(custom_params))
    -- print("CHAT openAI: " .. vim.fn.json_encode(Config.options.openai_params))
    local params = vim.tbl_extend("force", custom_params, Config.options.openai_params)
    Api.make_call(Api.CHAT_COMPLETIONS_URL, params, cb)
end

function Api.edits(custom_params, cb)
    local params = vim.tbl_extend("force", custom_params, Config.options.openai_edit_params)
    Api.make_call(Api.COMPLETIONS_URL, params, cb)
end

function Api.make_call(url, params, cb)
    TMP_MSG_FILENAME = os.tmpname()
    local f = io.open(TMP_MSG_FILENAME, "w+")
    if f == nil then
        vim.notify("Cannot open temporary message file: " .. TMP_MSG_FILENAME, vim.log.levels.ERROR)
        return
    end
    -- print("TMP_MSG_FILENAME SEND: " .. vim.fn.json_encode(params))
    -- print("OPENAI_API_KEY: " .. Api.OPENAI_API_KEY)
    f:write(vim.fn.json_encode(params))
    f:close()
    -- print 
    -- ("TMP_MSG_FILENAME con:tent: " .. vim.fn.json_encode(vim.fn.readfile(TMP_MSG_FILENAME)))
    Api.job = job
        :new({
            command = "curl",
            args = {
                url,
                "-H",
                "Content-Type: application/json",
                "-H",
                "api-key: " .. Api.OPENAI_API_KEY,
                "-d",
                "@" .. TMP_MSG_FILENAME,
            },
            on_exit = vim.schedule_wrap(function(response, exit_code)
                Api.handle_response(response, exit_code, cb)
            end),
        })
        :start()
end

Api.handle_response = vim.schedule_wrap(function(response, exit_code, cb)
    os.remove(TMP_MSG_FILENAME)
    if exit_code ~= 0 then
        vim.notify("An Error Occurred ...", vim.log.levels.ERROR)
        cb("ERROR: API Error")
    end

    local result = table.concat(response:result(), "\n")
    --print("Result: " .. result)
    local json = vim.fn.json_decode(result)
    -- print("JSON: " .. result)
    if json == nil then
        cb("No Response.")
    elseif json.error then
        cb("// API ERROR: " .. json.error.message)
    else
        local message = json.choices[1].message
        if message ~= nil then
            local response_text = json.choices[1].message.content
            if type(response_text) == "string" and response_text ~= "" then
                cb(response_text, json.usage)
            else
                cb("...")
            end
        else
            local response_text = json.choices[1].text
            if type(response_text) == "string" and response_text ~= "" then
                cb(response_text, json.usage)
            else
                cb("...")
            end
        end
    end
end)

function Api.close()
    if Api.job then
        job:shutdown()
    end
end

return Api
