# md-list.nvim

A Neovim plugin for intelligent Markdown list handling. Automatically continues lists with intelligent numbering and indentation.

## Features
- Automatically continues unordered lists (*, -, +, >)
- Automatically continues ordered lists (1., 1))
- Handles empty list items intelligently:
  - Unindents when pressing Enter on an empty indented list item.
  - Removes the list item completely when pressing Enter on an empty non-indented list item
- Special handling for colon-terminated lines, creating indented sublists
- Works with both normal mode (o, O) and insert mode (<CR>)


## Installation
Using packer.nvim
```lua
use {
  'oliver-hughes/mdlist.nvim',
  config = function()
    require('mdlist').setup()
  end
}
```

Using lazy.nvim
```lua
{
  'username/mdlist.nvim',
  config = function()
    require('mdlist').setup()
  end
}
```

## Configuration
The plugin works with default settings, but you can customize it to your preferences:

```lua
require('mdlist').setup({
  -- List markers to recognize and continue
  list_markers = {
    -- Unordered list markers
    "*", "-", "+", ">",
    -- Ordered list markers will be detected by pattern
  },
  -- Marker to use for new lists after a colon (defaults to first marker in list_markers)
  colon_list_marker = "-",
  -- Filetypes where the plugin should be active
  filetypes = { "markdown", "text" }
})
```

## Usage
### Continuing Lists
When you press Enter at the end of a list item in insert mode, a new list item will be created:

```markdown
* Item 1█

-- becomes -->

* Item 1
* █
```

For ordered lists, the plugin automatically increments the number:

```markdown
1. First item█

-- becomes -->

1. First item
2. █
```

### Colon-Terminated Lines

When you press `Enter` at the end of a line that ends with a colon, an indented list will be created:

```markdown
Topics:█

-- becomes -->

Topics:
  * █
```

This also works with list items that end with a colon:

```markdown
* Main points:█

-- becomes -->

* Main points:
  * █
```

### Empty List Items

When you press `Enter` on an empty list item, the plugin will:

1. Unindent if the item is indented:
   ```markdown
     * █
   
   -- becomes -->
   
   * █
   ```

2. Remove the list item completely if it's not indented:
   ```markdown
   * █
   
   -- becomes -->
   
   █
   ```

### Normal Mode Operations

The plugin also enhances the normal mode `o` and `O` commands:

- `o` creates a new list item below the current one
- `O` creates a new list item above the current one (and adjusts numbering for ordered lists)

## Examples

### Basic List Continuation

```markdown
* First item
* Second item█

-- Press Enter -->

* First item
* Second item
* █
```

### Ordered List Continuation

```markdown
1. First step
2. Second step█

-- Press Enter -->

1. First step
2. Second step
3. █
```

### Colon Indentation

```markdown
Shopping list:█

-- Press Enter -->

Shopping list:
  * █

-- Continue adding items -->

Shopping list:
  * Apples
  * Bananas
  * Milk
```

### Nested Lists with Colon

```markdown
* Project tasks:█

-- Press Enter -->

* Project tasks:
  * █

-- Add more nested items -->

* Project tasks:
  * Research
  * Implementation
  * Testing
```

License
MIT

Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
