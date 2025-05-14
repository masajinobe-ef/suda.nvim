-- suda.nvim - Safe sudo integration for Neovim
-- License: MIT
local M = {}
local Job = require 'plenary.job'

local function is_writable(path)
  return path and vim.fn.filewritable(path) == 1
end

local function sudo_read(path, callback)
  if not path or #path == 0 then
    vim.notify('Invalid file path', vim.log.levels.ERROR)
    return callback(nil)
  end

  local prompt = vim.g.suda_prompt or 'Password: '
  local stderr = {}
  local output = {}

  Job:new({
    command = 'sudo',
    args = {
      '--prompt',
      prompt,
      'cat',
      path,
    },
    on_exit = function(j, exit_code)
      if exit_code ~= 0 then
        vim.notify(
          'Read failed: ' .. table.concat(stderr, '\n'),
          vim.log.levels.ERROR
        )
        return callback(nil)
      end
      callback(output)
    end,
    on_stderr = function(_, data)
      table.insert(stderr, data)
    end,
    on_stdout = function(_, data)
      table.insert(output, data)
    end,
  }):start()
end

local function sudo_write(content, dst, callback)
  if not content or not dst or #dst == 0 then
    return callback(false)
  end

  local prompt = vim.g.suda_prompt or 'Password: '
  local stderr = {}

  Job:new({
    command = 'sudo',
    args = {
      '--prompt',
      prompt,
      'tee',
      dst,
    },
    stdin = table.concat(content, '\n'),
    on_exit = function(j, exit_code)
      if exit_code ~= 0 then
        vim.notify(
          'Write failed: ' .. table.concat(stderr, '\n'),
          vim.log.levels.ERROR
        )
        return callback(false)
      end
      callback(true)
    end,
    on_stderr = function(_, data)
      table.insert(stderr, data)
    end,
  }):start()
end

local function handle_buffer(bufname, action)
  if type(bufname) ~= 'string' or #bufname == 0 then
    vim.notify('Invalid buffer name', vim.log.levels.ERROR)
    return
  end

  local path_part = bufname:match '^sudo://(.*)'
  if not path_part or #path_part == 0 then
    vim.notify('Invalid sudo protocol format', vim.log.levels.ERROR)
    return
  end

  local path = vim.fn.expand(path_part:gsub('^/*', '/'))
  if not path:match '^/' then
    path = '/' .. path
  end

  if #path == 0 then
    vim.notify('Could not resolve file path', vim.log.levels.ERROR)
    return
  end

  if action == 'read' then
    sudo_read(path, function(lines)
      if not lines then
        return
      end
      vim.schedule(function()
        vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
        vim.bo.modified = false
        vim.bo.readonly = false
        vim.bo.fileformat = vim.bo.fileformat -- Reset fileformat
      end)
    end)
  elseif action == 'write' then
    local content = vim.api.nvim_buf_get_lines(0, 0, -1, false)
    sudo_write(content, path, function(success)
      vim.schedule(function()
        if success then
          vim.bo.modified = false
          vim.notify('Saved: ' .. path, vim.log.levels.INFO)
        else
          vim.notify('Failed to save: ' .. path, vim.log.levels.ERROR)
        end
      end)
    end)
  end
end

local function auto_sudo()
  vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileReadPre' }, {
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      if bufname:match '^sudo://' then
        return
      end

      local path = vim.fn.expand(bufname)
      if
        #path > 0
        and vim.fn.filereadable(path) == 1
        and not is_writable(path)
      then
        vim.schedule(function()
          vim.cmd('edit sudo://' .. vim.fn.fnameescape(path))
        end)
      end
    end,
  })
end

local function setup_commands()
  vim.api.nvim_create_user_command('SudoWrite', function(opts)
    if opts.args and #opts.args > 0 then
      handle_buffer(opts.args, 'write')
    else
      handle_buffer(vim.api.nvim_buf_get_name(0), 'write')
    end
  end, { nargs = '?', complete = 'file' })
end

function M.setup()
  vim.api.nvim_create_autocmd({ 'BufReadCmd', 'FileReadCmd' }, {
    pattern = 'sudo://*',
    callback = function(args)
      if args.file and #args.file > 0 then
        handle_buffer(args.file, 'read')
      end
    end,
  })

  vim.api.nvim_create_autocmd({ 'BufWriteCmd', 'FileWriteCmd' }, {
    pattern = 'sudo://*',
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      if bufname and #bufname > 0 then
        handle_buffer(bufname, 'write')
      end
    end,
  })

  auto_sudo()
  setup_commands()
end

return M
