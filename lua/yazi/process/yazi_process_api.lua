---@module "plenary.path"

---@class YaziProcessApi # Provides yazi.nvim -> yazi process interactions. This allows yazi.nvim to tell yazi what to do.
---@field private config YaziConfig
---@field private yazi_id string
local YaziProcessApi = {}
YaziProcessApi.__index = YaziProcessApi

---@param config YaziConfig
---@param yazi_id string
function YaziProcessApi.new(config, yazi_id)
  local self = setmetatable({}, YaziProcessApi)
  self.config = config
  self.yazi_id = yazi_id
  return self
end

--- Emit a command to the yazi process.
--- https://yazi-rs.github.io/docs/dds#ya-emit
---@param args string[]
---@return vim.SystemObj
function YaziProcessApi:emit_to_yazi(args)
  local Log = require("yazi.log")
  local ya_cmd = { "ya", "emit-to", self.yazi_id, unpack(args) }

  if self.config.integrations.shell ~= nil then
    local result = {}
    for _, word in ipairs(self.config.integrations.shell) do
      table.insert(result, word)
    end

    local shell_bin = result[1]:lower()
    local is_wsl = shell_bin:match("wsl.exe")

    local command_string = ""
    if is_wsl then
      local escaped = {}
      for _, word in ipairs(ya_cmd) do
        table.insert(escaped, "'" .. word:gsub("'", "'\\''") .. "'")
      end
      command_string = table.concat(escaped, " ")
    else
      local escaped = {}
      for _, word in ipairs(ya_cmd) do
        table.insert(escaped, '"' .. word .. '"')
      end
      command_string = table.concat(escaped, " ")
    end

    table.insert(result, command_string)
    ya_cmd = result
  end

  Log:debug(
    string.format(
      "emit_to_yazi: Using shell-wrapped command: %s",
      vim.inspect(ya_cmd)
    )
  )

  return vim.system(ya_cmd, { timeout = 1000 }, function(result)
    Log:debug(
      string.format(
        "emit_to_yazi: execution finished with result '%s'",
        vim.inspect(result)
      )
    )
  end)
end

--- Tell yazi to focus (hover on) the given path.
--- https://yazi-rs.github.io/docs/configuration/keymap#manager.reveal
---@param path string
---@return vim.SystemObj
function YaziProcessApi:reveal(path)
  local shell_wrapper = self.config.integrations.shell
  local is_wsl = shell_wrapper ~= nil and shell_wrapper[1]:match("wsl.exe")

  local translated_path = path
  if is_wsl then
    local cmd = vim.deepcopy(shell_wrapper)
    table.insert(cmd, string.format("wslpath -u '%s'", path))
    translated_path = vim.fn.system(cmd):gsub("[\r\n]", "")
  end
  return self:emit_to_yazi({ "reveal", "--str", translated_path })
end

--- Tell yazi to open the currently selected file(s).
---@see https://yazi-rs.github.io/docs/configuration/keymap#manager.open
function YaziProcessApi:open()
  self:emit_to_yazi({ "open" })
end

return YaziProcessApi
