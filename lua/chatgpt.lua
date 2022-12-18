-- main module file
local module = require("chatgpt.module")
local config = require("chatgpt.config")
local api = require("chatgpt.api")
local buffer = require("chatgpt.buffer")

local M = {}

M.setup = function(options)
  config.setup(options)
end

--
-- public methods for the plugin
--

M.openChat = function()
  module.openChat()
end

M.selectAwesomePrompt = function()
  module.open_chat_with_awesome_prompt()
end

M.edit_with_instructions = function()
  module.edit_with_instructions()
end

M.api = api
M.buffer = buffer

return M
