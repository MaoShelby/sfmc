require "lfs"
require 'lib.samp.events'
require"lib.moonloader"
require"lib.sampfuncs"
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8
local samp = require "samp.events"
local lfs = require 'lfs'
local socket = require("socket")
local http = require("socket.http")
local https = require("ssl.https")
local tag_q =  "{9370DB}[SFMC_Squad]{FFFFFF}: "
local json = require "cjson"
local effil = require('effil')



function SendWebhook(URL, DATA, callback_ok, callback_error) -- ������� �������� �������
  local function asyncHttpRequest(method, url, args, resolve, reject)
      local request_thread = effil.thread(function (method, url, args)
         local requests = require 'requests'
         local result, response = pcall(requests.request, method, url, args)
         if result then
            response.json, response.xml = nil, nil
            return true, response
         else
            return false, response
         end
      end)(method, url, args)
      if not resolve then resolve = function() end end
      if not reject then reject = function() end end
      lua_thread.create(function()
          local runner = request_thread
          while true do
              local status, err = runner:status()
              if not err then
                  if status == 'completed' then
                      local result, response = runner:get()
                      if result then
                         resolve(response)
                      else
                         reject(response)
                      end
                      return
                  elseif status == 'canceled' then
                      return reject(status)
                  end
              else
                  return reject(err)
              end
              wait(0)
          end
      end)
  end
  asyncHttpRequest('POST', URL, {headers = {['content-type'] = 'application/json'}, data = u8(DATA)}, callback_ok, callback_error)
end


function cmd_hl(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."���������� ������� ID ������!", 0x9370DB)
      return
  end

  -- ����������� �������� � �����
  local playerID = tonumber(arg)

  -- ���������, �������� �� �������� ������
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."�������� ������ ID ������!", 0x9370DB)
      return
  end

  -- ���������, ���������� �� ����� � ��������� ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."����� � ����� ID �� ����������!", 0x9370DB)
      return
  end

  -- ���� ��� �������� ������ �������, ���������� �������
  lua_thread.create(function()
      sampSendChat("/heal "..playerID.." 5000")
  end)
end

function cmd_md(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."���������� ������� ID ������!", 0x9370DB)
      return
  end

  -- ����������� �������� � �����
  local playerID = tonumber(arg)

  -- ���������, �������� �� �������� ������
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."�������� ������ ID ������!", 0x9370DB)
      return
  end

  -- ���������, ���������� �� ����� � ��������� ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."����� � ����� ID �� ����������!", 0x9370DB)
      return
  end

  -- ���� ��� �������� ������ �������, ���������� �������
  lua_thread.create(function()
      sampSendChat("/medcard "..playerID.." 3 3 200000")
  end)
end


function cmd_book(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."���������� ������� ID ������!", 0x9370DB)
      return
  end

  -- ����������� �������� � �����
  local playerID = tonumber(arg)

  -- ���������, �������� �� �������� ������
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."�������� ������ ID ������!", 0x9370DB)
      return
  end

  -- ���������, ���������� �� ����� � ��������� ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."����� � ����� ID �� ����������!", 0x9370DB)
      return
  end

  -- ���� ��� �������� ������ �������, ���������� �������
  lua_thread.create(function()
      sampSendChat("/givewbook "..playerID.." 100")
  end)
end


local allowed_nicks = {
  "Mao_Shelby",
  "Franchesko_Presli",
  "Toby_Shelby",
  "Oliver_Nesterov",
  "Moksimka_Evans",
}

-- ������� ��������, ��������� �� ��� � ������ �����������
local function isAllowedNick(nick)
  for _, allowed_nick in ipairs(allowed_nicks) do
      if nick == allowed_nick then
          return true
      end
  end
  return false
end


function main()
if not isSampLoaded() or not isSampfuncsLoaded() then return end
  
  -- ��������, ���� SAMP ������ ��������
  while not isSampAvailable() do wait(100) end

  -- �������� ����������� � �������
  while not sampIsLocalPlayerSpawned() do
      wait(100)
  end
sampAddChatMessage(" ", -1)
sampAddChatMessage(tag_q.."������ ������� ��������!", 0x9370DB)
sampAddChatMessage(" ", -1)
sampRegisterChatCommand("hl", cmd_hl)
sampRegisterChatCommand("md", cmd_md)
sampRegisterChatCommand("gb", cmd_book)

id = select(2, sampGetPlayerIdByCharHandle(playerPed))
nick = sampGetPlayerNickname(id)

  if isAllowedNick(nick) then
    print("�������!")
  else
    sampAddChatMessage(tag_q.."�������� ������ ��� ����������� �������������.", -1)
    thisScript():unload() 
  end

  local ip, port = sampGetCurrentServerAddress()
  if ip == "80.66.82.168" then
    sampAddChatMessage(tag_q.."��������� ������� Page", -1)
  else
    sampAddChatMessage(tag_q.."������ �������� ������ �� ������� Arizona RP - Page ", -1)
    thisScript():unload() 
  end

  while true do
    wait(0)
  end
end








function samp.onServerMessage(color, text)
  id = select(2, sampGetPlayerIdByCharHandle(playerPed))
  nick = sampGetPlayerNickname(id)
  if text:find("������������ ������ ����� ����� ����������� (.+)%, �������� ���������: "..nick.."(.+)") then
    local currentTime = os.date("%H:%M:%S") 
    local invname, leader = text:match("������������ ������ ����� ����� ����������� (.+)%, �������� ���������: "..nick.."(.+)")
    SendWebhook('https://discord.com/api/webhooks/1281603810627682334/8Uc7xoNxWgNvHzVGvzh0mLL-y7A23_ui3ur7wBf9ZTQHOCn-cEs0zbtycrcEMnscIU3j',([[{
    "content": "[%s] **%s** ��������� � ����������� **%s**",
    "embeds": [],
    "attachments": []
    }]]):format(currentTime, nick, invname))
    lua_thread.create(function()
      sampSendChat("/rb  ������ "..invname.." ������� �� ��������� � ��������� ����� � ����� ��������!")
      wait(1000)
      sampSendChat("/rb ��� ������ �� Discord: hfseg6kbjb")
    end)
  end
  if text:find("%[�����������%] {FFFFFF}"..nick.." ������(.+)% �� �����������%. �������:(.+)") then
    local currentTime = os.date("%H:%M:%S")   
    local name, reason = text:match("%[�����������%] {FFFFFF}"..nick.." ������(.+)% �� �����������%. �������:(.+)")
    SendWebhook('https://discord.com/api/webhooks/1282991962747834419/hqwlwA5GqOa3UIFKbV0cS74csLe9GBJauFz422_yHdGh41zZaumeriMBIlQRyYKKOYwx',([[{
      "content": "[%s] **%s** ������ �� �����������**%s** �������:**%s**",
      "embeds": [],
      "attachments": []
      }]]):format(currentTime, nick, name, reason))
  end
  if text:find(nick.." ������� ������(.+)") then
    local currentTime = os.date("%H:%M:%S") 
    local invname= text:match(nick.." ������� ������(.+)")
    SendWebhook('https://discord.com/api/webhooks/1283018846839771148/wKIsBuBsKbztCD3Dy5X81w6FOy4CHbDQ3dSBKleyHlf9hUFfk6xCLYqD5WvVf6ASlXM6',([[{
    "content": "[%s] **%s** ������� ������**%s**",
    "embeds": [],
    "attachments": []
    }]]):format(currentTime, nick, invname))
  end
end  
