local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  vim.fn.system({ "git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable", lazypath })
end
vim.opt.rtp:prepend(lazypath)

local ok_lazy, lazy = pcall(require, "lazy")
if not ok_lazy then
  vim.notify("lazy.nvim not installed", vim.log.levels.WARN)
  return
end

lazy.setup({
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      local ok, nvim_tree = pcall(require, "nvim-tree")
      if not ok then
        vim.notify("nvim-tree not installed", vim.log.levels.WARN)
        return
      end
      nvim_tree.setup({
        disable_netrw = true,
        hijack_netrw = true,
        view = { width = 32 },
        renderer = { group_empty = true },
        filters = { dotfiles = false },
        git = { enable = true },
      })
    end,
  },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "go", "lua", "vim", "vimdoc", "query" },
      highlight = { enable = true, additional_vim_regex_highlighting = false },
    },
    config = function()
      if not pcall(require, "nvim-treesitter") then
        vim.notify("nvim-treesitter not installed", vim.log.levels.WARN)
        return
      end
      require("nvim-treesitter").setup(opts)
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    config = function()
      local ok, telescope = pcall(require, "telescope")
      if not ok then
        vim.notify("telescope not installed", vim.log.levels.WARN)
        return
      end
      telescope.setup({
        defaults = {
          previewer = true,
          layout_strategy = "vertical",
          layout_config = {
            height = 0,
            width = 0.7,
            prompt_position = "top",
            preview_height = 0,
          },
          sorting_strategy = "ascending",
        },
      })
    end,
  },
  {
    "neovim/nvim-lspconfig",
    config = function()
      local gopls_path = vim.fn.exepath("gopls")
      local gopls_cmd = gopls_path ~= "" and gopls_path or "gopls"

      vim.lsp.config.gopls = {
        cmd = { gopls_cmd },
        filetypes = { "go", "gomod", "gowork", "gotmpl" },
        settings = {
          gopls = {
            semanticTokens = true,
          },
        },
      }

      if gopls_path == "" then
        vim.notify("gopls not found on PATH; install it to enable Go LSP", vim.log.levels.WARN)
      end

      vim.lsp.enable("gopls")
    end,
  },
  {
    "kevinhwang91/nvim-ufo",
    dependencies = { "kevinhwang91/promise-async" },
    config = function()
      if not pcall(require, "ufo") then
        vim.notify("nvim-ufo not installed", vim.log.levels.WARN)
        return
      end
      local ufo = require("ufo")
      ufo.setup({
        provider_selector = function() return { "treesitter", "indent" } end,
        fold_virt_text_handler = function(virt_text, lnum, end_lnum, width, truncate)
          local new_text = {}
          local suffix = (" ... %d lines ..."):format(end_lnum - lnum)
          local suf_width = vim.fn.strdisplaywidth(suffix)
          local target_width = width - suf_width
          local cur_width = 0

          local text = vim.api.nvim_buf_get_lines(0, lnum - 1, lnum, false)[1]
          if not text then return virt_text end

          local highlights = {}
          for i = 1, #text do highlights[i] = "UfoFoldedFg" end

          local ok, parser = pcall(vim.treesitter.get_parser, 0)
          if ok and parser then
            local query = vim.treesitter.query.get(parser:lang(), "highlights")
            if query then
              local tree = parser:parse()[1]
              local root = tree:root()
              for id, node, _ in query:iter_captures(root, 0, lnum - 1, lnum) do
                local capture_name = query.captures[id]
                local _, start_col, _, end_col = node:range()
                for i = start_col + 1, end_col do
                  highlights[i] = "@" .. capture_name
                end
              end
            end
          end

          local current_hl = highlights[1] or "UfoFoldedFg"
          local current_start = 1
          for i = 2, #text + 1 do
            if i > #text or highlights[i] ~= current_hl then
              local chunk_text = text:sub(current_start, i - 1)
              local chunk_width = vim.fn.strdisplaywidth(chunk_text)
              
              if target_width > cur_width + chunk_width then
                table.insert(new_text, { chunk_text, current_hl })
                cur_width = cur_width + chunk_width
              else
                chunk_text = truncate(chunk_text, target_width - cur_width)
                table.insert(new_text, { chunk_text, current_hl })
                cur_width = cur_width + vim.fn.strdisplaywidth(chunk_text)
                break
              end
              current_hl = highlights[i]
              current_start = i
            end
          end

          table.insert(new_text, { suffix, "FoldedInfo" })
          cur_width = cur_width + suf_width

          if cur_width < width then
            local padding = width - cur_width
            table.insert(new_text, { string.rep(".", padding), "UfoFoldedFg" })
          end

          return new_text
        end,
      })
    end,
  },
})

vim.opt.foldtext = ""

