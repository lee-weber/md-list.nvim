local M = {}

-- Configuration with default values
M.config = {
  -- List markers to recognize and continue
  list_markers = {
    -- Unordered list markers
    "-", "*", "+", ">",
    -- Ordered list markers will be detected by pattern
  },
  -- Marker to use for new lists after a colon (defaults to first marker in list_markers)
  colon_list_marker = nil,
  -- Filetypes where the plugin should be active
  filetypes = { "markdown", "text" }
}

local function get_marker_for_indent(level)
  return M.config.list_markers[math.min(level, #M.config.list_markers + 1) + 1]
end

-- Check if the current line is a list item and return its components
local function parse_list_item(line)
  -- Check for unordered list items (*, -, +, >) that end with a colon
  for _, marker in ipairs(M.config.list_markers) do
    local pattern = "^(%s*)(" .. vim.pesc(marker) .. "%s+)(.+):$"
    local indent, prefix, content = line:match(pattern)
    if indent and prefix and content then
      return {
        type = "unordered_colon",
        indent = indent,
        marker = marker,
        prefix = prefix,
        content = content,
        empty = false
      }
    end
  end
  
  -- Check for ordered list items (1., 1), etc.) that end with a colon
  local indent, number, separator, content = line:match("^(%s*)(%d+)([.)])%s+(.+):$")
  if indent and number and separator and content then
    return {
      type = "ordered_colon",
      indent = indent,
      number = tonumber(number),
      separator = separator,
      prefix = number .. separator .. " ",
      content = content,
      empty = false
    }
  end
  
  -- Check for unordered list items (*, -, +, >)
  for _, marker in ipairs(M.config.list_markers) do
    local pattern = "^(%s*)(" .. vim.pesc(marker) .. "%s+)(.*)$"
    local indent, prefix, content = line:match(pattern)
    if indent and prefix then
      return {
        type = "unordered",
        indent = indent,
        marker = marker,
        prefix = prefix,
        content = content or "",
        empty = (content or "") == ""
      }
    end
  end
  
  -- Check for ordered list items (1., 1), etc.)
  local indent, number, separator, content = line:match("^(%s*)(%d+)([.)])%s+(.*)$")
  if indent and number and separator then
    return {
      type = "ordered",
      indent = indent,
      number = tonumber(number),
      separator = separator,
      prefix = number .. separator .. " ",
      content = content or "",
      empty = (content or "") == ""
    }
  end
  
  -- Check for colon-terminated lines (special case for sublists)
  local indent, content = line:match("^(%s*)(.+):$")
  if indent and content then
    return {
      type = "colon",
      indent = indent,
      content = content,
      empty = false
    }
  end
  
  return nil
end

-- Get the marker to use for colon-based lists
local function get_colon_marker()
  -- If a specific colon list marker is set, use it
  if M.config.colon_list_marker then
    return M.config.colon_list_marker
  end
  
  -- Otherwise, use the first marker from the list_markers config
  return M.config.list_markers[1]
end

