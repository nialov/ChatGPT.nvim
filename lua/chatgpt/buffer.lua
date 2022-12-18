local api = require("chatgpt").api

local M = {}

-- Global nvim variable to store the answer buffer number in
M.buf_option = "ChatGPTAnswerBuf"

-- Function to initialize the answer buffer
M.init_answer_buf = function(reset)
  --  Try to get already existing buffer number
  local is_success, persistent_answer_buf = pcall(vim.api.nvim_get_var, M.buf_option)

  -- If does not exist, or reset is wanted or the value is nil
  if not is_success or reset or persistent_answer_buf == nil then
    -- Create the buf
    persistent_answer_buf = vim.api.nvim_create_buf(true, true)
  end
  -- Convert to number
  persistent_answer_buf = tonumber(persistent_answer_buf)

  -- Sanity check
  if persistent_answer_buf == nil then
    error(string.format("Expected persistent_answer_buf to not be nil %s", persistent_answer_buf))
  end

  -- Set the global variable
  vim.api.nvim_set_var(M.buf_option, persistent_answer_buf)

  -- Set buffer type to have no respective file
  vim.api.nvim_buf_set_option(persistent_answer_buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(persistent_answer_buf, "filetype", "markdown")

  -- Set the name of the buffer
  vim.api.nvim_buf_set_name(persistent_answer_buf, M.buf_option)

  -- Return the buffer number integer
  return persistent_answer_buf
end

-- Set lines at the end of the answer buffer
local set_persistent_answer_buf_lines = function(lines)
  -- Get buffer number
  local persistent_answer_buf = M.init_answer_buf(false)

  -- Resolve the current last line number
  local current_buf_lines = vim.api.nvim_buf_get_lines(persistent_answer_buf, 0, -1, true)
  local last_line_number = #current_buf_lines

  -- Set the lines at the end of the answer buffer
  vim.api.nvim_buf_set_lines(persistent_answer_buf, last_line_number + 1, last_line_number + 1, false, lines)
end

-- Callback function to write the answer to the answer buffer
local callback = function(answer)
  -- Sanity check
  if answer == nil then
    set_persistent_answer_buf_lines({ "No return." })
  end

  -- Append the
  local answer_lines = vim.fn.split(answer, "\n")
  set_persistent_answer_buf_lines(answer_lines)
end

M.api_call = function(prompt)
  -- Convert prompt string to lines
  local prompt_lines = vim.fn.split(prompt, "\n")

  -- Insert a header for the prompt
  local prompt_header = "## Prompt"
  table.insert(prompt_lines, 1, "")
  table.insert(prompt_lines, 1, prompt_header)
  table.insert(prompt_lines, 1, "")

  -- Append a header for the answer (answer gets added later by callback)
  local answer_header = "## Answer"
  table.insert(prompt_lines, #prompt_lines, "")
  table.insert(prompt_lines, #prompt_lines, answer_header)
  table.insert(prompt_lines, #prompt_lines, "")

  -- Insert the query formatted with the headers
  set_persistent_answer_buf_lines(prompt_lines)

  assert(prompt ~= nil)
  vim.notify(string.format("Conducting ChatGPT call: %s ...", string.sub(prompt, 1, 10)))

  -- Conduct the actual API call the ChatGPT
  api.completions(prompt, callback)
end

return M
