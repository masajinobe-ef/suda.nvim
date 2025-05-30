-- suda.nvim - Safe sudo integration for Neovim
-- License: MIT
local M = {}

local function is_writable(path)
  return path and vim.fn.filewritable(path) == 1
end

local function sudo_read(path)
  if not path or #path == 0 then
    vim.notify('Invalid file path', vim.log.levels.ERROR)
    return nil
  end

  local prompt = vim.g.suda_prompt or 'Password: '
  local tmpfile = vim.fn.tempname() .. '_sudo_read'

  local cmd = string.format(
    'sudo -p "%s" cat %s > %s 2>/dev/null',
    prompt,
    vim.fn.shellescape(path),
    vim.fn.shellescape(tmpfile)
  )

  if os.execute(cmd) ~= 0 then
    pcall(os.remove, tmpfile)
    return nil
  end

  return vim.fn.filereadable(tmpfile) == 1 and tmpfile or nil
end

local function sudo_write(src, dst)
  if not src or not dst or #src == 0 or #dst == 0 then
    return false
  end

  local prompt = vim.g.suda_prompt or 'Password: '
  local esc = vim.fn.shellescape

  local cmd = string.format(
    [[
    if [ -e %s ]; then
      ORIG_OWNER=$(sudo stat -c "%%u:%%g" %s) &&
      ORIG_PERM=$(sudo stat -c "%%a" %s) &&
      sudo -p %s cp %s %s &&
      sudo -p %s chown $ORIG_OWNER %s &&
      sudo -p %s chmod $ORIG_PERM %s
    else
      sudo -p %s install -m 644 %s %s
    fi
  ]],
    esc(dst),
    esc(dst),
    esc(dst),
    esc(prompt),
    esc(src),
    esc(dst),
    esc(prompt),
    esc(dst),
    esc(prompt),
    esc(dst),
    esc(prompt),
    esc(src),
    esc(dst)
  )

  return os.execute(cmd) == 0
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
    local tmp_path = sudo_read(path)
    if not tmp_path then
      vim.notify('Failed to read: ' .. path, vim.log.levels.ERROR)
      return
    end

    vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(tmp_path))
    vim.bo.modified = false
    vim.bo.readonly = false
    pcall(os.remove, tmp_path)
  elseif action == 'write' then
    local tmp_write = vim.fn.tempname() .. '_sudo_write'
    vim.fn.writefile(vim.api.nvim_buf_get_lines(0, 0, -1, false), tmp_write)

    if sudo_write(tmp_write, path) then
      vim.bo.modified = false
      vim.notify('Saved: ' .. path, vim.log.levels.INFO)
    else
      vim.notify('Failed to save: ' .. path, vim.log.levels.ERROR)
    end
    pcall(os.remove, tmp_write)
  end
end

local function auto_sudo()
  vim.api.nvim_create_autocmd({ 'BufReadPre', 'FileReadPre' }, {
    callback = function(args)
      local bufname = vim.api.nvim_buf_get_name(args.buf)
      if not bufname or bufname:match '^sudo://' then
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
    end
  end, { nargs = 1, complete = 'file' })
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