---
--- HIGHLIGHTING & LSP FIXES
---

local function apply_go_highlights()
  -- 1. Background and Folds
  vim.api.nvim_set_hl(0, "Normal", { bg = "#2b2b2b" })

  -- Clear FG/BG from Folded so syntax shows through
  vim.api.nvim_set_hl(0, "Folded", { fg = "none", bg = "none" })

  -- 2. Define Colors
  local orange = "#cc7832"
  local public_method = "#e2c543"
  local type_builtin = "#e2a069"
  local type_custom = "#657a47"
  local variable = "#6483A5"
  local unexported_variable = "#A76969"
  local string_col = "#5f7c5e"
  local package_color = "#a49779"
  local gray = "#928a79"
  local private_method = "#89703F" -- Unexported functions/methods

  -- 3. Helper function to set BOTH generic and specific groups
  -- This ensures ufo finds the color regardless of which name it grabs
  local function set_color(group_name, color)
    vim.api.nvim_set_hl(0, group_name, { fg = color })
    vim.api.nvim_set_hl(0, group_name .. ".go", { fg = color }) -- Add .go version
  end

  -- Fold Suffix & Dots
  set_color("FoldedInfo", gray)
  set_color("UfoFoldedFg", gray)

  -- Keywords
  set_color("@keyword", orange)
  set_color("@conditional", orange)
  set_color("@repeat", orange)
  set_color("@keyword.function", orange)
  set_color("@keyword.type", orange)


  -- Functions/Methods
  set_color("@function", public_method)
  set_color("@method", public_method)
  set_color("@function.call", public_method)
  set_color("@function.call.go", public_method)
  set_color("@method.call.go", public_method)
  set_color("@constructor.go", public_method)

  -- Types
  set_color("@type.builtin", orange)
  set_color("@type", type_custom)

  -- Variables/Strings
  set_color("@variable", variable)
  set_color("@variable.parameter", variable)
  set_color("@string", string_col)
  set_color("@property.go", unexported_variable)
  set_color("@variable.member.go", unexported_variable)
  -- Modules/Packages (Gray)
  set_color("@module", package_color)
  set_color("@namespace", package_color)

  -- Builtin Functions (Gold)
  set_color("@function.builtin", public_method)
  set_color("@function.call", public_method)
  set_color("@method.call", public_method)
  set_color("@function.method.call", public_method)

  -- Private Functions/Methods (Muted Gold)
  set_color("@function.private", private_method)
  set_color("@method.private", private_method)
  set_color("@function.call.private", private_method)
  set_color("@method.call.private", private_method)
  set_color("@constructor.private", private_method)
  set_color("@constructor.call.private", private_method)

  -- Constants / Fields (Gold)
  set_color("@constant", public_method)

  -- Builtin Constants (Orange)
  set_color("@constant.builtin", orange)

  -- LSP Semantic Tokens (The Real Fix)
  -- Packages/Namespaces -> Gray (e.g. fmt, reflect, ion)
  set_color("@lsp.type.namespace", package_color)
  
  -- Enum Members (e.g. reflect.Interface) -> Gold
  set_color("@lsp.type.enumMember", public_method)
  set_color("@lsp.type.enum", public_method)
  
  -- Functions/Methods -> Gold (e.g. Println, Elem, Kind)
  set_color("@lsp.type.function", public_method)
  set_color("@lsp.type.method", public_method)
  set_color("@lsp.mod.exported", public_method)

  -- Variables -> Variable Color (e.g. s, ctx)
  set_color("@lsp.type.variable", variable)
  set_color("@lsp.type.parameter", variable)

  -- Properties/Fields -> Gold (e.g. Value in reflect.Value)
  set_color("@lsp.type.property", public_method)

  -- Types -> Green/Orange (e.g. Interface, Int)
  set_color("@lsp.type.type", type_custom)
  set_color("@lsp.type.class", type_custom)
  set_color("@lsp.type.interface", public_method) -- reflect.Interface is often an interface type

  -- 4. Syntax and Treesitter
  vim.cmd("syntax on")
  vim.treesitter.stop(0)
  vim.treesitter.start(0, "go")
end

vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    if not args.data or not args.data.client_id then return end
    local client = vim.lsp.get_client_by_id(args.data.client_id)
    if not client or not client.server_capabilities.semanticTokensProvider then return end

    if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.start then
      vim.lsp.semantic_tokens.start(args.buf, client.id)
    elseif vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.enable then
      vim.lsp.semantic_tokens.enable(args.buf, client.id)
    end

    if vim.lsp.semantic_tokens and vim.lsp.semantic_tokens.force_refresh then
      vim.lsp.semantic_tokens.force_refresh(args.buf)
    end
  end,
})

-- 1. Setup gopls
-- vim.lsp.enable("gopls")

