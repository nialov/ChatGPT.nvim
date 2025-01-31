local M = {}

local Layout = require("nui.layout")
local Popup = require("nui.popup")

local ChatInput = require("chatgpt.input")
local Api = require("chatgpt.api")
local Config = require("chatgpt.config")
local Utils = require("chatgpt.utils")

-- TODO: find the better place
vim.api.nvim_command("hi chatgpt_input_mark ctermfg=gray guifg=gray cterm=italic")

local ns = vim.api.nvim_create_namespace("chatgpt")

local instructions_input, layout, input_window, output_window, output, timer, filetype, bufnr

local show_progress = function()
  local idx = 1
  local chars = { "|", "/", "-", "\\" }
  timer = vim.loop.new_timer()
  timer:start(
    0,
    250,
    vim.schedule_wrap(function()
      local char = chars[idx]
      local line = "[ "
        .. char
        .. " "
        .. Config.options.loading_text
        .. " "
        .. string.rep(".", idx - 1)
        .. string.rep(" ", 4 - idx)
        .. " ]"
      output_window.border:set_text("top", line, "center")
      if idx < 4 then
        idx = idx + 1
      else
        idx = 1
      end
    end)
  )
end

local hide_progress = function()
  if timer ~= nil then
    timer:stop()
    timer = nil
    output_window.border:set_text("top", " Result ", "center")
  end
end

local set_filetype_mark = function()
  local mopts = {
    virt_text = { { " " .. filetype .. " ", "chatgpt_input_mark" } },
    virt_text_pos = "right_align",
    hl_mode = "blend",
  }
  vim.api.nvim_buf_set_extmark(instructions_input.bufnr, ns, 0, 0, mopts)
end

local setup_and_mount = vim.schedule_wrap(function(lines)
  layout:mount()
  -- set input
  vim.api.nvim_buf_set_lines(input_window.bufnr, 0, 0, false, lines)

  -- set input and output settings
  for _, window in ipairs({ input_window, output_window }) do
    vim.api.nvim_buf_set_option(window.bufnr, "filetype", filetype)
    vim.api.nvim_win_set_option(window.winid, "number", true)
  end
end)

M.edit_with_instructions = function()
  local winnr = vim.api.nvim_get_current_win()
  bufnr = vim.api.nvim_win_get_buf(winnr)
  filetype = vim.api.nvim_buf_get_option(bufnr, "filetype")

  local visual_lines, start_row, start_col, end_row, _ = Utils.get_visual_lines(bufnr)
  if not visual_lines then
    visual_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end
  -- TODO: if buffer is empty

  input_window = Popup(Config.options.chat_window)
  output_window = Popup(Config.options.chat_window)
  instructions_input = ChatInput(Config.options.chat_input, {
    prompt = Config.options.chat_input.prompt,
    on_close = function()
      if timer ~= nil then
        timer:stop()
      end
    end,
    on_submit = vim.schedule_wrap(function(instruction)
      show_progress()

      local input = table.concat(vim.api.nvim_buf_get_lines(input_window.bufnr, 0, -1, false), "\n")
      Api.edits(input, instruction, function(output_txt)
        hide_progress()
        output = Utils.split_string_by_line(output_txt)

        vim.api.nvim_buf_set_lines(output_window.bufnr, 0, -1, false, output)
        -- output_window.border:set_text("bottom", " <C-y> to apply changes | <C-i> Use as input ", "center")
      end)
    end),
  })

  layout = Layout(
    Config.options.chat_layout,
    Layout.Box({
      Layout.Box({
        Layout.Box(input_window, { grow = 1 }),
        Layout.Box(instructions_input, { size = 3 }),
      }, { dir = "col", size = "50%" }),
      Layout.Box(output_window, { size = "50%" }),
    }, { dir = "row" })
  )

  instructions_input:map("i", Config.options.keymaps.yank_last, function()
    instructions_input.input_props.on_close()
    Utils.paste(bufnr, start_row, start_col, end_row, output)
    vim.notify("Successfully applied the change!", vim.log.levels.INFO)
  end, { noremap = true })

  instructions_input:map("i", "<C-i>", function()
    local lines = vim.api.nvim_buf_get_lines(output_window.bufnr, 0, -1, false)
    vim.api.nvim_buf_set_lines(input_window.bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_lines(output_window.bufnr, 0, -1, false, {})
  end, { noremap = true })

  setup_and_mount(visual_lines)
end

return M