-- Handle <CR> keypress
function M.handle_cr()
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  
  local list_item = parse_list_item(line)
  if not list_item then
    -- Not a list item, use default <CR> behavior
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), 'n', true)
  end
  
  -- Special handling for colon-terminated lines (both regular and list items)
  if list_item.type == "colon" or list_item.type == "unordered_colon" or list_item.type == "ordered_colon" then
    -- Create an indented list item below
    local indent_unit = vim.o.expandtab and string.rep(" ", vim.o.shiftwidth) or "\t"
    local new_indent = list_item.indent .. indent_unit
    
    -- Get the marker for colon-based lists
    local level = math.floor(#new_indent / #indent_unit)
    local marker = get_marker_for_indent(level)

    local new_item = new_indent .. marker .. " "
    
    -- Insert the new list item on the next line
    vim.api.nvim_buf_set_lines(0, line_nr, line_nr, false, {new_item})
    -- Position cursor at the end of the new list item prefix
    vim.api.nvim_win_set_cursor(0, {line_nr + 1, #new_item})
    -- Enter insert mode
    vim.cmd("startinsert")
    return ""
  end
  
  if list_item.empty then
    -- Empty list item
    if #list_item.indent > 0 then
      -- Indented empty list item - unindent it
      local indent_unit = list_item.indent:match("^\t+$") and "\t" or "  "
      local reduced_indent = list_item.indent:sub(1, #list_item.indent - #indent_unit)
      
      -- Create a new list item with reduced indentation
      local new_item
      if list_item.type == "unordered" then
        new_item = reduced_indent .. list_item.marker .. " "
      else
        -- For ordered lists, find the next number at the reduced indentation level
        local next_num = find_next_ordered_number(reduced_indent, line_nr)
        new_item = reduced_indent .. next_num .. list_item.separator .. " "
      end
      
      vim.api.nvim_set_current_line(new_item)
      -- Position cursor at the end of the new list item
      vim.api.nvim_win_set_cursor(0, {line_nr, #new_item})
      return ""
    else
      -- Non-indented empty list item - remove it completely
      vim.api.nvim_set_current_line("")
      return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<CR>", true, false, true), 'n', true)
    end
  end
  
  -- Create the new list item with the same indentation
  local new_item
  if list_item.type == "unordered" then
    new_item = list_item.indent .. list_item.marker .. " "
  else
    new_item = list_item.indent .. (list_item.number + 1) .. list_item.separator .. " "
  end
  
  -- Insert the new list item on the next line
  vim.api.nvim_buf_set_lines(0, line_nr, line_nr, false, {new_item})
  -- Position cursor at the end of the new list item prefix
  vim.api.nvim_win_set_cursor(0, {line_nr + 1, #new_item})
  -- Enter insert mode
  vim.cmd("startinsert")
  return ""
end

-- Handle 'o' keypress
function M.handle_o()
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local list_item = parse_list_item(line)
  
  if not list_item then
    -- Not a list item, use default 'o' behavior
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("o", true, false, true), 'n', true)
  end
  
  -- Special handling for colon-terminated lines (both regular and list items)
  if list_item.type == "colon" or list_item.type == "unordered_colon" or list_item.type == "ordered_colon" then
    -- Create an indented list item below
    local indent_unit = vim.o.expandtab and string.rep(" ", vim.o.shiftwidth) or "\t"
    local new_indent = list_item.indent .. indent_unit
    
    -- Get the marker for colon-based lists
    local marker = get_colon_marker()
    local new_item = new_indent .. marker .. " "
    
    -- Insert the new list item on the next line
    vim.api.nvim_buf_set_lines(0, line_nr, line_nr, false, {new_item})
    -- Position cursor at the end of the new list item prefix
    vim.api.nvim_win_set_cursor(0, {line_nr + 1, #new_item})
    -- Enter insert mode
    vim.cmd("startinsert")
    return ""
  end
  
  -- Create the new list item
  local new_item
  if list_item.type == "unordered" then
    new_item = list_item.indent .. list_item.marker .. " "
  else
    new_item = list_item.indent .. (list_item.number + 1) .. list_item.separator .. " "
  end
  
  -- Insert a new line below the current line
  vim.api.nvim_buf_set_lines(0, line_nr, line_nr, false, {new_item})
  
  -- Position cursor at the end of the new list item
  vim.api.nvim_win_set_cursor(0, {line_nr + 1, #new_item})
  
  -- Enter insert mode
  vim.cmd("startinsert")
  
  return ""
end

-- Handle 'O' keypress
function M.handle_O()
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local list_item = parse_list_item(line)
  if not list_item then
    -- Not a list item, use default 'O' behavior
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("O", true, false, true), 'n', true)
  end
  -- Special handling for colon-terminated lines
  if list_item.type == "colon" or list_item.type == "unordered_colon" or list_item.type == "ordered_colon" then
    -- For colon lines, just use the default 'O' behavior
    return vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("O", true, false, true), 'n', true)
  end
  -- Create the new list item
  local new_item
  if list_item.type == "unordered" then
    new_item = list_item.indent .. list_item.marker .. " "
  else
    -- For ordered lists, use the same number and adjust the current line's number
    new_item = list_item.indent .. list_item.number .. list_item.separator .. " "
    -- Update the current line's number if it's an ordered list
    if list_item.type == "ordered" then
      local updated_line = list_item.indent .. (list_item.number + 1) .. list_item.separator .. " " .. list_item.content
      vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, {updated_line})
    end
  end
  -- Insert a new line above the current line
  vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr - 1, false, {new_item})
  -- Position cursor at the end of the new list item
  vim.api.nvim_win_set_cursor(0, {line_nr, #new_item})
  -- Enter insert mode
  vim.cmd("startinsert")
  return ""
end

-- Handle <Tab> and <S-Tab> keypresses for list indentation 
function M.handle_Tab(reverse)
  local line_nr = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_get_current_line()
  local list_item = parse_list_item(line)
  if not list_item then
    -- Not a list item, use default behavior
    return "<Tab>"
  end
  local indent_unit = vim.o.expandtab and string.rep(" ", vim.o.shiftwidth) or "\t"
  local new_indent
  if reverse then
    -- Unindent (Shift+Tab): only if enough indent exists
    if #list_item.indent >= #indent_unit then
      new_indent = list_item.indent:sub(1, #list_item.indent - #indent_unit)
    else
      new_indent = ""
    end
    else
      -- Indent (Tab)
      new_indent = list_item.indent .. indent_unit
  end
  -- Decide marker adaptively based on indent depth
  local level = math.floor(#new_indent / #indent_unit)
  local new_marker = get_marker_for_indent(level)
  -- Rebuild line with new indentation
  local after_prefix = line:sub(#list_item.indent + #list_item.prefix + 1)
  local new_line = new_indent .. new_marker .. " " .. after_prefix
  vim.api.nvim_buf_set_lines(0, line_nr - 1, line_nr, false, { new_line })
  -- Restore cursor to correct column inside insert mode
  local col = vim.api.nvim_win_get_cursor(0)[2]
  local shift = #new_indent - #list_item.indent
  vim.api.nvim_win_set_cursor(0, { line_nr, col + shift})
  return ""
end

-- Setup function to initialize the plugin
function M.setup(opts)
  -- Merge user config with defaults
  if opts then
    M.config = vim.tbl_deep_extend("force", M.config, opts)
  end
  
  -- Create autocommands for the specified filetypes
  vim.api.nvim_create_autocmd("FileType", {
    pattern = M.config.filetypes,
    callback = function()
      -- Map <CR> to our handler in insert mode
      vim.api.nvim_buf_set_keymap(0, "i", "<CR>",
        [[<Cmd>lua require('mdlist').handle_cr()<CR>]],
        { noremap = true, silent = true })
      
      -- Map 'o' to our handler in normal mode
      vim.api.nvim_buf_set_keymap(0, "n", "o",
        [[<Cmd>lua require('mdlist').handle_o()<CR>]],
        { noremap = true, silent = true })
      
      -- Map 'O' to our handler in normal mode
      vim.api.nvim_buf_set_keymap(0, "n", "O",
        [[<Cmd>lua require('mdlist').handle_O()<CR>]],
        { noremap = true, silent = true })

      vim.api.nvim_buf_set_keymap(0, "i", "<Tab>",
        [[<Cmd>lua require('mdlist').handle_Tab(false)<CR>]],
        { noremap = true, silent = true }) 

      vim.api.nvim_buf_set_keymap(0, "i", "<S-Tab>",
        [[<Cmd>lua require('mdlist').handle_Tab(true)<CR>]],
        { noremap = true, silent = true })      
    end
  })
end

return M