-- 2. DISABLE LSP Semantic Tokens so Treesitter colors work
-- vim.api.nvim_create_autocmd("LspAttach", {
--   callback = function(args)
--     local client = vim.lsp.get_client_by_id(args.data.client_id)
--     if client and client.name == "gopls" then
--       client.server_capabilities.semanticTokensProvider = nil
--     end
--   end,
-- })

-- 3. Apply highlights on file open and colorscheme change
vim.api.nvim_create_autocmd({ "FileType", "ColorScheme", "BufEnter" }, {
  pattern = "go",
  callback = apply_go_highlights,
})

-- Fold all in Go files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "go",
  callback = function()
    vim.cmd("normal zM")
  end,
})

vim.keymap.set("n", "qq", ":q!<CR>")
vim.keymap.set("n", "sq", ":wq<CR>")
vim.keymap.set("n", "J", "10j")
vim.keymap.set("n", "K", "10k")
vim.keymap.set("n", "ff", "zA")
vim.keymap.set("n", "ft", ":NvimTreeToggle<CR>")
-- vim.keymap.set("n", "<D-k>", ":NvimTreeToggle<CR>")
local function toggle_telescope_preview_on_prompt(prompt_bufnr)
  local ok, action_state = pcall(require, "telescope.actions.state")
  if not ok then
    return
  end

  local picker = action_state.get_current_picker(prompt_bufnr)
  if not picker or not picker.all_previewers or picker.all_previewers == false then
    return
  end

  local prompt = action_state.get_current_line()
  local is_empty = vim.trim(prompt or "") == ""

  if is_empty and picker.previewer then
    picker.hidden_previewer = picker.previewer
    picker.previewer = nil
    picker:full_layout_update()
  elseif (not is_empty) and (not picker.previewer) and picker.hidden_previewer then
    picker.previewer = picker.hidden_previewer
    picker.hidden_previewer = nil
    picker:full_layout_update()
  end
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "TelescopePrompt",
  callback = function(args)
    local prompt_bufnr = args.buf

    toggle_telescope_preview_on_prompt(prompt_bufnr)

    vim.api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
      buffer = prompt_bufnr,
      callback = function()
        toggle_telescope_preview_on_prompt(prompt_bufnr)
      end,
    })
  end,
})
local function toggle_telescope(prompt_fn)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == "TelescopePrompt" then
      vim.api.nvim_win_close(win, true)
      return
    end
  end

  local ok, builtin = pcall(require, "telescope.builtin")
  if not ok then
    vim.notify("telescope not installed", vim.log.levels.WARN)
    return
  end
  prompt_fn(builtin)
end

local function lsp_symbol_entry_maker()
  local make_entry = require("telescope.make_entry")
  local entry_display = require("telescope.pickers.entry_display")
  local displayer = entry_display.create({
    separator = "  ",
    items = {
      { width = 50 },
      { remaining = true },
    },
  })

  local function read_symbol_line(filename, lnum, fallback)
    if not filename or filename == "" or not lnum or lnum < 1 then
      return fallback or ""
    end

    local ok, lines = pcall(vim.fn.readfile, filename, "", lnum)
    if not ok or not lines or not lines[lnum] then
      return fallback or ""
    end

    local line = lines[lnum]
    line = line:gsub("%s+", " ")
    return vim.trim(line)
  end

  local base_entry_maker = make_entry.gen_from_lsp_symbols({})

  return function(entry)
    local e = base_entry_maker(entry)
    local filename = e.filename or e.path or ""
    local line = read_symbol_line(filename, e.lnum, e.text)
    local file_display = filename ~= "" and vim.fn.fnamemodify(filename, ":.") or ""

    e.display = function()
      return displayer({ line, file_display })
    end

    return e
  end
end



vim.keymap.set("n", "<D-o>", function()
  toggle_telescope(function(builtin) builtin.find_files() end)
end)

vim.keymap.set("n", "<D-k>", function()
  local has_gopls = false
  for _, client in ipairs(vim.lsp.get_clients()) do
    if client.name == "gopls" then
      has_gopls = true
      break
    end
  end

  if not has_gopls then
    vim.notify("gopls is not attached; open a Go file first", vim.log.levels.WARN)
    return
  end

  toggle_telescope(function(builtin)
    builtin.lsp_dynamic_workspace_symbols({
      prompt_title = "What's up",
      -- results_limit = 10,
      previewer = true,
      layout_strategy = "vertical",
      layout_config = {
        prompt_position = "top",
        mirror = true,
        height = 0.5,
        preview_height = 0.5,
      },
      sorting_strategy = "ascending",
      preview_cutoff = 0,
      entry_maker = lsp_symbol_entry_maker(),
    })
  end)
end)
