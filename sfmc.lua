require "lfs"
require 'lib.samp.events'
require"lib.moonloader"
require"lib.sampfuncs"
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local samp = require "samp.events"
local lfs = require 'lfs'
local socket = require("socket")
local http = require("socket.http")
local https = require("ssl.https")
local tag_q =  "{9370DB}[SFMC_Squad]{FFFFFF}: "
local json2 = require "cjson"
local effil = require('effil')
local vkeys = require 'vkeys'
local imgui = require "mimgui"
local screenX, screenY = getScreenResolution()
local font_flag = require('moonloader').font_flag
local my_font = renderCreateFont('Verdana', 10, font_flag.BOLD + font_flag.SHADOW)
local ltn12 = require("ltn12")
local dlstatus = require('moonloader').download_status
local ffi = require 'ffi'
local new, vec2, col = imgui.new, imgui.ImVec2, imgui.ImColor


local requests = require 'requests'
local json = require 'dkjson'
local inicfg = require 'inicfg'

-- Настройки

local SERVER_URL = 'http://136.0.251.4:8095'
local DEBUG = false
local last_message_id = 0
local connection_attempts = 0
local max_connection_attempts = 5
local retry_delay = 10000 -- 10 секунд между попытками


-- Переменные для обновления
local script_vers = 94
local script_vers_text = "1.94"
local update_url = "https://raw.githubusercontent.com/MaoShelby/sfmc/main/update.ini"
local update_path = getWorkingDirectory() .. "/update.ini"
local script_url = "https://github.com/MaoShelby/sfmc/raw/main/sfmc.luac"
local script_path = thisScript().path
local update_state = false
local isUpdating = false



-- Функция загрузки обновления
function downloadUpdate()
    if update_state and not isUpdating then
        isUpdating = true
        lua_thread.create(function()
            wait(500)
            downloadUrlToFile(script_url, script_path, function(id, status)
                if status == dlstatus.STATUS_ENDDOWNLOADDATA then
                    sampAddChatMessage(tag_q.."Скрипт успешно обновлен!", -1)
                    isUpdating = false
                    thisScript():reload()
                elseif status == dlstatus.STATUS_FAILED then
                    sampAddChatMessage(tag_q.."Ошибка загрузки обновления.", -1)
                    isUpdating = false
                end
            end)
        end)
    end
end

-- Функция проверки обновлений



function checkForUpdate()
    downloadUrlToFile(update_url, update_path, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            if doesFileExist(update_path) then
                local ini = inicfg.load(nil, update_path)
                if ini and ini.info then
                    if tonumber(ini.info.vers) > script_vers then
                        sampAddChatMessage(tag_q.."Доступно обновление! Версия: " .. ini.info.vers_text, -1)
                        update_state = true
                        downloadUpdate()
                    else
                        sampAddChatMessage(tag_q.."У вас установлена последняя версия скрипта.", -1)
                    end
                else
                    sampAddChatMessage(tag_q.."Ошибка чтения данных обновления.", -1)
                end
                os.remove(update_path)
            else
                sampAddChatMessage(tag_q.."Ошибка загрузки файла обновления.", -1)
            end
        elseif status == dlstatus.STATUS_FAILED then
            sampAddChatMessage(tag_q.."Ошибка проверки обновлений.", -1)
        end
    end)
end

function checkForUpdatechas()
    downloadUrlToFile(update_url, update_path, function(id, status)
        if status == dlstatus.STATUS_ENDDOWNLOADDATA then
            if doesFileExist(update_path) then
                local ini = inicfg.load(nil, update_path)
                if ini and ini.info then
                    if tonumber(ini.info.vers) > script_vers then
                        update_state = true
                        lua_thread.create(function()
                            wait(500)
                            downloadUpdate()
                        end)
					else
                        print(tag_q.."У вас установлена последняя версия скрипта.")
                    end
                else
                    print(tag_q.."Ошибка чтения данных обновления.")
                end
                os.remove(update_path)
            else
                print(tag_q.."Ошибка загрузки файла обновления.")
            end
        elseif status == dlstatus.STATUS_FAILED then
            print(tag_q.."Ошибка проверки обновлений.")
        end
    end)
end















function url_encode(str)
    if str then
        str = str:gsub("\n", "\r\n")
        str = str:gsub("([^%w %-%_%.%~])", function(c)
            return string.format("%%%02X", string.byte(c))
        end)
        str = str:gsub(" ", "+")
    end
    return str
end

function sendTelegram(text, inputGroup)
    local inputToken = "7731216678:AAGKoTLHtu127ndUHXco9XxYRE_fHhJO1WM" -- Токен вашего бота
    
    -- Преобразуем текст в UTF-8
    local utf8_text = toUtf8(text)
    if not utf8_text then
        print("Ошибка: текст не удалось преобразовать в UTF-8")
        return
    end
    
    -- Кодируем текст для URL
    local encoded_text = url_encode(utf8_text)
    
    -- Формируем URL
    local url = ('https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s'):format(
        inputToken,
        inputGroup,
        encoded_text
    )
    
    asyncHttpRequest('POST', url, nil, function(response)
        local success, result = pcall(function() return json.decode(response.text) end)
        if success and result.ok then
            print("Сообщение отправлено успешно!")
        else
            print("Ошибка при отправке: ", result and result.description or "Неизвестная ошибка")
        end
    end, function(err)
        print("Ошибка при отправке сообщения в Telegram:", err)
    end)
end

function asyncHttpRequest(method, url, args, resolve, reject)
    local request_thread = effil.thread(function(method, url, args)
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
        while true do
            local status, err = request_thread:status()
            if status == 'completed' then
                local result, response = request_thread:get()
                if result then
                    resolve(response)
                else
                    reject(response)
                end
                return
            elseif status == 'canceled' then
                reject('Thread canceled')
                return
            end
            wait(0)
        end
    end)
end

local totalTime = 180 -- Общее время таймера в секундах
local startTime = 0 -- Время старта таймера
local isTimerActive = false -- Таймер по умолчанию не активен

local windowVisiblkd = new.bool(false)
local resX, resY = getScreenResolution() -- Разрешение экрана





function SendWebhook(URL, DATA, callback_ok, callback_error) -- Функция отправки запроса
  asyncHttpRequest('POST', URL, {headers = {['content-type'] = 'application/json'}, data = u8(DATA)}, callback_ok, callback_error)
end

function cmd_inv(arg)
    lua_thread.create(function()
      sampSendChat("/invite "..arg)
    end)
end

function cmd_hl(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."необходимо указать ID игрока!", 0x9370DB)
      return
  end

  -- Преобразуем аргумент в число
  local playerID = tonumber(arg)

  -- Проверяем, является ли аргумент числом
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."неверный формат ID игрока!", 0x9370DB)
      return
  end

  -- Проверяем, существует ли игрок с указанным ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."игрок с таким ID не существует!", 0x9370DB)
      return
  end

  -- Если все проверки прошли успешно, отправляем команду
  lua_thread.create(function()
      sampSendChat("/heal "..playerID.." 10000")
  end)
end

function cmd_md(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."необходимо указать ID игрока!", 0x9370DB)
      return
  end

  -- Преобразуем аргумент в число
  local playerID = tonumber(arg)

  -- Проверяем, является ли аргумент числом
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."неверный формат ID игрока!", 0x9370DB)
      return
  end

  -- Проверяем, существует ли игрок с указанным ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."игрок с таким ID не существует!", 0x9370DB)
      return
  end

  -- Если все проверки прошли успешно, отправляем команду
  lua_thread.create(function()
      sampSendChat("/medcard "..playerID.." 3 3 200000")
  end)
end


function cmd_book(arg)
  if arg == nil or arg == "" then
      sampAddChatMessage(tag_q.."необходимо указать ID игрока!", 0x9370DB)
      return
  end

  -- Преобразуем аргумент в число
  local playerID = tonumber(arg)

  -- Проверяем, является ли аргумент числом
  if playerID == nil or playerID <= 0 then
      sampAddChatMessage(tag_q.."неверный формат ID игрока!", 0x9370DB)
      return
  end

  -- Проверяем, существует ли игрок с указанным ID
  if not sampIsPlayerConnected(playerID) then
      sampAddChatMessage(tag_q.."игрок с таким ID не существует!", 0x9370DB)
      return
  end
-- 
  -- Если все проверки прошли успешно, отправляем команду
  lua_thread.create(function()
      sampSendChat("/givewbook "..playerID.." 100")
  end)
end


local allowed_nicks = {
    "Miya_Shelby",
    "Mao_Shelby",
    "Kevin_Berlinetta",
	"Yumi_Shelby",
    "Emily_Miller",
    "Alexey_Kudzaev",
	"Corovar_Miror",
	"Dmitry_Berlinetta",
	"Kris_Sherman",
	"Steven_Sadness",
	"Steve_Lix",
}

local allowed_nicks_date = {
    Miya_Shelby = "2024.09.08",
    Mao_Shelby = "2024.09.08",
    Adriano_Shelby = "2024.09.19",
    Vino_Vnik = "2024.11.03",
    Kevin_Berlinetta = "2024.10.05",
    Yumi_Shelby = "2024.11.13",
    Emily_Miller = "2024.10.28",
    Versace_Cozart = "2024.10.28",
    Alexey_Kudzaev = "2024.11.09",
	Corovar_Miror = "2024.11.25",
	Dmitry_Berlinetta = "2024.12.03",
	Kris_Sherman = "2024.11.25",
	Steven_Sadness = "2024.12.07",
	Steve_Lix = "2025.01.12",
}
local uidTable = {} -- Таблица для хранения уникальных UID
local function days_since_for_nick(nick)
    local date_str = allowed_nicks_date[nick]
    
    if not date_str then
        return "Ник не найден"
    end
    
    -- Разбор даты с проверкой
    local year, month, day = date_str:match("(%d%d%d%d).(%d%d).(%d%d)")
    
    if not (year and month and day) then
        return "Некорректный формат даты для ника " .. nick
    end

    -- Преобразование в числовые значения
    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    
    if not (year and month and day) then
        return "Ошибка преобразования даты для ника " .. nick
    end

    local start_date = os.time({year = year, month = month, day = day, hour = 0, min = 0, sec = 0})
    local current_date = os.time()

    if not start_date then
        return "Ошибка преобразования времени для ника " .. nick
    end

    local diff_in_days = math.floor(os.difftime(current_date, start_date) / (24 * 3600))
    return diff_in_days
end

-- Функция проверки, находится ли ник в списке разрешённых
local function isAllowedNick(nick)
  for _, allowed_nick in ipairs(allowed_nicks) do
      if nick == allowed_nick then
          return true
      end
  end
  return false
end
local playersToHeal = {} -- Таблица для хранения игроков, написавших "лек"

-- Функция для удаления цветовых кодов из строки
local function removeColorCodes(text)
    return text:gsub("{%x%x%x%x%x%x}", "") -- Убираем все цветовые коды формата {RRGGBB}
end






local wordFilePath = "moonloader/config/slova.txt"

local healKeywords = {}

local words = {}
local newWordInput = ""
local wordInputBuffer = ffi.new("char[256]")

local function createDirectoryIfNotExists(directory)
    local attr = lfs.attributes(directory)
    if not attr then
        lfs.mkdir(directory)  -- Создаем директорию
        print("Directory created: " .. directory)
    elseif attr.mode ~= "directory" then
        print(directory .. " is not a directory.")
    end
end

local function saveWords(text)
    local directory = "moonloader/config"
    createDirectoryIfNotExists(directory)  -- Создаем папку, если её нет

    local filePath = directory .. "/slova.txt"  -- Путь к файлу
    local file, err = io.open(filePath, "w")
    
    if not file then
        print("Error opening file: " .. err)  -- Выведет сообщение об ошибке
        return
    end

    -- Записываем слова в файл
    for _, word in ipairs(words) do
        file:write(word .. "\n")
    end
    file:close()
end











-- Загрузка ключевых слов при старте скрипта

-- Функция для сохранения слов в файл (опционально, если нужно сохранять изменения)



-- Функция для загрузки слов из файла
local function loadWords()
    local file = io.open(wordFilePath, "r")
    if file then
        for line in file:lines() do
            table.insert(words, line)
        end
        file:close()
    else
        -- Если файл не существует, создаем его
        saveWords(wordFilePath)
    end
end

-- Функция для сохранения слов в файл

local function formatColor(value)
    return string.format("%.3f", value)
end

local settingsFilePath = "moonloader/config/settings.json"
local settingsFilePathonline = "moonloader/config/online.json"
local windowVisiblelek = new.bool()
local windowVisible = new.bool()
local windowVisibleonline = new.bool()
local windowVisibleonline2 = new.bool()
local start_timereklama = new.bool()
local windowVisiblelekokno = new.bool()
local windowVisibkrvr = new.bool()

local lastMessageTime = 0
local messageInterval = 60000 -- Интервал в миллисекундах (например, 60 секунд)
local totalTimeInZone = {} -- Инициализация как таблицы
local isInZonePreviously = false -- Флаг для отслеживания, находится ли игрок в зоне
local lastZoneEntryTime = 0 -- Время последнего входа в зону
local procSymmaByDate = {}
local rankdate = {}
local lekdate = {}
local checkstats = {}
local startinfo = false

local mddate = {}
local invdate = {}
local uninvdate = {}
local color0 = 0
local color1 = 0
local color2 = 0
local color3 = 0
local loadstats = {}
-- Загрузка настроек из файла
local function loadSettings()
    local file = io.open(settingsFilePath, "r")
    if file then
        local content = file:read("*a")
        local savedSettings = decodeJson(content)
        file:close()
        if savedSettings then
            totalTimeInZone = savedSettings.totalTimeInZone or {}
            start_timereklama[0] = savedSettings.start_timereklama or false
            windowVisiblelekokno[0] = savedSettings.windowVisiblelekokno or false
            windowVisibkrvr[0] = savedSettings.windowVisibkrvr or false
            procSymmaByDate = savedSettings.procSymmaByDate or {} -- Загружаем procsymma по датам
			rankdate = savedSettings.rankdate or {}
			lekdate = savedSettings.lekdate or {}
			mddate = savedSettings.mddate or {}
			invdate = savedSettings.invdate or {}
			uninvdate = savedSettings.uninvdate or {}
            color3 = tonumber(savedSettings.color3) or 1.00
            color2 = tonumber(savedSettings.color2) or 0.10
            color1 = tonumber(savedSettings.color1) or 0.00
            color0 = tonumber(savedSettings.color0) or 0.30
        end
    end
end

-- Создаем таблицу для хранения процентов по датам

-- Сохранение настроек в файл
local function saveSettings()
    local file = io.open(settingsFilePath, "w+")
    if file then
        local settings = {
            totalTimeInZone = totalTimeInZone,
            start_timereklama = start_timereklama[0],
            windowVisiblelekokno = windowVisiblelekokno[0],
            windowVisibkrvr = windowVisibkrvr[0],
            procSymmaByDate = procSymmaByDate,
            rankdate = rankdate,
            lekdate = lekdate,
            mddate = mddate,
            invdate = invdate,
            uninvdate = uninvdate,
            color3 = formatColor(color3),
            color2 = formatColor(color2),
            color1 = formatColor(color1),
            color0 = formatColor(color0),
        }

        -- Сохраняем настройки
        file:write(encodeJson(settings))
        file:close()
    end
end
local function loadSettingsonline()
    local file = io.open(settingsFilePathonline, "r")
    if file then
        local content = file:read("*a")
        local savedSettings = decodeJson(content)
        file:close()
        if savedSettings then
			loadstats = savedSettings.checkstats or {}
        end
    end
end

local function saveSettingsonline()
    local file, err = io.open(settingsFilePathonline, "w+")
    if not file then
        print("Ошибка при открытии файла: " .. err)
        return
    end

    print("checkstats: " .. tostring(checkstats))

    -- Инициализация settings
    local settings = {}

    -- Проверка checkstats
    if checkstats ~= nil then
        settings.checkstats = checkstats
    else
        print("checkstats пусто или nil")
    end

    -- Сериализация данных
    local jsonData = encodeJson(settings)
    -- print("Сериализованные данные: " .. jsonData)

    -- Сохраняем настройки
    file:write(jsonData)
    file:close()
end



-- Функция для обновления времени, проведённого в зоне
local function updateZoneTime(currentTime)
    local today = os.date("%Y-%m-%d") -- Получаем текущую дату в формате ГГГГ-ММ-ДД
    local timeSpent = currentTime - lastZoneEntryTime -- Время, проведённое в зоне

    if not totalTimeInZone[today] then
        totalTimeInZone[today] = 0 -- Инициализация времени для текущего дня
    end
    totalTimeInZone[today] = totalTimeInZone[today] + timeSpent
end

local startreklama = true


local zone = {
    corner1 = {x = 2430.0, y = 1177.0}, -- Нижний левый угол
    corner2 = {x = 2430.0, y = 1200.0}, -- Верхний левый угол
    corner3 = {x = 2466.66, y = 1200.0}, -- Верхний правый угол
    corner4 = {x = 2466.66, y = 1177.0}, -- Нижний правый угол
    heightRange = {min = 916.0, max = 924.0} -- Диапазон по высоте
}

local messageInterval = 300000 -- Интервал сообщений (5 минут в миллисекундах)
local lastMessageTime = 0 -- Время последнего сообщения

local Info = true
function isInRectangleZone(x, y, z, zone)
    local isInXY = (x >= zone.corner1.x and x <= zone.corner3.x) and (y >= zone.corner1.y and y <= zone.corner2.y)
    local isInZ = (z >= zone.heightRange.min and z <= zone.heightRange.max)
    return isInXY and isInZ
end

local sellrang = false
local delltag = false
local infotag = ''
local namme = " "
local igrok = " "
local ranksell = false
local srok = 0
local ranksell2 = false
local selectedRank = 0
local ranksell245 = false
local ranksell24 = false
local ranksell23 = false
function parseDialogButtons(text)
    local buttons = {}
    for line in text:gmatch("[^\n]+") do
        local cleanLine = line:gsub("{%x%x%x%x%x%x}", "")  -- Убираем цветовые коды
        table.insert(buttons, cleanLine)
    end
    return buttons
end
local selectedWeek = 0 

function cmd_spcarall(arg)
    lua_thread.create(function ()
        arg = tonumber(arg)  -- Преобразуем 'arg' в число
        if arg and arg >= 10 and arg <= 60 then
            sampSendChat("/rb [Спавн ТС] Ув.Сотрудники через " .. arg .. " секунд будет спавн фракционого ТС!", -1)
            wait(1000)
            sampSendChat("/rb [Спавн ТС] Займите свой фракционный ТС, в противном случае он пропадет!", -1)
            spcartime = os.time()
            while os.time() - spcartime < arg do
                printStyledString("Spawn cars through: " .. arg - (os.time() - spcartime), 1, 6)
                wait(0)
            end
            sampAddChatMessage("Начинается спавн транспорта", -1)
            status_spcarall = true
            sampSendChat("/lmenu")
            dfssdsd = os.time()
            if os.time() - dfssdsd < 3 then
                while os.time() - dfssdsd < 3 and status_spcarall do
                    wait(0)
                end
            end
            status_spcarall = false
        else
            sampAddChatMessage(tag_q.."Укажите время в секундах (10-60 сек.)", -1)
        end
    end)
end

-- Создаем таблицу для хранения процентов по датам
local function formatMoney(value)
    value = tonumber(value) -- Убедитесь, что value является числом
    if not value then return "0" end -- Если value не число, возвращаем "0"
    
    local formatted = tostring(value)
    local reversed = formatted:reverse()
    local chunks = {}

    for i = 1, #reversed, 3 do
        table.insert(chunks, reversed:sub(i, i + 2))
    end

    return table.concat(chunks, "."):reverse() -- Объединяем и переворачиваем обратно
end
local nickbuy2 = 0
local rank2 = 0
local day2 = 0
local symmaday2 = 0
local symma2 = 0
local procsymma2 = 0
local moneyEarnedday2 = 0
local moneyEarned2 = 0
local statssend = false

local dateweek = "Нет информации"
local Monday1 = "Нет информации"
local Tuesday1 = 0
local Wednesday1 = "Нет информации"
local Thursday1 = "Нет информации"
local Friday1 = "Нет информации"
local Saturday1 = "Нет информации"
local Sunday1 = "Нет информации"

local Monday1manoy = "Нет информации"
local Tuesday1manoy = "Нет информации"
local Wednesday1manoy = "Нет информации"
local Thursday1manoy = "Нет информации"
local Friday1manoy = "Нет информации"
local Saturday1manoy = "Нет информации"
local Sunday1manoy = "Нет информации"
local timemein = "Нет информации"
local totalmoneyEarned2 = "Нет информации"
local totalranksell2 = "Нет информации"
local totalinv2 = "Нет информации"
local totaluninv2 = "Нет информации"
local totallek2 = "Нет информации"
local totalmd2 = "Нет информации"

local statsnick = {}
local nickname = "Nick_Name"



function checksms()
	lua_thread.create(function()
		while true do
			wait(0)
			wait(5000)
			if startinfo then
				check_new_messages()
			end
		end
	end)
end
function checkstats2()
	lua_thread.create(function()
		while true do
			wait(10000)
			local startDate, endDate
			local totalOnlineTime = 0 -- Переменная для общего времени
			local function parseDate(dateStr)
				local year, month, day = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
				return {day = tonumber(day), month = tonumber(month), year = tonumber(year)}
			end
			-- Функция для генерации всех дат с понедельника по воскресенье для указанной недели
			local function generateWeekDates(weekOffset)
				local dates = {}
				local currentDate = os.time() -- Текущая дата
			
				-- Вычисляем понедельник, отталкиваясь от текущей даты и смещения по неделям
				local currentWeekday = os.date("*t", currentDate).wday
				local lastMonday = currentDate - ((currentWeekday - 2) % 7) * 86400
				local targetMonday = lastMonday - (weekOffset * 7 * 86400) -- Учитываем смещение
			
				-- Генерируем даты с понедельника по воскресенье
				for i = 0, 6 do
					local date = os.date("%Y-%m-%d", targetMonday + i * 86400)
					table.insert(dates, date)
				end
			
				return dates
			end
			-- Генерируем даты для выбранной недели
	
			local dateRange = generateWeekDates(selectedWeek)
			local text = 7
			local totalmoneyEarned = 0
			local totalranksell = 0
			local totalinv = 0
			local totaluninv = 0
			local totallek = 0
			local totalmd = 0
			local totalOnlineTime = 0
	

			local function formatTime(milliseconds)
				if not milliseconds then
					return "00:00:00"  -- Если milliseconds равен nil, возвращаем "00:00:00"
				end
	
				local hours = math.floor(milliseconds / 3600000)
				local minutes = math.floor((milliseconds % 3600000) / 60000)
				local seconds = math.floor((milliseconds % 60000) / 1000)
				return string.format("%02d:%02d:%02d", hours, minutes, seconds)
			end
	
	
			-- Инициализация переменных для каждого дня недели
			-- Инициализация переменных для каждого дня недели на английском
			local daysOfWeek = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
			local timeSpentByDay = {Monday = 0, Tuesday = 0, Wednesday = 0, Thursday = 0, Friday = 0, Saturday = 0, Sunday = 0}
			local daysOfWeek2 = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
			local manoySpentByDay = {Monday = 0, Tuesday = 0, Wednesday = 0, Thursday = 0, Friday = 0, Saturday = 0, Sunday = 0}
			-- Сортировка dateRange по порядку
			table.sort(dateRange)
	
			for i, day in ipairs(dateRange) do
				local timeSpent = totalTimeInZone[day] or 0
				local moneyEarned = (procSymmaByDate[day] and procSymmaByDate[day]) or 0
				local rankdateEarned = (rankdate[day] and rankdate[day]) or 0
				local lekdateEarned = (lekdate[day] and lekdate[day]) or 0
				local mddateEarned = (mddate[day] and mddate[day]) or 0
				local invdateEarned = (invdate[day] and invdate[day]) or 0
				local uninvdateEarned = (uninvdate[day] and uninvdate[day]) or 0
	
				totaluninv = totaluninv + uninvdateEarned
				totalinv = totalinv + invdateEarned
				totallek = totallek + lekdateEarned
				totalmd = totalmd + mddateEarned
				totalOnlineTime = totalOnlineTime + timeSpent
				totalmoneyEarned = totalmoneyEarned + moneyEarned
				totalranksell = totalranksell + rankdateEarned
				-- Добавим логирование, чтобы увидеть, что мы получаем из dateRange
				if #dateRange > 0 then
					-- Сортируем даты, если они не отсортированы
					table.sort(dateRange)
					
					-- Получаем первую и последнюю дату
					startDate = dateRange[1]  -- Первая дата
					endDate = dateRange[#dateRange]  -- Последняя дата
				end
				
				-- Проверка на nil перед использованием переменной endDate
	
				
				-- Отображаем данные
				local formattedTime = formatTime(timeSpent)

	
				local formattedMoney = formatMoney(moneyEarned)

				-- Присваиваем значение времени для каждого дня недели по порядку
				if i <= #daysOfWeek then
					local currentDay = daysOfWeek[i]  -- Получаем день недели по порядку
					timeSpentByDay[currentDay] = timeSpent
				end
				if i <= #daysOfWeek2 then
					local currentDay = daysOfWeek2[i]  -- Получаем день недели по порядку
					manoySpentByDay[currentDay] = moneyEarned
				end
			end
			totalmoneyEarned2 = totalmoneyEarned
			totalranksell2 = totalranksell
			totalinv2 = totalinv
			totaluninv2 = totaluninv
			totallek2 = totallek
			totalmd2 = totalmd
			dateweek = startDate.." - "..endDate
			Monday1 = formatTime(timeSpentByDay.Monday)
			Tuesday1 = formatTime(timeSpentByDay.Tuesday)
			Wednesday1 = formatTime(timeSpentByDay.Wednesday)
			Thursday1 = formatTime(timeSpentByDay.Thursday)
			Friday1 = formatTime(timeSpentByDay.Friday)
			Saturday1 = formatTime(timeSpentByDay.Saturday)
			Sunday1 = formatTime(timeSpentByDay.Sunday)
			Monday1manoy = formatMoney(manoySpentByDay.Monday)
			Tuesday1manoy = formatMoney(manoySpentByDay.Tuesday)
			Wednesday1manoy = formatMoney(manoySpentByDay.Wednesday)
			Thursday1manoy = formatMoney(manoySpentByDay.Thursday)
			Friday1manoy = formatMoney(manoySpentByDay.Friday)
			Saturday1manoy = formatMoney(manoySpentByDay.Saturday)
			Sunday1manoy = formatMoney(manoySpentByDay.Sunday)
			local totalHours = math.floor(totalOnlineTime / 3600000)
			local totalMinutes = math.floor((totalOnlineTime % 3600000) / 60000)
			local totalSeconds = math.floor((totalOnlineTime % 60000) / 1000)
			totalmoneyEarned2 = formatMoney(totalmoneyEarned)
			timemein = ("%02d:%02d:%02d"):format(totalHours, totalMinutes, totalSeconds)
			statssend = true
			wait(1800000)
		end
	end)
end
function samp.onShowDialog(dialogId, style, title, button1, button2, text)
    if title:find("Основная статистика") and Info then
        id = select(2, sampGetPlayerIdByCharHandle(playerPed))
        nick = sampGetPlayerNickname(id)
        if not sampGetDialogCaption():find("Выберите действие") and Info then
            local frac, rank = text:match("Организация:.*}%[(.*)%].*Должность:.*(%d+)%).*Уро")
            if nick == "Mao_Shelby" or nick == "Miya_Shelby" or nick == "Yumi_Shelby" then
                print("У вас доступ разработчика!")
            else
                if frac ~= "Больница СФ" then
                    sampAddChatMessage(tag_q.."Скрипт работает только для замов СФМЦ", -1)
                    thisScript():unload() 
                elseif rank ~= "9" and rank ~= "0" then
                    sampAddChatMessage(tag_q.."Скрипт работает только для замов СФМЦ", -1)
                    thisScript():unload() 
                end
            end
			sampSendDialogResponse(dialogId, 0, nil)
			sampCloseCurrentDialogWithButton(0)
        end
        return false
    end
    if dialogId == 15024 then
        if delltag then
            sampSendDialogResponse(dialogId, 1, nil)
            sampCloseCurrentDialogWithButton(1)
            sampSendChat(infotag)
            return false 
        end
    end
	if dialogId == 1214 then
        if sellrang then
            sampSendDialogResponse(dialogId, 1, 20, nil)

            sampCloseCurrentDialogWithButton(1)
			return false 
		end
		if ranksell then
			sampSendDialogResponse(dialogId, 1, 20, nil)
            sampCloseCurrentDialogWithButton(1)
			return false 
        end
		if status_spcarall then
			status_spcarall = false
			sampSendChat("/rb [Спавн ТС] Весь фракционный ТС успешно был заспавнен!", -1)
			sampSendDialogResponse(dialogId, 1, 3, nil)
			return false
		end
    end
	if dialogId == 27266 then
		if sellrang then
			if text:find("Дистанция(.+)") then
				 
				namme = text:match("Дистанция(.+)")
				sellrang = false
				sampSendDialogResponse(dialogId, 0, nil)
				return false 
			end
		elseif ranksell then
			text = parseDialogButtons(text)
            for buttonIndex, buttonText in ipairs(text) do
                if buttonText:find(igrok) then
                    sampSendDialogResponse(dialogId, 1, buttonIndex - 2, nil) -- Нажимаем на найденную кнопку
					ranksell = false
					ranksell2 = true
                    break
                end
            end
		end
	end
	if dialogId == 27267 then
		if ranksell2 then
			if selectedRank == 4 then
				sampSendDialogResponse(dialogId, 1, 5-1, nil)
			else
				sampSendDialogResponse(dialogId, 1, selectedRank-1, nil)
			end

			ranksell2 = false
			ranksell23 = true
			return false 
		end
	end
	if dialogId == 27268 then
		if ranksell23 then
			sampSendDialogResponse(dialogId, 1, nil, srok)
			ranksell23 = false
			ranksell24 = true
			return false 
		end
	end
	if dialogId == 27269 then
		if ranksell24 then
			local symma = 0
			if selectedRank == 0 then
				symma = 0
			elseif selectedRank == 4 then
				symma = 200000
			elseif selectedRank == 5 then
				symma = 333334
			elseif selectedRank == 6 then
				symma = 3592000
			elseif selectedRank == 7 then
				symma = 4286000
			elseif selectedRank == 8 then
				symma = 5000000
			end
			sampSendDialogResponse(dialogId, 1, nil, symma)
			ranksell24 = false
			ranksell245 = true
			return false 
		end 
	end 

    if dialogId == 27270 then
        if text:find("{FFFFFF}Выбранный игрок: {90EE90}(.+)%{FFFFFF}Выбранный ранг: {90EE90}(.+)%{FFFFFF}Выбранное кол%-%во дней: {90EE90}(.+)%{FFFFFF}Выбранная стоимость за день: {90EE90}(.+)%{FFFFFF}Общая стоимость: {90EE90}(.+)%{FFFFFF}Ваш процент: {90EE90}(.+)%{FFFFFF}Отправьте подтверждение игроку нажав") then
            local nickbuy, rank, day, symmaday, symma, procsymma = text:match("{FFFFFF}Выбранный игрок: {90EE90}(.+)%{FFFFFF}Выбранный ранг: {90EE90}(.+)%{FFFFFF}Выбранное кол%-%во дней: {90EE90}(.+)%{FFFFFF}Выбранная стоимость за день: {90EE90}(.+)%{FFFFFF}Общая стоимость: {90EE90}(.+)%{FFFFFF}Ваш процент: {90EE90}(.+)%{FFFFFF}Отправьте подтверждение игроку нажав")
            id = select(2, sampGetPlayerIdByCharHandle(playerPed))
            nick = sampGetPlayerNickname(id)

            -- Получаем текущую дату
            local today = os.date("%Y-%m-%d")
    

            procsymma = procsymma:gsub("%s%(%d+%%%)", "")
            procsymma = procsymma:gsub("%$", "")       -- Удаляем доллар
            procsymma = procsymma:gsub("%s+", "")      -- Удаляем все пробелы (можно заменить на gsub("%s", "") для удаления только одного пробела)
            procsymma = procsymma:gsub("%.", "") 
			procsymma = procsymma:gsub("%,", "")        -- Удаляем точку
            -- Инициализируем таблицу для текущего дня, если она отсутствует
			local numericValue = tonumber(procsymma)

            local function generateWeekDates(weekOffset)
                local dates = {}
                local currentDate = os.time() -- Текущая дата
            
                -- Вычисляем понедельник, отталкиваясь от текущей даты и смещения по неделям
                local currentWeekday = os.date("*t", currentDate).wday
                local lastMonday = currentDate - ((currentWeekday - 2) % 7) * 86400
                local targetMonday = lastMonday - (weekOffset * 7 * 86400) -- Учитываем смещение
            
                -- Генерируем даты с понедельника по воскресенье
                for i = 0, 6 do
                    local date = os.date("%Y-%m-%d", targetMonday + i * 86400)
                    table.insert(dates, date)
                end
            
                return dates
            end
  


            local dateRange = generateWeekDates(selectedWeek)

            local moneyEarned12 = 0
            for _, day in ipairs(dateRange) do
                local moneyEarned1 = (procSymmaByDate[day] and procSymmaByDate[day]) or 0 -- Получаем сумму для текущей даты
                moneyEarned12 = moneyEarned12 + moneyEarned1
            end
			local moneyEarned = formatMoney(moneyEarned12)
			nickbuy2 = nickbuy
			rank2 = rank
			day2 = day
			symmaday2 = symmaday
			symma2 = symma
			procsymma2 = procsymma
			moneyEarnedday2 = numericValue
			moneyEarned2 = moneyEarned

            if ranksell245 then
            	sampSendDialogResponse(dialogId, 1, nil)
            	ranksell245 = false
            	return false 
            end
        end
    end
    

    
    
    return {dialogId, style, title, button1, button2, text}
end 


function cmd_update(arg)
	local randomNumber = math.random(1, 1000000)

    sampShowDialog(1000, "Доступна новая версия скрипта", "{FFFFFF}\n{FFF000}Новая версия: "..script_vers_text, "Закрыть", "", 0)
end
-- {FFFFFF}Выбранный игрок: {90EE90}(.+)%{FFFFFF}Выбранный ранг: {90EE90}(.+)%{FFFFFF}Выбранное кол-во дней: {90EE90}(.+)% {FFFFFF}Выбранная стоимость за день: {90EE90}(.+)% {FFFFFF}Общая стоимость: {90EE90}(.+)% {FFFFFF}Ваш процент: {90EE90}(.+)% {FFFFFF}Отправьте подтверждение игроку нажав
local checknick = 0
local okno = false


local iconv = require("iconv")
local utf8_to_cp1251 = iconv.new("CP1251", "UTF-8") -- Пример конверсии в cp1251, если необходимо

local function loadHealKeywords()
    local file = io.open(wordFilePath, "r")
    if file then
        healKeywords = {}  -- Очищаем таблицу перед загрузкой
        for line in file:lines() do
            local converted_line = utf8_to_cp1251:iconv(line)
            if converted_line then
                table.insert(healKeywords, converted_line)  -- Добавляем слово из файла в таблицу
            else
                print("Ошибка конвертации строки: " .. line)
            end
        end
        file:close()
    else
        healKeywords = { "лек", "лекни", "вылечи", "lek" }
        saveWords(wordFilePath)  
    end
end


function cmd_send(arg)
    -- Проверка, указаны ли ник и сообщение
    if not arg or not arg:find(" ") then
        sampAddChatMessage(tag_q.."Использование: /smsg [ник] [сообщение]", -1)
        return
    end

    -- Разделяем аргументы на ник и сообщение
    local nick, message = arg:match("^(%S+)%s+(.+)$")
    if not nick or not message then
        sampAddChatMessage(tag_q.."Ошибка: Некорректный ввод. Используйте /smsg [ник] [сообщение]", -1)
        return
    end
	local randomNumber = math.random(1, 1000000)
	-- sampAddChatMessage(randomNumber)

    local data = {
        message = toUtf8("Отправка сообщения"),
        sender = getNickname(),
		nickcheck = getNickname(),
        statsinfo = {
            tipsend = 2,
			uid = randomNumber,
            nicksend = nick,
            sms = toUtf8(message),
        }
    }
    startinfo = true
    cmd_send_message(data)
    sampAddChatMessage(tag_q.."Сообщение успешно отправлено игроку " .. nick, -1)
end




function cmd_upinfo(arg)
    -- Проверка, указаны ли ник и сообщение
    if not arg or not arg:find(" ") then
        sampAddChatMessage(tag_q.."Использование: /upinfo [ник] [сообщение]", -1)
        return
    end

    -- Разделяем аргументы на ник и сообщение
    local nick, message = arg:match("^(%S+)%s+(.+)$")
    if not nick or not message then
        sampAddChatMessage(tag_q.."Ошибка: Некорректный ввод. Используйте /upinfo [ник] [сообщение]", -1)
        return
    end
	local randomNumber = math.random(1, 1000000)
	-- sampAddChatMessage(randomNumber)

    local data = {
        message = toUtf8("Отправка сообщения"),
        sender = getNickname(),
		nickcheck = nick,
        statsinfo = {
            tipsend = 3,
			uid = randomNumber,
            nicksend = nick,
            sms = toUtf8(message),
        }
    }
	startinfo = true
	
    -- Отправляем данные
    cmd_send_message(data)
    sampAddChatMessage(tag_q.."Сообщение успешно отправлено игроку " .. nick, -1)
end

local minute = os.date("*t").min


local memory = require 'memory'

-- Объявляем необходимые Windows API функции через FFI
ffi.cdef[[
    typedef int BOOL;
    typedef void* HANDLE;
    typedef unsigned long DWORD;
    typedef unsigned long SIZE_T;
    typedef struct _PROCESS_MEMORY_COUNTERS {
        DWORD cb;
        DWORD PageFaultCount;
        SIZE_T PeakWorkingSetSize;
        SIZE_T WorkingSetSize;
        SIZE_T QuotaPeakPagedPoolUsage;
        SIZE_T QuotaPagedPoolUsage;
        SIZE_T QuotaPeakNonPagedPoolUsage;
        SIZE_T QuotaNonPagedPoolUsage;
        SIZE_T PagefileUsage;
        SIZE_T PeakPagefileUsage;
    } PROCESS_MEMORY_COUNTERS;

    HANDLE GetCurrentProcess(void);
    BOOL GetProcessMemoryInfo(HANDLE Process, PROCESS_MEMORY_COUNTERS* ppsmemCounters, DWORD cb);
    BOOL EmptyWorkingSet(HANDLE Process);
    BOOL SetProcessWorkingSetSize(HANDLE Process, SIZE_T dwMinimumWorkingSetSize, SIZE_T dwMaximumWorkingSetSize);
]]

local kernel32 = ffi.load('kernel32')
local psapi = ffi.load('psapi')

-- Функция для получения текущего использования памяти
function getCurrentMemoryUsage()
    local pmc = ffi.new('PROCESS_MEMORY_COUNTERS')
    pmc.cb = ffi.sizeof(pmc)
    local process = kernel32.GetCurrentProcess()
    if psapi.GetProcessMemoryInfo(process, pmc, ffi.sizeof(pmc)) then
        return tonumber(pmc.WorkingSetSize)
    end
    return 0
end

-- Функция для очистки памяти
function cleanMemory()
    local process = kernel32.GetCurrentProcess()
    -- Очищаем рабочий набор процесса
    kernel32.SetProcessWorkingSetSize(process, -1, -1)
    -- Принудительно очищаем неиспользуемую память
    collectgarbage("collect")
end

-- Основная функция мониторинга и очистки памяти
-- Основная функция мониторинга и очистки памяти
function memoryCleanerThread()
    local lastCleanTime = os.clock()
    local memoryThreshold = 500 * 1024 * 1024 -- 500 MB
    local cleanInterval = 300 -- 5 минут

    while true do
        local success, err = pcall(function()
            ::continue::
            wait(1000) -- Проверяем каждую секунду

            if not cleanMemory or not getCurrentMemoryUsage then
                print("Ошибка: Не найдены необходимые функции cleanMemory или getCurrentMemoryUsage")
                wait(1000) -- Ждем перед повторной проверкой
                goto continue
            end

            local currentTime = os.clock()
            local currentMemory = getCurrentMemoryUsage()

            if (currentTime - lastCleanTime > cleanInterval) or (currentMemory > memoryThreshold) then
                cleanMemory()
                lastCleanTime = currentTime

                local memoryUsageAfter = getCurrentMemoryUsage()
                local memoryFreed = (currentMemory - memoryUsageAfter) / (1024 * 1024)
                if memoryFreed > 0 then
                    print(string.format("Очистка памяти: освобождено %.2f MB", memoryFreed))
                end
            end

            if currentMemory > memoryThreshold * 1.5 then
                print("Внимание: Высокое потребление памяти! Выполняется экстренная очистка...")
                cleanMemory()
                wait(1000)
                cleanMemory()
            end
        end)

        if not success then
            print("Ошибка в процессе очистки памяти: ", err)
            wait(1000) -- Даем время на восстановление
        end
    end
end


function initMemoryCleaner()
    local success, err = pcall(function()
        lua_thread.create(memoryCleanerThread)
        print("Система очистки памяти успешно активирована.")
    end)

    if not success then
        print("Ошибка при инициализации системы очистки памяти:", err)
    end
end

local totalTimet = 180 -- Общее время таймера в секундах
local startTime = os.time() -- Время старта таймера

local currentTime = os.time()
local elapsedTime = os.difftime(currentTime, startTime)
local remainingTime = math.max(0, totalTimet - elapsedTime)


function drawCircularTimer(x, y, radius, remainingTime, totalTimet)
    local ImGui = imgui
    local draw_list = ImGui.GetWindowDrawList()

    -- Определяем параметры для визуализации таймера
    local start_angle = 3 * math.pi / 2
    local end_angle = start_angle + (2 * math.pi) * (remainingTime / totalTimet)

    -- Цвета
    local timerColor = ImGui.ColorConvertFloat4ToU32(ImGui.ImVec4(0.2, 0.7, 0.3, 1)) -- Зеленый
    local backgroundColor = ImGui.ColorConvertFloat4ToU32(ImGui.ImVec4(0.2, 0.2, 0.2, 0.3)) -- Темно-серый

    -- Рисуем фон таймера
    draw_list:AddCircleFilled(ImGui.ImVec2(x, y), radius, backgroundColor, 64)

    -- Рисуем оставшееся время таймера
    if remainingTime > 0 then
        draw_list:PathArcTo(ImGui.ImVec2(x, y), radius - 1, start_angle, end_angle, 64)
        draw_list:PathStroke(timerColor, false, 2)
    end

    -- Текст с оставшимся временем
    local timeText = string.format("%.2f", remainingTime)
    local textSize = ImGui.CalcTextSize(timeText)
    draw_list:AddText(ImGui.ImVec2(x - textSize.x / 2, y - textSize.y / 2), ImGui.ColorConvertFloat4ToU32(ImGui.ImVec4(1, 1, 1, 1)), timeText)
end



-- local nickglobal = ""
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end
    checkForUpdate()
    sampAddChatMessage(" ", -1)
    sampAddChatMessage(tag_q.."Скрипт успешно загружен!", 0x9370DB)
    sampAddChatMessage(" ", -1)
    sampRegisterChatCommand("hl", cmd_hl)
    sampRegisterChatCommand("md", cmd_md)
    sampRegisterChatCommand("gb", cmd_book)
    sampRegisterChatCommand("inv", cmd_inv)
	sampRegisterChatCommand('rspcar', cmd_spcarall)
    sampRegisterChatCommand("updates", cmd_update)

    loadWords()
	checksms()
	checkstats2()
    loadSettings()
	loadSettingsonline()
    loadHealKeywords()
	initMemoryCleaner()

    id = select(2, sampGetPlayerIdByCharHandle(playerPed))
    self = {
		nick = sampGetPlayerNickname(id),
		score = sampGetPlayerScore(id),
		color = sampGetPlayerColor(id),
		ping = sampGetPlayerPing(id),
		gameState = sampGetGamestate()
    }
	checknick = self.nick
	local font_path = getWorkingDirectory()..'\\EagleSans-Reg.ttf'
	local file = io.open(font_path, "r")
	if not file then
		print("Файл шрифта не найден, используется Verdana.")
		my_font = renderCreateFont('Verdana', 10, font_flag.BOLD + font_flag.SHADOW)
	else
		file:close() -- Закрываем файл после проверки
		my_font = renderCreateFont(font_path, 10, font_flag.BOLD + font_flag.SHADOW)
	end
    if isAllowedNick(self.nick) then
        print("Успешно!")
    else
        sampAddChatMessage(tag_q.."Работает только для разрешённых пользователей.", -1)
        thisScript():unload() 
    end
    if self.nick == "Yumi_Shelby" or self.nick == "Mao_Shelby" or self.nick == "Miya_Shelby" then
        sampRegisterChatCommand('smsg', cmd_send)
		sampRegisterChatCommand('upinfo', cmd_upinfo)
        sampRegisterChatCommand('smsg_debug', cmd_toggle_debug)
    end
    local ip, port = sampGetCurrentServerAddress()
     if ip == "80.66.82.168" then
        sampAddChatMessage(tag_q.."Поддержка сервера Page", -1)
    else
        sampAddChatMessage(tag_q.."Скрипт работает только на сервере Arizona RP - Page ", -1)
        thisScript():unload() 
    end
    sampRegisterChatCommand("sfmc", function()
        windowVisible[0] = not windowVisible[0]
		windowVisibleonline2[0] = false
        if not windowVisible[0] then
            hideCursor() 
        end
    end)
    sampRegisterChatCommand("online", function()
        windowVisibleonline[0] = not windowVisibleonline[0]
        if not windowVisibleonline[0] then
            hideCursor() 
        end
    end)
  while true do

    if startreklama == false then  
        start_timereklamavr = os.time()
        startreklama = true
    end
    if start_timereklamavr and windowVisibkrvr[0] then
        local current_timereklama = os.time()
        local elapsed_timereklama = current_timereklama - start_timereklamavr
        local remaining_timereklama = 180 - elapsed_timereklama
  
        if remaining_timereklama > 0 then
          local textreklama = string.format("{80FFFFFF}КД на /vr: %d секунд", remaining_timereklama)
          local x = screenX * 0.03 
          local y = screenY * 0.65 

        --   renderFontDrawText(my_font, textreklama, x, y, 0xFFFFFFFF)
        else
          start_timereklamavr = nil  
        end
    end
    local player = PLAYER_PED -- Получаем указатель на игрока
    if isCharInAnyCar(player) or isCharOnFoot(player) then -- Проверка на наличие персонажа
        local success, x, y, z = pcall(getCharCoordinates, player) -- Обернули в pcall для обработки ошибок
        if not success or x == nil or y == nil or z == nil then
            print("Ошибка получения координат игрока!")
        else
			id = select(2, sampGetPlayerIdByCharHandle(playerPed))
			intcolor = sampGetPlayerColor(id) -- 2164227710
			if intcolor == 2164227710 then
				if isInRectangleZone(x, y, z, zone) then
					local currentTime = os.clock() * 1000
					id = select(2, sampGetPlayerIdByCharHandle(player))
					nickglobal = sampGetPlayerNickname(id)

					if not isInZonePreviously then
						-- Игрок вошёл в зону
						lastZoneEntryTime = currentTime
						isInZonePreviously = true

						local randomMinutes = math.random(1, 5)
						local randomSeconds = math.random(0, 59)
						nextSaveTime = currentTime + (randomMinutes * 60000) + (randomSeconds * 1000)
					else
						-- Игрок всё ещё в зоне, обновляем время
						updateZoneTime(currentTime)
						lastZoneEntryTime = currentTime

						if currentTime >= nextSaveTime then
							saveSettings()

							local randomMinutes = math.random(1, 5)
							local randomSeconds = math.random(0, 59)
							nextSaveTime = currentTime + (randomMinutes * 60000) + (randomSeconds * 1000)
						end
					end

					if currentTime - lastMessageTime > messageInterval then

						local currentTimee = os.date("%H:%M:%S") 
						
						local message = "["..currentTimee.."] "..nickglobal.." находится в холле"
						local inputGroup = "-1002388389043"
						
		
			
						sendTelegram(message, inputGroup)
						-- SendWebhook('https://discord.com/api/webhooks/1288955003729481828/oNZf4HehjbJKa3Zz2jj3jd1L2zx7p38XCrtPuQrfIRRCInrUa621UPeytVLlsX58efB1', ([[{
						--     "content": "[%s] **%s** находится в холле",
						--     "embeds": [],
						--     "attachments": []
						-- }]]):format(currentTimee, nick))
						
						lastMessageTime = currentTime
					end
				else
					if isInZonePreviously then
						-- Игрок покинул зону
						local currentTime = os.clock() * 1000
						updateZoneTime(currentTime)
						isInZonePreviously = false
						saveSettings()
					end
				end
			end
        end
    end
    
    wait(0)
    if start_timereklama[0] then
        local textreklama = string.format("{80FFFFFF}/hl - вылечить\n/md - медкарта\n/gb - трудовая\n/medcheck - мед.обследование\n/healbad - вылечить от нарко\n/recept - выдать рецепт\n/givemedinsurance - страховка\n/healactor - вылечить охранника\n/expel - выгнать")
        local x = screenX * 0.03 
        local y = screenY * 0.45 
        renderFontDrawText(my_font, textreklama, x, y, 0xFFFFFFFF)
    end

    if wasKeyPressed(vkeys.VK_H) and not sampIsChatInputActive() then
        sampSendChat("/opengate")
    end
    if wasKeyPressed(vkeys.VK_RETURN) and not sampIsChatInputActive() then
        okno = true
    end 
    if windowVisible[0] or windowVisibleonline[0] or windowVisiblelek[0] or windowVisibleonline2[0] or windowVisiblkd[0] then  --
        imgui.Process = true
    else
        imgui.Process = false
    end
    if Info then
        wait(1000)
        sampSendChat("/stats")
        wait(500)
        Info = false
    end

    if minute == 00 then
		checkForUpdatechas()
        wait(60000)  -- Ждём 1 минуту, чтобы избежать повторного выполнения в течение текущего часа
    end
	-- check_new_messages()
	if statssend then
		wait(1000)
		local today = os.date("%m-%d %H:%M")
		local randomNumber = math.random(1, 1000000)
		local data = {
			message = toUtf8("Передача данных"),
			sender = getNickname(),
			statsinfo = {
				tipsend = 1,
				uid = randomNumber,
				updateinfo = script_vers_text,
				dateweekinfo = toUtf8(dateweek),
				Monday1info = toUtf8(Monday1),
				Tuesday1info = toUtf8(Tuesday1),
				Wednesday1info = toUtf8(Wednesday1),
				Thursday1info = toUtf8(Thursday1),
				Friday1info = toUtf8(Friday1),
				Saturday1info = toUtf8(Saturday1),
				Sunday1info = toUtf8(Sunday1),
				Monday1manoyinfo = toUtf8(Monday1manoy),
				Tuesday1manoyinfo = toUtf8(Tuesday1manoy),
				Wednesday1manoyinfo = toUtf8(Wednesday1manoy),
				Thursday1manoyinfo = toUtf8(Thursday1manoy),
				Friday1manoyinfo = toUtf8(Friday1manoy),
				Saturday1manoyinfo = toUtf8(Saturday1manoy),
				Sunday1manoyinfo = toUtf8(Sunday1manoy),
				timemeininfo = toUtf8(timemein),
				totalmoneyEarned2info = toUtf8(totalmoneyEarned2),
				totalranksell2info = toUtf8(totalranksell2),
				totalinv2info = toUtf8(totalinv2),
				totaluninv2info = toUtf8(totaluninv2),
				totallek2info = toUtf8(totallek2),
				totalmd2info = toUtf8(totalmd2),
				totaltime = toUtf8(today),
			}
		}
		cmd_send_message(data)
		statssend = false
	end
  end
end






local enteredWeeks = new.int(0)
local enteredPlayerID = new.char[256]()


selectedButton = ""


function addPlayerToHeal(playerID, playerName)
    playersToHeal[playerID] = playerName
    windowVisiblelek[0] = true 
end

function removePlayerFromHeal(playerID)
    playersToHeal[playerID] = nil
    if next(playersToHeal) == nil then
        windowVisiblelek[0] = false 
    end
end




local system = 0

local isPlayerIDWindowVisible = false
local rolerp = " "

local function trim(s)
    return (s:gsub("^%s*(.-)%s*$", "%1"))
end
local currentPlayerIndex = 1  
local font = {}
imgui.OnInitialize(function()
    local glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
    local path = getWorkingDirectory()..'\\EagleSans-Reg.ttf'
	print(path)
	local file = io.open(path, "r")
	if not file then
		print("Файл не найден: " .. path)
	else
		file:close()
		imgui.GetIO().Fonts:Clear() -- Удаляем стандартный шрифт на 14
		imgui.GetIO().Fonts:AddFontFromFileTTF(path, 15.0, nil, glyph_ranges) -- этот шрифт на 15 будет стандартным
	end
    -- дополнительные шриты:
    font[25] = imgui.GetIO().Fonts:AddFontFromFileTTF(path, 25.0, nil, glyph_ranges)
    font[20] = imgui.GetIO().Fonts:AddFontFromFileTTF(path, 18.0, nil, glyph_ranges)
	font[21] = imgui.GetIO().Fonts:AddFontFromFileTTF(path, 19.0, nil, glyph_ranges)
end)





local progress = 0 -- начальный прогресс
local speed = 0.5 -- скорость прогресса (можно регулировать)




local newFrame4 = imgui.OnFrame( --[[Сама функция создания фрейма, их может быть сколько вашей душе угодно.
                                    Обратите внимание, что в mimgui рекомендуется создавать отдельный
                                    фрейм для каждого окна, однако это не является обязательным.]]
    function() return windowVisibleonline2[0] end, -- Определяет, выполняется/отображается ли текущий фрейм.
    function(player2)            --[[Сама область, в которой уже будем рисовать элементы.
                                    В функцию в качестве первой переменной передаются список функций
                                    для взаимодействия с локальным игроком и рядом нескольких возможностей.]]
		applyCustomTheme()
		imgui.ShowCursor = true
		local startDate, endDate
		local screenX, screenY = getScreenResolution()
		local windowWidth, windowHeight = 750, 300 -- увеличена высота для отображения всех элементов
		local posX = (screenX - windowWidth) / 2
		local posY = (screenY - windowHeight) / 2
	
		imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Once)
		imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Once)
	
		local windowFlags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar


		imgui.Begin(u8"##", windowVisibleonline2, windowFlags)
		local windowPos = imgui.GetWindowPos()
		local windowSize = imgui.GetWindowSize()
		
		-- Размеры для кнопок
		local buttonWidth = 50
		local buttonHeight = 50
		local selectedOption = 1 -- Предположим, 1 - это первый вариант
		-- Устанавливаем позицию курсора для первой кнопки (правый верхний угол)
		

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight - 35)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushFont(font[25])
		imgui.Text(u8"АКТИВНОСТЬ ЗА НЕДЕЛЮ "..nickname) -- Текст слева от радиокнопки
		imgui.PopFont()
		
		-- -- statsnick.Tuesday1manoyinfo


		imgui.PushFont(font[20])




		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, 40 + 220)) -- Отступ от правого края и ниже первой кнопки
		if imgui.Button(u8"Закрыть", imgui.ImVec2(180, 30)) then
			windowVisibleonline2[0] = false
			imgui.ShowCursor = false
		end
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 500, 40 + 220)) -- Отступ от правого края и ниже первой кнопки
		if imgui.Button(u8"Обновить", imgui.ImVec2(80, 30)) then
			local randomNumber = math.random(1, 1000000)
			local data = {
				message = toUtf8("Отправка сообщения"),
				sender = getNickname(),
				nickcheck = nickname,
				statsinfo = {
					tipsend = 3,
					uid = randomNumber,
					nicksend = nickname,
				}
			}
			cmd_send_message(data)
			windowVisible[0] = true
			windowVisibleonline2[0] = false
			-- imgui.ShowCursor = false
			selectedButton = "lodiing"
			startinfo = true
			sampAddChatMessage(tag_q.."Попытка получить данные.", -1)
		end

		local sideWidth = 445 
		local availableHeight = 25
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 83)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline2", imgui.ImVec2(sideWidth, availableHeight), false)
		imgui.EndChild()
		imgui.PopStyleColor()

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 133)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline3", imgui.ImVec2(sideWidth, availableHeight), false)
		imgui.EndChild()
		imgui.PopStyleColor()


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 183)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline4", imgui.ImVec2(sideWidth, availableHeight), false)
		-- Ваш код внутри окна
		imgui.EndChild()
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному
		


		local sideWidth = 445 
		local availableHeight = 185
		
		-- Устанавливаем позицию следующего дочернего окна
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 55)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.00, 0.00, 0.00, 0.60))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline", imgui.ImVec2(sideWidth, availableHeight), true)
		




		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 7))
		imgui.Text((u8"Online: ".. (statsnick.Monday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 7))
		imgui.Text((u8"Sell: "..(statsnick.Monday1manoyinfo or "Нет информации").."$"))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 32))
		imgui.Text((u8"Online: "..(statsnick.Tuesday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 32))
		imgui.Text((u8"Sell: "..(statsnick.Tuesday1manoyinfo or "Нет информации").."$"))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 57))
		imgui.Text((u8"Online: "..(statsnick.Wednesday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 57))
		imgui.Text((u8"Sell: "..(statsnick.Wednesday1manoyinfo or "Нет информации").."$"))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 82))
		imgui.Text((u8"Online: "..(statsnick.Thursday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 82))
		imgui.Text((u8"Sell: "..(statsnick.Thursday1manoyinfo or "Нет информации").."$"))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 107))
		imgui.Text((u8"Online: "..(statsnick.Friday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 107))
		imgui.Text((u8"Sell: "..(statsnick.Friday1manoyinfo or "Нет информации").."$"))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 132))
		imgui.Text((u8"Online: "..(statsnick.Saturday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 132))
		imgui.Text((u8"Sell: "..(statsnick.Saturday1manoyinfo or "Нет информации").."$"))
		

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, 157))
		imgui.Text((u8"Online: "..(statsnick.Sunday1info or "Нет информации")))


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, 157))
		imgui.Text((u8"Sell: "..(statsnick.Sunday1manoyinfo or "Нет информации").."$"))
		-- imgui.Separator()
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 7)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Понедельник") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 32)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Вторник") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 57)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Среда") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 82)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Четверг") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 107)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Пятница") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 132)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Суббота") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 157)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Воскресенье") -- Если времени нет, отображаем 00:00:00
		imgui.EndChild()
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight - 10)) -- Отступ от правого края и ниже первой кнопки
		local titleColor = imgui.ImVec4(0.50, 0.00, 0.15, 1.00)  -- Цвет для "Общая сумма sell:"

		imgui.Text((u8""..(statsnick.dateweekinfo or "Нет информации")..u8"  Версия обновления: "..(statsnick.updateinfo or "Нет информации")..u8"\nДата получения информации: "..(statsnick.totaltime or "Нет информации"))) -- Текст слева от радиокнопки


		
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 65)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Проданных рангов: "..(statsnick.totalranksell2info or "Нет информации")) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 85)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Принято сотрудников: "..(statsnick.totalinv2info or "Нет информации")) -- Текст слева от радиокнопки
		
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 105)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Уволено сотрудников: "..(statsnick.totaluninv2info or "Нет информации")) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 125)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Вылечено больных: "..(statsnick.totallek2info or "Нет информации")) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 145)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Выдано мед.карт: "..(statsnick.totalmd2info or "Нет информации")) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 45)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text((u8"Всего на посту: "..(statsnick.timemeininfo or "Нет информации"))) -- Текст слева от радиокнопки
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 170)) -- Отступ от правого края и ниже первой кнопки
		-- Цвет для второй части текста
		local valueColor = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)  -- Белый цвет для значения

		-- Выводим текст с цветом
		imgui.Text((u8"Общая сумма sell: "..(statsnick.totalmoneyEarned2info or "Нет информации").."$"))  -- Первый цветной текст

		imgui.PopFont()
		imgui.PushFont(font[21])
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 175)) -- Отступ от правого края и ниже первой кнопки

		imgui.PopFont()
		imgui.End() -- закрытие окна обязательно

	end
)
local newFrame3 = imgui.OnFrame( --[[Сама функция создания фрейма, их может быть сколько вашей душе угодно.
                                    Обратите внимание, что в mimgui рекомендуется создавать отдельный
                                    фрейм для каждого окна, однако это не является обязательным.]]
    function() return windowVisibleonline[0] end, -- Определяет, выполняется/отображается ли текущий фрейм.
    function(player3)            --[[Сама область, в которой уже будем рисовать элементы.
                                    В функцию в качестве первой переменной передаются список функций
                                    для взаимодействия с локальным игроком и рядом нескольких возможностей.]]
		applyCustomTheme()
		imgui.ShowCursor = true
		local startDate, endDate
		local screenX, screenY = getScreenResolution()
		local windowWidth, windowHeight = 750, 300 -- увеличена высота для отображения всех элементов
		local posX = (screenX - windowWidth) / 2
		local posY = (screenY - windowHeight) / 2
	
		imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Once)
		imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Once)
	
		local windowFlags = imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoTitleBar

		imgui.Begin(u8"", windowVisibleonline, windowFlags)
		local windowPos = imgui.GetWindowPos()
		local windowSize = imgui.GetWindowSize()
		
		-- Размеры для кнопок
		local buttonWidth = 50
		local buttonHeight = 50
		local selectedOption = 1 -- Предположим, 1 - это первый вариант
		-- Устанавливаем позицию курсора для первой кнопки (правый верхний угол)
		

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight - 35)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushFont(font[25])
		imgui.Text(u8"АКТИВНОСТЬ ЗА НЕДЕЛЮ") -- Текст слева от радиокнопки
        imgui.PopFont()
		



        imgui.PushFont(font[20])




		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 115, 10)) -- Отступ от правого края
		imgui.Text(u8"Текущая неделя") -- Текст слева от радиокнопки
		imgui.SameLine() -- Размещаем радиокнопку на той же строке
		if imgui.RadioButtonBool(u8"  ", selectedWeek == 0) then
			selectedWeek = 0
		end

		
		-- Устанавливаем позицию курсора для второй кнопки (правый верхний угол, ниже первой кнопки)
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 145, buttonHeight - 6)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Предыдущая неделя") -- Текст слева от радиокнопки
		imgui.SameLine() -- Размещаем радиокнопку на той же строке
		if imgui.RadioButtonBool(" ", selectedWeek == 1) then
			selectedWeek = 1
		end
		
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, 40 + 220)) -- Отступ от правого края и ниже первой кнопки
        if imgui.Button(u8"Закрыть", imgui.ImVec2(260, 30)) then
            windowVisibleonline[0] = false
			imgui.ShowCursor = false
        end


		local sideWidth = 445 
		local availableHeight = 25
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 83)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline2", imgui.ImVec2(sideWidth, availableHeight), false)
		imgui.EndChild()
		imgui.PopStyleColor()

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 133)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline3", imgui.ImVec2(sideWidth, availableHeight), false)
		imgui.EndChild()
		imgui.PopStyleColor()


		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 183)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(color0, color1, color2, color3))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline4", imgui.ImVec2(sideWidth, availableHeight), false)
		-- Ваш код внутри окна
		imgui.EndChild()
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному
		


		local sideWidth = 445 
		local availableHeight = 185
		
		-- Устанавливаем позицию следующего дочернего окна
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 407, buttonHeight + 55)) -- Отступ от правого края и ниже первой кнопки
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.00, 0.00, 0.00, 0.60))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttonsonline", imgui.ImVec2(sideWidth, availableHeight), true)
		
		local totalOnlineTime = 0 -- Переменная для общего времени
            
		-- Функция для преобразования даты
		local function parseDate(dateStr)
			local year, month, day = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
			return {day = tonumber(day), month = tonumber(month), year = tonumber(year)}
		end
		
		-- Функция для генерации всех дат с понедельника по воскресенье для указанной недели
		local function generateWeekDates(weekOffset)
			local dates = {}
			local currentDate = os.time() -- Текущая дата
		
			-- Вычисляем понедельник, отталкиваясь от текущей даты и смещения по неделям
			local currentWeekday = os.date("*t", currentDate).wday
			local lastMonday = currentDate - ((currentWeekday - 2) % 7) * 86400
			local targetMonday = lastMonday - (weekOffset * 7 * 86400) -- Учитываем смещение
		
			-- Генерируем даты с понедельника по воскресенье
			for i = 0, 6 do
				local date = os.date("%Y-%m-%d", targetMonday + i * 86400)
				table.insert(dates, date)
			end
		
			return dates
		end

		-- Генерируем даты для выбранной недели

		local dateRange = generateWeekDates(selectedWeek)
		local text = 7
		local totalmoneyEarned = 0
		local totalranksell = 0
		local totalinv = 0
		local totaluninv = 0
		local totallek = 0
		local totalmd = 0
		local totalOnlineTime = 0

		-- totalmoneyEarned2 = totalmoneyEarned
		-- totalranksell2 = totalranksell
		-- totalinv2 = totalinv
		-- totaluninv2 = totaluninv
		-- totallek2 = totallek
		-- totalmd2 = totalmd



		local function formatTime(milliseconds)
			if not milliseconds then
				return "00:00:00"  -- Если milliseconds равен nil, возвращаем "00:00:00"
			end

			local hours = math.floor(milliseconds / 3600000)
			local minutes = math.floor((milliseconds % 3600000) / 60000)
			local seconds = math.floor((milliseconds % 60000) / 1000)
			return string.format("%02d:%02d:%02d", hours, minutes, seconds)
		end


		-- Инициализация переменных для каждого дня недели
		-- -- Инициализация переменных для каждого дня недели на английском
		-- local daysOfWeek = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
		-- local timeSpentByDay = {Monday = 0, Tuesday = 0, Wednesday = 0, Thursday = 0, Friday = 0, Saturday = 0, Sunday = 0}
		-- local daysOfWeek2 = {"Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"}
		-- local manoySpentByDay = {Monday = 0, Tuesday = 0, Wednesday = 0, Thursday = 0, Friday = 0, Saturday = 0, Sunday = 0}
		-- Сортировка dateRange по порядку
		table.sort(dateRange)

		for i, day in ipairs(dateRange) do
			local timeSpent = totalTimeInZone[day] or 0
			local moneyEarned = (procSymmaByDate[day] and procSymmaByDate[day]) or 0
			local rankdateEarned = (rankdate[day] and rankdate[day]) or 0
			local lekdateEarned = (lekdate[day] and lekdate[day]) or 0
			local mddateEarned = (mddate[day] and mddate[day]) or 0
			local invdateEarned = (invdate[day] and invdate[day]) or 0
			local uninvdateEarned = (uninvdate[day] and uninvdate[day]) or 0

			totaluninv = totaluninv + uninvdateEarned
			totalinv = totalinv + invdateEarned
			totallek = totallek + lekdateEarned
			totalmd = totalmd + mddateEarned
			totalOnlineTime = totalOnlineTime + timeSpent
			totalmoneyEarned = totalmoneyEarned + moneyEarned
			totalranksell = totalranksell + rankdateEarned
			-- Добавим логирование, чтобы увидеть, что мы получаем из dateRange
			if #dateRange > 0 then
				-- Сортируем даты, если они не отсортированы
				table.sort(dateRange)
				
				-- Получаем первую и последнюю дату
				startDate = dateRange[1]  -- Первая дата
				endDate = dateRange[#dateRange]  -- Последняя дата
			end
			
			-- Отображаем данные
			local formattedTime = formatTime(timeSpent)
			imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 555, text))
			imgui.Text((u8"Online: %s"):format(formattedTime))

			local formattedMoney = formatMoney(moneyEarned)
			imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 405, text))
			imgui.Text((u8"Sell: %s$"):format(formattedMoney))
			text = text + 25
			-- Присваиваем значение времени для каждого дня недели по порядку
			-- if i <= #daysOfWeek then
			-- 	local currentDay = daysOfWeek[i]  -- Получаем день недели по порядку
			-- 	timeSpentByDay[currentDay] = timeSpent
			-- end
			-- if i <= #daysOfWeek2 then
			-- 	local currentDay = daysOfWeek2[i]  -- Получаем день недели по порядку
			-- 	manoySpentByDay[currentDay] = moneyEarned
			-- end
		end
		-- dateweek = startDate.." - "..endDate
		-- Monday1 = formatTime(timeSpentByDay.Monday)
		-- Tuesday1 = formatTime(timeSpentByDay.Tuesday)
		-- Wednesday1 = formatTime(timeSpentByDay.Wednesday)
		-- Thursday1 = formatTime(timeSpentByDay.Thursday)
		-- Friday1 = formatTime(timeSpentByDay.Friday)
		-- Saturday1 = formatTime(timeSpentByDay.Saturday)
		-- Sunday1 = formatTime(timeSpentByDay.Sunday)


		-- Monday1manoy = formatMoney(manoySpentByDay.Monday)
		-- Tuesday1manoy = formatMoney(manoySpentByDay.Tuesday)
		-- Wednesday1manoy = formatMoney(manoySpentByDay.Wednesday)
		-- Thursday1manoy = formatMoney(manoySpentByDay.Thursday)
		-- Friday1manoy = formatMoney(manoySpentByDay.Friday)
		-- Saturday1manoy = formatMoney(manoySpentByDay.Saturday)
		-- Sunday1manoy = formatMoney(manoySpentByDay.Sunday)



		-- imgui.Separator()
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 7)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Понедельник") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 32)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Вторник") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 57)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Среда") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 82)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Четверг") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 107)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Пятница") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 132)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Суббота") -- Если времени нет, отображаем 00:00:00
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 680, 157)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Воскресенье") -- Если времени нет, отображаем 00:00:00
		imgui.EndChild()
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight - 10)) -- Отступ от правого края и ниже первой кнопки
		local titleColor = imgui.ImVec4(0.50, 0.00, 0.15, 1.00)  -- Цвет для "Общая сумма sell:"

		imgui.Text((u8""..startDate.." - "..endDate)) -- Текст слева от радиокнопки

		local totalHours = math.floor(totalOnlineTime / 3600000)
		local totalMinutes = math.floor((totalOnlineTime % 3600000) / 60000)
		local totalSeconds = math.floor((totalOnlineTime % 60000) / 1000)
		
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 45)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Проданных рангов: "..totalranksell) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 65)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Принято сотрудников: "..totalinv) -- Текст слева от радиокнопки
		
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 85)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Уволено сотрудников: "..totaluninv) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 105)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Вылечено больных: "..totallek) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 125)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text(u8"Выдано мед.карт: "..totalmd) -- Текст слева от радиокнопки

		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 25)) -- Отступ от правого края и ниже первой кнопки
		imgui.Text((u8"Всего на посту: %02d:%02d:%02d"):format(totalHours, totalMinutes, totalSeconds)) -- Текст слева от радиокнопки
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 145)) -- Отступ от правого края и ниже первой кнопки
		totalmoneyEarned2 = formatMoney(totalmoneyEarned)
		timemein = ("%02d:%02d:%02d"):format(totalHours, totalMinutes, totalSeconds)

		-- Цвет для второй части текста
		local valueColor = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)  -- Белый цвет для значения

		-- Выводим текст с цветом
		imgui.Text((u8"Общая сумма sell: "..totalmoneyEarned2.."$"))  -- Первый цветной текст

		imgui.PopFont()
		imgui.PushFont(font[21])
		imgui.SetCursorPos(imgui.ImVec2(windowSize.x - buttonWidth - 685, buttonHeight + 175)) -- Отступ от правого края и ниже первой кнопки
		local result = days_since_for_nick(checknick)
		imgui.Text((u8"Количество дней на должности: "..result))  -- Первый цветной текст
		imgui.PopFont()
		imgui.End() -- закрытие окна обязательно
	end
)

local newFrame = imgui.OnFrame( --[[Сама функция создания фрейма, их может быть сколько вашей душе угодно.
                                    Обратите внимание, что в mimgui рекомендуется создавать отдельный
                                    фрейм для каждого окна, однако это не является обязательным.]]
    function() return windowVisible[0] end, -- Определяет, выполняется/отображается ли текущий фрейм.
    function(player)            --[[Сама область, в которой уже будем рисовать элементы.
                                    В функцию в качестве первой переменной передаются список функций
                                    для взаимодействия с локальным игроком и рядом нескольких возможностей.]]
		applyCustomTheme()
		imgui.ShowCursor = true
		imgui.PushFont(font[20])
		local screenX, screenY = getScreenResolution()

		local windowWidth, windowHeight = 700, 300

		local posX = (screenX - windowWidth) / 2
		local posY = (screenY - windowHeight) / 2

		imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Once)
		imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Once)

		imgui.Begin(u8"                                                                   San Fierro Medical Center", windowVisible)

		local buttonWidth, buttonHeight = 200, 30
		local sideWidth = 217 
		local buttonWidthsel, buttonHeightsell = 200, 50
		local contentRegionAvail = imgui.GetContentRegionAvail()
		local availableHeight = contentRegionAvail.y
		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.00, 0.00, 0.00, 0.10))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Buttons", imgui.ImVec2(sideWidth, availableHeight), true)

		if imgui.Button(u8"Продажа рагов", imgui.ImVec2(buttonWidth, buttonHeight)) then
			selectedButton = "sellrags"
			system = 0
			selectedRank = 0
		end


		if imgui.Button(u8"Активность", imgui.ImVec2(buttonWidth, buttonHeight)) then
			windowVisibleonline[0] = true
			windowVisible[0] = false
		end
        if imgui.Button(u8"Спавн транспорта", imgui.ImVec2(buttonWidth, buttonHeight)) then
            selectedRank = 10
            isWeeksWindowVisible = true
		end
		if imgui.Button(u8"Руководство", imgui.ImVec2(buttonWidth, buttonHeight)) then
			selectedButton = "sfmc"
		end
        if imgui.Button(u8"Настройки", imgui.ImVec2(buttonWidth, buttonHeight)) then
			selectedButton = "settings"
		end
		imgui.Dummy(imgui.ImVec2(0, availableHeight - 7.4 * buttonHeight)) -- Оставляем место для предыдущих кнопок

		if imgui.Button(u8"Скачать обновление", imgui.ImVec2(buttonWidth, buttonHeight)) then
			imgui.ShowCursor = false
			checkForUpdate() -- Проверяем наличие обновления
			windowVisible[0] = false
		end
		imgui.EndChild()

		imgui.SameLine()
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному


		imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0.00, 0.00, 0.00, 0.10))  -- Задаем цвет фона (серый)
		imgui.BeginChild("Info", imgui.ImVec2(0, availableHeight), true)

		local nicknames = {"Yumi_Shelby", "Miya_Shelby", "Mao_Shelby", "Emily_Miller", "Kris_Sherman", "Corovar_Miror", "Dmitry_Berlinetta", "Steven_Sadness", "Kevin_Berlinetta", "Steve_Lix"} -- Список ников
		local buttonsPerRow = 2 -- Количество кнопок в одной строке
		
		if selectedButton == "sfmc" then
			local buttonCounter = 0 -- Счётчик кнопок в текущей строке
			if nick == "Miya_Shelby" or nick == "Mao_Shelby" or nick == "Yumi_Shelby" or nick == "Emily_Miller" then

				for _, nick in ipairs(nicknames) do
					if imgui.Button(u8(nick), imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						loadSettingsonline()
						statsnick = loadstats[nick] 
						print(statsnick)
						nickname = nick -- Сохраняем выбранный ник
						 
						if statsnick then
							if checkstats ~= nil then
								windowVisibleonline2[0] = true
								windowVisible[0] = false
							else
								local randomNumber = math.random(1, 1000000)
								local data = {
									message = toUtf8("Отправка сообщения"),
									sender = getNickname(),
									nickcheck = nickname,
									statsinfo = {
										tipsend = 3,
										uid = randomNumber,
										nicksend = nickname,
									}
								}
								cmd_send_message(data)
								startinfo = true
								sampAddChatMessage(tag_q.."Нет данных о руководителе, попытка получить данные.", -1)
								print(statsnick)
							end
						else
							local randomNumber = math.random(1, 1000000)
							local data = {
								message = toUtf8("Отправка сообщения"),
								sender = getNickname(),
								nickcheck = nickname,
								statsinfo = {
									tipsend = 3,
									uid = randomNumber,
									nicksend = nickname,
								}
							}
							cmd_send_message(data)
							startinfo = true
							sampAddChatMessage(tag_q.."Нет данных о руководителе, попытка получить данные.", -1)
							print(statsnick)
						end
					end
					buttonCounter = buttonCounter + 1
					if buttonCounter % buttonsPerRow ~= 0 then
						imgui.SameLine() -- Размещаем кнопку на одной линии, если это не конец строки
					end
				end
			else
				imgui.Text(u8"Доступно только лидеру и владельцу!")
			end	
		elseif selectedButton == "lodiing" then
			local window_pos = imgui.GetWindowPos()
			local window_size = imgui.GetWindowSize()
		
			-- Рассчитываем центр внутри окна
			local center_x = window_pos.x + window_size.x / 2
			local center_y = window_pos.y + window_size.y / 2.4		
			local radius = 50
			local thickness = 6
		
			-- Обновление прогресса
			progress = progress + (speed * imgui.GetIO().DeltaTime)
			if progress > 1 then progress = 0 end -- цикл прогресса
		

			local ImGui = imgui
			local draw_list = ImGui.GetWindowDrawList()
			local start_angle = -math.pi / 2
			local max_angle = 2 * math.pi
			local progress_angle = start_angle + max_angle * progress
			local bg_color = ImGui.ColorConvertFloat4ToU32(ImGui.ImVec4(0.2, 0.2, 0.2, 1))
			local fg_color = ImGui.ColorConvertFloat4ToU32(ImGui.ImVec4(0.4, 0.7, 0.2, 1))
		
			-- Рисуем фон индикатора
			draw_list:PathArcTo(ImGui.ImVec2(center_x, center_y), radius, start_angle, start_angle + max_angle, 64)
			draw_list:PathStroke(bg_color, false, thickness)
		
			-- Рисуем прогресс индикатора
			draw_list:PathArcTo(ImGui.ImVec2(center_x, center_y), radius, start_angle, progress_angle, 64)
			draw_list:PathStroke(fg_color, false, thickness)
		elseif selectedButton == "online" then
			imgui.BeginGroup()

			-- Заголовок
			imgui.TextColored(imgui.ImVec4(0.3, 0.8, 1.0, 1.0), u8"Онлайн по дням в холле:")
			imgui.Separator()
			imgui.Spacing()
			
			local totalOnlineTime = 0 -- Переменная для общего времени
			
			-- Функция для преобразования даты
			local function parseDate(dateStr)
				local year, month, day = dateStr:match("(%d%d%d%d)-(%d%d)-(%d%d)")
				return {day = tonumber(day), month = tonumber(month), year = tonumber(year)}
			end
			
			-- Функция для генерации всех дат с понедельника по воскресенье для указанной недели
			local function generateWeekDates(weekOffset)
				local dates = {}
				local currentDate = os.time() -- Текущая дата
			
				-- Вычисляем понедельник, отталкиваясь от текущей даты и смещения по неделям
				local currentWeekday = os.date("*t", currentDate).wday
				local lastMonday = currentDate - ((currentWeekday - 2) % 7) * 86400
				local targetMonday = lastMonday - (weekOffset * 7 * 86400) -- Учитываем смещение
			
				-- Генерируем даты с понедельника по воскресенье
				for i = 0, 6 do
					local date = os.date("%Y-%m-%d", targetMonday + i * 86400)
					table.insert(dates, date)
				end
			
				return dates
			end
			
			-- Генерируем даты для выбранной недели
			-- Генерируем даты для выбранной недели
			local dateRange = generateWeekDates(selectedWeek)

			imgui.Columns(2, "OnlineDays", true) -- Создаем 2 колонки
			for _, day in ipairs(dateRange) do
				local timeSpent = totalTimeInZone[day] or 0
				local moneyEarned = (procSymmaByDate[day] and procSymmaByDate[day]) or 0 -- Получаем сумму для текущей даты

				totalOnlineTime = totalOnlineTime + timeSpent -- Суммируем общее время
				local hours = math.floor(timeSpent / 3600000)
				local minutes = math.floor((timeSpent % 3600000) / 60000)
				local seconds = math.floor((timeSpent % 60000) / 1000)

				imgui.TextColored(imgui.ImVec4(0.6, 0.9, 0.6, 1.0), ("%s:"):format(day))
				imgui.SameLine()
				if timeSpent > 0 then
					imgui.Text(("%02d:%02d:%02d"):format(hours, minutes, seconds))
				else
					imgui.Text("00:00:00") -- Если времени нет, отображаем 00:00:00
				end
				local formattedMoney = formatMoney(moneyEarned)
				imgui.SameLine() -- Переход на ту же строку для отображения суммы
				imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.1, 1.0), ("%s$"):format(formattedMoney)) -- Отображаем сумму или 0

				imgui.NextColumn() -- Переход к следующей колонке
			end
			imgui.Columns(1) -- Возвращаемся к одной колонке

			-- Вывод общего времени онлайн
			local totalHours = math.floor(totalOnlineTime / 3600000)
			local totalMinutes = math.floor((totalOnlineTime % 3600000) / 60000)
			local totalSeconds = math.floor((totalOnlineTime % 60000) / 1000)

			imgui.Separator()
			imgui.TextColored(imgui.ImVec4(1.0, 0.8, 0.1, 1.0), u8"Общее время онлайн:")
			imgui.Text(("%02d:%02d:%02d"):format(totalHours, totalMinutes, totalSeconds))

			
			-- Кнопки для переключения между неделями внизу
			imgui.Spacing()
			if imgui.Button(u8"Текущая неделя") then
				selectedWeek = 0
			end
			imgui.SameLine()
			if imgui.Button(u8"Предыдущая неделя") then
				selectedWeek = 1
			end
			
			imgui.EndGroup()
			

		
		
		
		
		
		
		elseif selectedButton == "sellrags" then

			if system == 1 then
				imgui.BeginGroup()
				imgui.Text(u8"На данный момент открыта новая система!")
				if selectedRank == 0 then
					if imgui.Button(u8"5-й ранг(-40%)", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						selectedRank = 4
						sellrang = true
						sampSendChat("/lmenu")
					end
					imgui.SameLine()
					if imgui.Button(u8"5-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						selectedRank = 5
						sellrang = true
						sampSendChat("/lmenu")
					end
					imgui.EndGroup()

					imgui.Spacing()

					-- Вторая строка кнопок
					imgui.BeginGroup()
					if imgui.Button(u8"6-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						selectedRank = 6
						sellrang = true
						sampSendChat("/lmenu")
					end

					imgui.SameLine()
					
					if imgui.Button(u8"7-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						selectedRank = 7
						sellrang = true
						sampSendChat("/lmenu")
					end

					
					if imgui.Button(u8"8-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						selectedRank = 8
						sellrang = true
						sampSendChat("/lmenu")
					end
					imgui.SameLine()
					if imgui.Button(u8"Вернутся назад", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						system = 0
						selectedRank = 0
					end
				else
					if selectedRank == 4 then
						if imgui.Button(u8("5-й ранг"), imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
							selectedRank = selectedRank
							sellrang = true
							sampSendChat("/lmenu")
						end
					else
						if imgui.Button(u8(selectedRank.." -й ранг"), imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
							selectedRank = selectedRank
							sellrang = true
							sampSendChat("/lmenu")
						end
					end
					imgui.SameLine()
					if imgui.Button(u8"Вернутся назад", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
						system = 0
						selectedRank = 0
					end
					for line in string.gmatch(namme, "[^\n]+") do
						line = removeColorCodes(line)
						local buttonWidthsel, buttonHeightsell = 400, 50
						if line:find("(%a+_%a+)") then
							local test = line:match("(%a+_%a+)")
							if imgui.Button(u8(line), imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
								igrok = test
								isWeeksWindowVisiblenew = true
							end
						end
					end
				end
				imgui.EndGroup()
			elseif system == 2 then
				imgui.BeginGroup()
				imgui.Text(u8"На данный момент открыта старая система!")
				if imgui.Button(u8"5-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					selectedRank = 5 -- Устанавливаем ранг 5
					isPlayerIDWindowVisible = true 
				end
				imgui.SameLine()
				
				if imgui.Button(u8"6-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					selectedRank = 6 -- Устанавливаем ранг 6
					isPlayerIDWindowVisible = true -- Открываем окно для ввода ID
				end
				
				imgui.EndGroup()

				imgui.Spacing()

				-- Вторая строка кнопок
				imgui.BeginGroup()
				
				if imgui.Button(u8"7-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					selectedRank = 7 -- Устанавливаем ранг 7
					isWeeksWindowVisible = true -- Открываем окно для ввода количества недель и ID
				end
				imgui.SameLine()
				
				if imgui.Button(u8"8-й ранг", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					selectedRank = 8 -- Устанавливаем ранг 8
					isWeeksWindowVisible = true -- Открываем окно для ввода количества недель и ID
				end
				if imgui.Button(u8"Вернутся назад", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					system = 0
				end
				imgui.EndGroup()
			else
				imgui.BeginGroup()
				
				if imgui.Button(u8"Новая система", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					system = 1 -- Устанавливаем ранг 5
				end
				imgui.SameLine()
				
				if imgui.Button(u8"Старая система", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
					system = 2 -- Устанавливаем ранг 6
				end
				imgui.EndGroup()
			end
		elseif selectedButton == "settings" then
			-- Ползунок для управления рекламой
			if imgui.Checkbox(u8"Включить CMD help на экране", start_timereklama) then
				saveSettings()  -- Сохраняем изменения
			end
		
			-- Ползунок для управления видимостью окна лечения
			if imgui.Checkbox(u8"Включить окно лечения", windowVisiblelekokno) then
				saveSettings()  -- Сохраняем изменения
			end
			if imgui.Checkbox(u8"Включить отображения КД /vr", windowVisibkrvr) then
				saveSettings()  -- Сохраняем изменения
			end
			imgui.Text(u8"Редактирование слов:")
			
			-- Отображение слов и кнопок, как было ранее
			for i, word in ipairs(words) do
				imgui.Text(word)
				imgui.SameLine()
				if imgui.Button(u8"Удалить##" .. i) then
					loadHealKeywords()
					table.remove(words, i)
					saveWords(wordFilePath)
				end
				if i % 4 ~= 0 then
					imgui.SameLine()
				end
			end
			
			imgui.Spacing()
		
            imgui.InputText(u8" ", wordInputBuffer, 256)
            
            local buttonWidth, buttonHeight = 278, 30
            if imgui.Button(u8"Добавить слово", imgui.ImVec2(buttonWidth, buttonHeight)) then
                local newWord = trim(ffi.string(wordInputBuffer)) -- Преобразуем cdata в строку
                if newWord ~= "" then
					loadHealKeywords()
                    table.insert(words, newWord)
                    -- Сохранение в отдельном потоке
                    lua_thread.create(function()
                        saveWords(wordFilePath)
                    end)
                    -- Очищаем буфер
                    ffi.fill(wordInputBuffer, 256) -- Заполняем буфер нулями
                end
            end

            if not color then
                color = ffi.new("float[4]", 0.30, 0.00, 0.10, 1.00)  -- Белый по умолчанию
            end
            
            -- Отображение ColorEdit4 с передачей ffi.new массива для правильной работы
            if imgui.ColorEdit4('##color', color) then
                -- Преобразуем измененные значения в u32 для сохранения
                local u32 = imgui.ColorConvertFloat4ToU32(imgui.ImVec4(color[0], color[1], color[2], color[3]))
                color2 = color[2]
                color0 = color[0]
                color1 = color[1]
                color3 = color[3]
                saveSettings()
            end
            
		else
			system = 0 -- Устанавливаем ранг 5
		end
		imgui.PopStyleColor()  -- Сбрасываем цвет к исходному
		imgui.EndChild()

		imgui.End()

		if not windowVisible[0] then
			hideCursor()
		end
		if isWeeksWindowVisible then
			local screenWidth, screenHeight = getScreenResolution()
            local windowWidth, windowHeight = 300, 170
			local windowPosX = (screenWidth - windowWidth) / 2
			local windowPosY = (screenHeight - windowHeight) / 2
		
			imgui.SetNextWindowPos(imgui.ImVec2(windowPosX, windowPosY), imgui.Cond.Always)
			imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Always)
			if selectedRank == 6 then
				imgui.Begin(u8"Введите ID игрока и количество месяцев", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
            elseif selectedRank == 10 then
                imgui.Begin(u8"Вы уверены, что хотите сделать спавн ТС?", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
			else
				imgui.Begin(u8"Введите ID игрока и количество недель", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
			end
			local contentRegion = imgui.GetContentRegionAvail()
		
			if selectedRank == 10 then
                print("Пусто")
            else
                imgui.PushItemWidth(contentRegion.x)
                imgui.InputText(u8"ID игрока", enteredPlayerID, 0)
                imgui.PopItemWidth()
            end
			if selectedRank == 6 then
				imgui.Text(u8"Введите количество месяцев:")
            elseif selectedRank == 10 then
                imgui.Text(u8"Введите время спавна ТС:")
			else
				imgui.Text(u8"Введите количество недель:")
			end
			-- Поле ввода для количества недель
			imgui.PushItemWidth(contentRegion.x)
			imgui.InputInt(u8"", enteredWeeks, 0)
			imgui.PopItemWidth()
		
			imgui.Spacing()
			if selectedRank == 6 then
				if imgui.Button(u8"Подтвердить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
					if enteredWeeks[0] > 0 then
						-- Рассчитываем дату окончания по МСК, добавляя месяцы
						local currentTime = os.time()
						local currentDateTable = os.date("*t", currentTime)
						
						-- Добавляем месяцы к текущей дате
						currentDateTable.month = currentDateTable.month + enteredWeeks[0]
						
						-- Если месяц превысит 12, корректируем год и месяц
						while currentDateTable.month > 12 do
							currentDateTable.month = currentDateTable.month - 12
							currentDateTable.year = currentDateTable.year + 1
						end
						
						-- Получаем таблицу с датой окончания
						local targetTime = os.time(currentDateTable)
						local endDateTable = os.date("*t", targetTime)
						
						-- Корректная дата с учётом длины месяцев
						local endDay = endDateTable.day
						local endMonth = endDateTable.month
						
						-- Форматируем и отправляем команды
						lua_thread.create(function()
							sampSendChat("/giverank " .. enteredPlayerID[0] .. " " .. selectedRank)
							wait(1000)
							delltag = true
							sampSendChat("/settag " .. enteredPlayerID[0] .. " " .. string.format("%02d.%02d", endDay, endMonth))
							infotag = "/settag " .. enteredPlayerID[0] .. " " .. string.format("%02d.%02d", endDay, endMonth)
							wait(500)
							delltag = false
						end)
					else
						print("Количество месяцев должно быть больше 0.")
					end
				
					isWeeksWindowVisible = false -- Закрываем окно
				end
            elseif selectedRank == 10 then
                if imgui.Button(u8"Подтвердить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
					if enteredWeeks[0] > 0 then
                        cmd_spcarall(enteredWeeks[0])
					else
                        cmd_spcarall(15)
					end
				
					isWeeksWindowVisible = false -- Закрываем окно
				end
			else
				if imgui.Button(u8"Подтвердить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
					if enteredWeeks[0] > 0 then
						-- Рассчитываем дату окончания по МСК, учитывая длину месяцев
						local currentTime = os.time()
						local targetTime = currentTime + (enteredWeeks[0] * 7 * 24 * 60 * 60) -- Добавляем недели
			
						-- Получаем таблицу с датой окончания
						local endDateTable = os.date("*t", targetTime)
			
						-- Корректная дата с учётом длины месяцев
						local endDay = endDateTable.day
						local endMonth = endDateTable.month
			
						-- Форматируем и отправляем команды
						lua_thread.create(function()
							sampSendChat("/giverank " .. enteredPlayerID[0] .. " " .. selectedRank)
							wait(1000)
							delltag = true
							sampSendChat("/settag " .. enteredPlayerID[0] .. " " .. string.format("%02d.%02d", endDay, endMonth))
							infotag = "/settag " .. enteredPlayerID[0] .. " " .. string.format("%02d.%02d", endDay, endMonth)
							wait(500)
							delltag = false
						end)
					else
						print("Количество недель должно быть больше 0.")
					end
			
					isWeeksWindowVisible = false -- Закрываем окно
				end
			end
			imgui.SameLine()
		
			if imgui.Button(u8"Отменить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
				isWeeksWindowVisible = false -- Закрываем окно без действия
			end
            if selectedRank == 10 then
                print("Пропуск")
            else
                imgui.Spacing()
            
                -- Новая кнопка для копирования ника игрока
                if imgui.Button(u8"Скопировать ник", imgui.ImVec2(contentRegion.x, 40)) then
                    local playerName = sampGetPlayerNickname(enteredPlayerID[0]) -- Функция для получения ника игрока по ID
                    if playerName then
                        setClipboardText(playerName) -- Функция для копирования текста в буфер обмена
                        sampAddChatMessage(tag_q.."Ник игрока "..playerName.." скопирован в буфер обмена.", -1) -- Вывод сообщения для пользователя
                    else
                        sampAddChatMessage(tag_q.."Не удалось найти игрока с таким ID.", -1) -- Сообщение об ошибке
                    end
                end
            end
			imgui.End()
		end
		if isPlayerIDWindowVisible then
			local screenWidth, screenHeight = getScreenResolution()
			local windowWidth, windowHeight = 300, 160 -- Увеличиваем высоту окна для дополнительной кнопки
			local windowPosX = (screenWidth - windowWidth) / 2
			local windowPosY = (screenHeight - windowHeight) / 2
		
			imgui.SetNextWindowPos(imgui.ImVec2(windowPosX, windowPosY), imgui.Cond.Always)
			imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Always)
		
			imgui.Begin(u8"Введите ID игрока", nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
		
			local contentRegion = imgui.GetContentRegionAvail()
			imgui.PushItemWidth(contentRegion.x)
		
			-- Поле ввода для ID игрока
			imgui.InputText(u8"", enteredPlayerID, 0)
			imgui.PopItemWidth()
		
			imgui.Spacing()
		
			if imgui.Button(u8"Подтвердить", imgui.ImVec2(contentRegion.x / 2, contentRegion.y / 3.2)) then
				-- Для 5 и 6 рангов логика остаётся прежней
				if selectedRank == 5 then
					lua_thread.create(function()
						sampSendChat("/giverank " .. enteredPlayerID[0] .. " 5")
						wait(1000)
						delltag = true
						sampSendChat("/settag ".. enteredPlayerID[0] .. " Forever")
						infotag = "/settag ".. enteredPlayerID[0] .. " Forever"
						wait(500)
						delltag = false
					end)
				end
				isPlayerIDWindowVisible = false -- Закрываем окно
			end
		
			imgui.SameLine()
		
			if imgui.Button(u8"Отменить", imgui.ImVec2(contentRegion.x / 2, contentRegion.y / 3.2)) then
				isPlayerIDWindowVisible = false -- Закрываем окно без действия
			end
		
			imgui.Spacing()
		
			-- Новая кнопка для копирования ника игрока
			if imgui.Button(u8"Скопировать ник", imgui.ImVec2(contentRegion.x, 40)) then
				local playerName = sampGetPlayerNickname(enteredPlayerID[0]) -- Функция для получения ника игрока по ID
				if playerName then
					setClipboardText(playerName) -- Функция для копирования текста в буфер обмена
					sampAddChatMessage(tag_q.."Ник игрока "..playerName.." скопирован в буфер обмена.", -1) -- Вывод сообщения для пользователя
				else
					sampAddChatMessage(tag_q.."Не удалось найти игрока с таким ID.", -1) -- Сообщение об ошибке
				end
			end
		
			imgui.End()
		end
		
		if isWeeksWindowVisiblenew then
			local screenWidth, screenHeight = getScreenResolution()
			local windowWidth, windowHeight = 380, 180
			local windowPosX = (screenWidth - windowWidth) / 2
			local windowPosY = (screenHeight - windowHeight) / 2
		
			imgui.SetNextWindowPos(imgui.ImVec2(windowPosX, windowPosY), imgui.Cond.Always)
			imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Always)
			if selectedRank == 5 or selectedRank == 4  then
				imgui.Begin(u8(igrok.." Покупает ранг"), nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
			else
				imgui.Begin(u8(igrok.." Покупает ранг введите количество недель"), nil, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoCollapse)
			end
			local contentRegion = imgui.GetContentRegionAvail()
		
			if selectedRank == 5 or selectedRank == 4 then
	
			elseif selectedRank == 8 then
				imgui.Text(u8"Введите количество месяцев:")
				-- Поле ввода для количества недель
				imgui.PushItemWidth(contentRegion.x)
				imgui.InputInt(u8"", enteredWeeks, 0)
				imgui.PopItemWidth()
			
				imgui.Spacing()
			else
				imgui.Text(u8"Введите количество недель:")
				-- Поле ввода для количества недель
				imgui.PushItemWidth(contentRegion.x)
				imgui.InputInt(u8"", enteredWeeks, 0)
				imgui.PopItemWidth()
			
				imgui.Spacing()
			end
			if imgui.Button(u8"Подтвердить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
				if selectedRank == 5 or selectedRank == 4 then
					srok = 60
					ranksell = true
					sampSendChat("/lmenu")
				elseif selectedRank == 8 then
					if enteredWeeks[0] > 0 then
						srok = enteredWeeks[0] * 30
						ranksell = true
						sampSendChat("/lmenu")
					else
						print("Количество месяцев должно быть больше 0.")
				end
				else
					if enteredWeeks[0] > 0 then
						srok = enteredWeeks[0] * 7
						ranksell = true
						sampSendChat("/lmenu")
					else
						print("Количество недель должно быть больше 0.")
					end
				end
		
				isWeeksWindowVisiblenew = false -- Закрываем окно
			end
			imgui.SameLine()
		
			if imgui.Button(u8"Отменить", imgui.ImVec2(contentRegion.x / 2.05, contentRegion.y / 4)) then
				isWeeksWindowVisiblenew = false -- Закрываем окно без действия
			end
			imgui.Spacing()
		
			-- Новая кнопка для копирования ника игрока
			if imgui.Button(u8"Скопировать ник", imgui.ImVec2(contentRegion.x, 40)) then
				local playerName = sampGetPlayerNickname(enteredPlayerID[0]) -- Функция для получения ника игрока по ID
				if playerName then
					setClipboardText(playerName) -- Функция для копирования текста в буфер обмена
					sampAddChatMessage(tag_q.."Ник игрока "..playerName.." скопирован в буфер обмена.", -1) -- Вывод сообщения для пользователя
				else
					sampAddChatMessage(tag_q.."Не удалось найти игрока с таким ID.", -1) -- Сообщение об ошибке
				end
			end
			imgui.PopFont()
			imgui.End()
		end
	end
)


local newFrame2 = imgui.OnFrame( 
    function() 
        local playersCount = 0
        for _ in pairs(playersToHeal) do
            playersCount = playersCount + 1
        end
        return windowVisiblelek[0] and playersCount > 0 and windowVisiblelekokno[0] 
    end, -- Определяет, выполняется/отображается ли текущий фрейм.
    
    function(player) 
        applyCustomTheme()
		imgui.ShowCursor = false
        local windowWidth, windowHeight = 250, 400
        imgui.SetNextWindowSize(imgui.ImVec2(windowWidth, windowHeight), imgui.Cond.Once)
    
        local screenWidth, screenHeight = getScreenResolution()
        local windowPosX = screenWidth - windowWidth - 10
        local windowPosY = screenHeight - windowHeight - 10
        imgui.SetNextWindowPos(imgui.ImVec2(windowPosX, windowPosY), imgui.Cond.Once)
    
        imgui.Begin(u8"SFMC_Window", nil, 1 + 2)
        local buttonWidthsel, buttonHeightsell = 235, 40
    
        local playersList = {}
        for playerID, playerName in pairs(playersToHeal) do
            table.insert(playersList, {id = playerID, name = playerName})
        end
    
        for i, player in ipairs(playersList) do
            if imgui.Button(player.name .. " (ID: " .. player.id .. ")", imgui.ImVec2(buttonWidthsel, buttonHeightsell)) then
                sampSendChat("/heal " .. player.id .. " 10000")
                playersToHeal[player.id] = nil
            end
        end
    
        local playerCount = #playersList
        if playerCount > 0 then
            if okno and not sampIsChatInputActive() then
                if currentPlayerIndex > playerCount then
                    currentPlayerIndex = 1
                end
                local currentPlayer = playersList[currentPlayerIndex]
                if currentPlayer then
                    sampSendChat("/heal " .. currentPlayer.id .. " 10000")
                    playersToHeal[currentPlayer.id] = nil
                    currentPlayerIndex = currentPlayerIndex + 1
                    if currentPlayerIndex > playerCount then
                        currentPlayerIndex = 1
                    end
                end
                okno = false
            end
        end
    
        imgui.End()
    
        if not windowVisiblelek[0] then
            imgui.ShowCursor = false
        end
	end
)





function hideCursor()
    imgui.ShowCursor = false
end


local function toLowerCyrillic(text)
    local conversion = {
        ["А"] = "а", ["Б"] = "б", ["В"] = "в", ["Г"] = "г",
        ["Д"] = "д", ["Е"] = "е", ["Ё"] = "ё", ["Ж"] = "ж",
        ["З"] = "з", ["И"] = "и", ["Й"] = "й", ["К"] = "к",
        ["Л"] = "л", ["М"] = "м", ["Н"] = "н", ["О"] = "о",
        ["П"] = "п", ["Р"] = "р", ["С"] = "с", ["Т"] = "т",
        ["У"] = "у", ["Ф"] = "ф", ["Х"] = "х", ["Ц"] = "ц",
        ["Ч"] = "ч", ["Ш"] = "ш", ["Щ"] = "щ", ["Ъ"] = "ъ",
        ["Ы"] = "ы", ["Ь"] = "ь", ["Э"] = "э", ["Ю"] = "ю",
        ["Я"] = "я",
        ["а"] = "а", ["б"] = "б", ["в"] = "в", ["г"] = "г",
        ["д"] = "д", ["е"] = "е", ["ё"] = "ё", ["ж"] = "ж",
        ["з"] = "з", ["и"] = "и", ["й"] = "й", ["к"] = "к",
        ["л"] = "л", ["м"] = "м", ["н"] = "н", ["о"] = "о",
        ["п"] = "п", ["р"] = "р", ["с"] = "с", ["т"] = "т",
        ["у"] = "у", ["ф"] = "ф", ["х"] = "х", ["ц"] = "ц",
        ["ч"] = "ч", ["ш"] = "ш", ["щ"] = "щ", ["ъ"] = "ъ",
        ["ы"] = "ы", ["ь"] = "ь", ["э"] = "э", ["ю"] = "ю",
        ["я"] = "я"
    }

    local lowerText = ""
    for i = 1, #text do
        local char = text:sub(i, i)
        lowerText = lowerText .. (conversion[char] or char)
    end
    return lowerText
end


local function containsKeyword(text)
    text = toLowerCyrillic(text)  -- Преобразуем текст в нижний регистр для сравнения

    for _, keyword in ipairs(healKeywords) do
        keyword = toLowerCyrillic(keyword)  -- Преобразуем ключевое слово в нижний регистр
        if text:find(u8"%s" .. keyword .. "%s") or text:find("^" .. keyword .. "%s") or text:find("%s" .. keyword .. "$") or text:find("^" .. keyword .. "$") then
            return true
        end
    end
    return false
end




local function colorToU32(color)
    return imgui.ColorConvertFloat4ToU32(color)
end

-- Функция для отрисовки круглого таймера
local function drawCircularTimer(x, y, radius, remainingTime, totalTime)
    local draw_list = imgui.GetBackgroundDrawList()

    local start_angle = 3 * math.pi / 2
    local end_angle = start_angle + (2 * math.pi) * (remainingTime / totalTime)

    -- Цвета
    local timerColor = imgui.ImVec4(51 / 255, 178 / 255, 77 / 255, 1.0) -- Зеленый
    local backgroundColor = imgui.ImVec4(51 / 255, 51 / 255, 51 / 255, 0.95) -- Темно-серый

    -- Фон таймера
    draw_list:AddCircleFilled(vec2(x, y), radius, colorToU32(backgroundColor), 32)

    -- Оставшееся время таймера
    if remainingTime > 0 then
        local segments = 32
        for i = 0, segments do
            local a = start_angle + (end_angle - start_angle) * (i / segments)
            local ax = x + math.cos(a) * (radius - 1)
            local ay = y + math.sin(a) * (radius - 1)
            if i > 0 then
                draw_list:AddLine(vec2(x + math.cos(a - (end_angle - start_angle) / segments) * (radius - 1),
                                       y + math.sin(a - (end_angle - start_angle) / segments) * (radius - 1)),
                                  vec2(ax, ay), colorToU32(timerColor), 1)
            end
        end
    end

    -- Текст с оставшимся временем
    local timeText = string.format("%.0f", remainingTime)
    local textSize = imgui.CalcTextSize(timeText)
    draw_list:AddText(vec2(x - textSize.x / 2, y - textSize.y / 2), colorToU32(timerColor), timeText)
end

-- Обработчик отрисовки
imgui.OnFrame(
    function() return windowVisiblkd[0] end,
    function(self)
        self.HideCursor = true
        if not isTimerActive then return end

        local currentTime = os.time()
        local elapsedTime = os.difftime(currentTime, startTime)
        local remainingTime = math.max(0, totalTime - elapsedTime)

        -- Рисуем круглый таймер
        drawCircularTimer(resX / 12, resY / 1.6, 40, remainingTime, totalTime)

        if remainingTime <= 0 then
            isTimerActive = false
            sampAddChatMessage(u8:decode("{FF0000}[Timer]: {FFFFFF}Таймер завершён!"), 0xFFFFFF)
            windowVisiblkd[0] = false -- Отключаем отображение окна
        end
    end
)

function samp.onServerMessage(color, text)
    local cleanText = removeColorCodes(text)

    local playerName, playerID, message = cleanText:match("(%S+)%[(%d+)%] говорит: (.+)")

    if playerName and playerID and containsKeyword(message) then
        local playerIdNum = tonumber(playerID)

        if not playersToHeal[playerIdNum] then
            addPlayerToHeal(playerIdNum, playerName) 
        else
            playersToHeal[playerIdNum] = playerName
        end
    end
    id = select(2, sampGetPlayerIdByCharHandle(playerPed))
    nick = sampGetPlayerNickname(id)
    if text:find("Вам был добавлен предмет 'Фишки для казино'%. Откройте инвентарь, используйте клавишу 'Y' или /invent") then
        local currentTime = os.date("%H:%M:%S") 
        SendWebhook('https://discord.com/api/webhooks/1289317204134858772/uA_rG8HGqgWcTvq94Te_4OMvcwu8zojeERZVs6ofgJ3e5A9h1wn2STyMglTw7BsekgVW',([[{
            "content": "[%s] **%s** Купил фишки для казино",
            "embeds": [],
            "attachments": []
        }]]):format(currentTime, nick))
    end
    if text:find("%[VIP ADV%] {FFFFFF}"..nick.."%[(%d+)%]:(.+)") then
		isTimerActive = true
        startTime = os.time() -- Обновляем время старта
        windowVisiblkd[0] = true
    end
	if text:find("%[Информация%] {ffffff}Игрок (.+)%((%d+)%) принял покупку ранга за (.+)") then
		local name, id2, rank = text:match("%[Информация%] {ffffff}Игрок (.+)%((%d+)%) принял покупку ранга за (.+)")
		if not name or not rank then
			print("Ошибка: не удалось извлечь данные из текста.")
			return
		end
		-- local niiik, id2 = string.match(nickbuy2, "")
		-- id22 = id2
		local currentTimee = os.date("%H:%M:%S")
		local today = os.date("%Y-%m-%d")
		if selectedRank == 5 then
			lua_thread.create(function()
				wait(2000)
				sampSendChat("/settag " .. id2 .. " 5Forever")
			end)
		elseif selectedRank == 4 then
			lua_thread.create(function()
				wait(2000)
				sampSendChat("/settag " .. id2 .. " 5Forever")
			end)
		end
		if moneyEarnedday2 then
			procSymmaByDate[today] = procSymmaByDate[today] or 0
			procSymmaByDate[today] = procSymmaByDate[today] + moneyEarnedday2
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end



		local moneyEarnedday3 = (procSymmaByDate[today] and procSymmaByDate[today]) or 0 -- Получаем сумму для текущей даты
		local moneyEarnedday = formatMoney(moneyEarnedday3)
	
		local message2 = "[" .. currentTimee .. "]\nПродал ранг: " .. nick ..
			"\n\nКупил ранг: " .. nickbuy2 ..
			"\nПокупаемый ранг: " .. rank2 ..
			"\nКол-во покупаемых дней: " .. day2 ..
			"\nСумма за один день: " .. symmaday2 ..
			"\nОбщая стоимость: " .. symma2 ..
			"\nС учетом процента: " .. procsymma2 ..
			"\nСумма проданная за сегодня: " .. moneyEarnedday ..
			"\nСумма проданная за неделю: " .. moneyEarned2
		local inputGroup2 = "-1002378857918"
		sendTelegram(message2, inputGroup2)
	
		local message = "[" .. currentTimee .. "] " .. nick .. " продал ранг игроку " .. name .. " .Стоимость: " .. rank
		local inputGroup = "-1002378857918"
		local ranksell = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(ranksell)
		if numericValue then
			rankdate[today] = rankdate[today] or 0
			rankdate[today] = rankdate[today] + numericValue
		else
			print("Ошибка: значение ranksell не может быть преобразовано в число")
		end
	
		saveSettings()
		sendTelegram(message, inputGroup)
	end
	if text:find("%[Семья %(Новости%)%] "..nick.."(.+)%:{FFFFFF} Пополнил склад семьи на (.+)") then
        local id, rank = text:match("%[Семья %(Новости%)%] "..nick.."(.+)%:{FFFFFF} Пополнил склад семьи на (.+)")
        local currentTimee = os.date("%H:%M:%S") 
		local message = nick.." Пополнил склад семьи на "..rank
		local inputGroup = "-4694800453"
		sendTelegram(message, inputGroup)
    end
	if text:find("%[Семья %(Новости%)%] "..nick.."(.+)%:{FFFFFF} Взял (.+)% со склада семьи!") then
        local name, rank = text:match("%[Семья %(Новости%)%] "..nick.."(.+)%:{FFFFFF} Взял (.+)% со склада семьи!")
        local currentTimee = os.date("%H:%M:%S") 
		local message = nick.." Взял "..rank.." со склада семьи"
		local inputGroup = "-4694800453"
		sendTelegram(message, inputGroup)
    end
	if text:find("%[Информация%] {ffffff}Вы установили игроку (.+)% новый тэг: {cccccc}(.+)") then
        local name, rank = text:match("%[Информация%] {ffffff}Вы установили игроку (.+)% новый тэг: {cccccc}(.+)")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." установили игроку "..name.." новый тэг: "..rank
        local inputGroup = "-1002378857918"
		lua_thread.create(function()
			wait(1000)
			sendTelegram(message, inputGroup)
		end)
    end
    if text:find("Вы повысили игрока (.+)% до (.+)% ранга") then
        local name, rank = text:match("Вы повысили игрока (.+)% до (.+)% ранга")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." повысил игрока "..name.." на "..rank.." ранг."
        local inputGroup = "-1002378857918"
        
        sendTelegram(message, inputGroup)
    end
	if text:find("Вы повысил игрока (.+)% до (.+)% ранга") then
        local name, rank = text:match("Вы повысил игрока (.+)% до (.+)% ранга")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." повысил игрока "..name.." на "..rank.." ранг."
        local inputGroup = "-1002378857918"
        
        sendTelegram(message, inputGroup)
    end
	if text:find("Вы повысил игрока (.+)% до (.+)%-%го ранга") then
        local name, rank = text:match("Вы повысил игрока (.+)% до (.+)%-%го ранга")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." повысил игрока "..name.." на "..rank.." ранг."
        local inputGroup = "-1002378857918"
        
        sendTelegram(message, inputGroup)
    end

    if text:find("%[Организация%] {FFFFFF}"..nick.." выгнал(.+)% из организации%. Причина:(.+)") then
        local currentTime = os.date("%H:%M:%S")   
        local name, reason = text:match("%[Организация%] {FFFFFF}"..nick.." выгнал(.+)% из организации%. Причина:(.+)")
		local rankuninv = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(rankuninv)
		if numericValue then
			uninvdate[today] = uninvdate[today] or 0
			uninvdate[today] = uninvdate[today] + numericValue
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end
		saveSettings()
        SendWebhook('https://discord.com/api/webhooks/1282991962747834419/hqwlwA5GqOa3UIFKbV0cS74csLe9GBJauFz422_yHdGh41zZaumeriMBIlQRyYKKOYwx',([[{
        "content": "[%s] **%s** выгнал из организации**%s** Причина:**%s**",
        "embeds": [],
        "attachments": []
        }]]):format(currentTime, nick, name, reason))
    end
	
    
    if text:find("%[Информация%](.+)% принял ваше предложение вступить к вам в организацию%.") then
        local invname= text:match("%[Информация%](.+)% принял ваше предложение вступить к вам в организацию%.")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." пригласил в организацию "..invname..""
        local inputGroup = "-1002339001236"
        
    
		local rankinv = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(rankinv)
		if numericValue then
			invdate[today] = invdate[today] or 0
			invdate[today] = invdate[today] + numericValue
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end
		saveSettings()
        sendTelegram(message, inputGroup)
        lua_thread.create(function()
            wait(500)
            sampSendChat("/giverank "..invname.." 4")
            wait(3000)
            sampSendChat("/rb Присоединяйся к нашему Discord-серверу и получи скидку 40 проц на 5-й ранг.")
            wait(1000)
            if "Kris_Sherman" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/m67vu32QV8")
            elseif "Emily_Miller" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/apkNEKpWBu")
            elseif "Kevin_Berlinetta" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/tKreypvCrj")
            elseif "Corovar_Miror" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/Nv4SaDyk")
            elseif "Dmitry_Berlinetta" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/bzqBswyJWb")
			elseif "Steven_Sadness" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/MfD4RDApdG")
			elseif "Steve_Lix" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/yVbNsKbP65")
            else
                sampSendChat("/rb Ссылка на Discord: https://discord.gg/zs2NdZXzNq")
            end
        end)
	elseif text:find("%[Информация%] {ffffff}Игрок (.+)% принял покупку ранга за (.+)") then
        local invname, test = text:match("%[Информация%] {ffffff}Игрок (.+)% принял покупку ранга за (.+)")
        local currentTimee = os.date("%H:%M:%S") 
        local message = "["..currentTimee.."] "..nick.." пригласил в организацию "..invname..""
        local inputGroup = "-1002339001236"
        
    
        
        sendTelegram(message, inputGroup)
        lua_thread.create(function()
            wait(500)
            wait(3000)
            sampSendChat("/rb Присоединяйся к нашему Discord-серверу и получи скидку 40 проц на 5-й ранг.")
            wait(1000)
            if "Kris_Sherman" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/m67vu32QV8")
            elseif "Emily_Miller" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/apkNEKpWBu")
            elseif "Kevin_Berlinetta" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/tKreypvCrj")
            elseif "Corovar_Miror" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/Nv4SaDyk")
            elseif "Dmitry_Berlinetta" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/bzqBswyJWb")
			elseif "Steven_Sadness" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/MfD4RDApdG")
			elseif "Steve_Lix" == nick then
                sampSendChat("/rb Cсылка на Discord: https://discord.gg/yVbNsKbP65")
            else
                sampSendChat("/rb Ссылка на Discord: https://discord.gg/zs2NdZXzNq")
            end
        end)
    end
    if text:find(nick.." вылечил игрока(.+)") then
        local currentTime = os.date("%H:%M:%S") 
        local invname= text:match(nick.." вылечил игрока(.+)")
		local ranksell = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(ranksell)
		if numericValue then
			lekdate[today] = lekdate[today] or 0
			lekdate[today] = lekdate[today] + numericValue
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end
		saveSettings()
        SendWebhook('https://discord.com/api/webhooks/1283018846839771148/wKIsBuBsKbztCD3Dy5X81w6FOy4CHbDQ3dSBKleyHlf9hUFfk6xCLYqD5WvVf6ASlXM6',([[{
        "content": "[%s] **%s** вылечил игрока**%s**",
        "embeds": [],
        "attachments": []
        }]]):format(currentTime, nick, invname))
    end
	if text:find(nick.." выдал мед.карту(.+)") then
        local currentTime = os.date("%H:%M:%S") 
        local invname= text:match(nick.." выдал мед.карту(.+)")
		local ranksell = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(ranksell)
		if numericValue then
			mddate[today] = mddate[today] or 0
			mddate[today] = mddate[today] + numericValue
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end
		saveSettings()
        SendWebhook('https://discord.com/api/webhooks/1283018846839771148/wKIsBuBsKbztCD3Dy5X81w6FOy4CHbDQ3dSBKleyHlf9hUFfk6xCLYqD5WvVf6ASlXM6',([[{
        "content": "[%s] **%s** выдал мед.карту**%s**",
        "embeds": [],
        "attachments": []
        }]]):format(currentTime, nick, invname))
    end
	if text:find(nick.." аннулировал мед.карту(.+)") then
        local currentTime = os.date("%H:%M:%S") 
        local invname= text:match(nick.." аннулировал мед.карту(.+)")
		local ranksell = 1
		local today = os.date("%Y-%m-%d")
		local numericValue = tonumber(ranksell)
		if numericValue then
			mddate[today] = mddate[today] or 0
			mddate[today] = mddate[today] + numericValue
		else
			print("Ошибка: значение procsymma не может быть преобразовано в число")
		end
		saveSettings()
        SendWebhook('https://discord.com/api/webhooks/1283018846839771148/wKIsBuBsKbztCD3Dy5X81w6FOy4CHbDQ3dSBKleyHlf9hUFfk6xCLYqD5WvVf6ASlXM6',([[{
        "content": "[%s] **%s** выдал мед.карту вылечил игрока**%s**",
        "embeds": [],
        "attachments": []
        }]]):format(currentTime, nick, invname))
    end
	
	if "Miya_Shelby" == nick then
		if text:find("%[R%]%s(.+)%]%s(.+)%[(.+)%]:(.+)") then
			local currentTime = os.date("%H:%M:%S") 
			local role, sender, idd, name = text:match("%[R%]%s(.+)%]%s(.+)%[(.+)%]:(.+)")
			SendWebhook('https://discord.com/api/webhooks/1306892958917722156/tqaMXZ8yxyv2frthsnPspeVok2GocggBdq3E4dpK8iTyEl35Wwc7MV4KfxVZDz7zXHGK',([[{
			  "content": "[%s] [R]%s]%s[%s]:%s",
			  "embeds": [],
			  "attachments": []
			}]]):format(currentTime, role, sender, idd, name))

		  end
	end
end  

function isInZone(x, y, z, zone)
    -- Определяем границы квадрата
    local halfSize = zone.size
    local inX = (x >= (zone.x - halfSize)) and (x <= (zone.x + halfSize))
    local inY = (y >= (zone.y - halfSize)) and (y <= (zone.y + halfSize))
    local inHeight = math.abs(z - zone.z) <= zone.heightRange

    -- Отладочные сообщения


    return inX and inY and inHeight
end


function applyCustomTheme()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col

    -- Настройка закругления кнопок
    style.FrameRounding = 10.0 -- Значение можно увеличить или уменьшить для изменения степени закругления

    local black = imgui.ImVec4(0.00, 0.00, 0.00, 0.80)
    local white = imgui.ImVec4(1.00, 1.00, 1.00, 1.00)

    local darkCherryRed = imgui.ImVec4(color0, color1, color2, color3)
    local darkCherryRedHover = imgui.ImVec4(color0+0.05, color1, color2+0.05, color3)
    local darkCherryRedActive = imgui.ImVec4(color0-0.05, color1, color2, color3)

    colors[clr.WindowBg]             = black
    colors[clr.ChildBg]              = black
    colors[clr.PopupBg]              = black
    colors[clr.MenuBarBg]            = black
    colors[clr.ScrollbarBg]          = black

    colors[clr.Text]                 = white
    colors[clr.TextDisabled]         = white
    colors[clr.FrameBg]              = black
    colors[clr.FrameBgHovered]       = black
    colors[clr.FrameBgActive]        = black
    colors[clr.TitleBg]              = imgui.ImVec4(0.00, 0.00, 0.00, 0.60)
    colors[clr.TitleBgActive]        = imgui.ImVec4(0.00, 0.00, 0.00, 0.80)
    colors[clr.TitleBgCollapsed]     = imgui.ImVec4(0.00, 0.00, 0.00, 0.40)

    colors[clr.Button]               = darkCherryRed
    colors[clr.ButtonHovered]        = darkCherryRedHover
    colors[clr.ButtonActive]         = darkCherryRedActive
    colors[clr.CheckMark]            = darkCherryRedHover
    colors[clr.SliderGrab]           = darkCherryRedHover
    colors[clr.SliderGrabActive]     = darkCherryRedHover
    colors[clr.Header]               = darkCherryRedHover
    colors[clr.HeaderHovered]        = darkCherryRedHover
    colors[clr.HeaderActive]         = darkCherryRedHover
    colors[clr.Separator]            = imgui.ImVec4(0.50, 0.50, 0.50, 0.60)
    colors[clr.SeparatorHovered]     = imgui.ImVec4(0.60, 0.60, 0.70, 0.70)
    colors[clr.SeparatorActive]      = imgui.ImVec4(0.70, 0.70, 0.90, 0.80)
    colors[clr.ResizeGrip]           = imgui.ImVec4(0.26, 0.59, 0.98, 0.20)
    colors[clr.ResizeGripHovered]    = imgui.ImVec4(0.26, 0.59, 0.98, 0.50)
    colors[clr.ResizeGripActive]     = imgui.ImVec4(color0-0.24, 0.05, color2-0.03, 0.80)
    colors[clr.PlotLines]            = imgui.ImVec4(0.61, 0.61, 0.61, 0.80)
    colors[clr.PlotLinesHovered]     = imgui.ImVec4(1.00, 0.43, 0.35, 0.80)
    colors[clr.PlotHistogram]        = imgui.ImVec4(0.90, 0.70, 0.00, 0.80)
    colors[clr.PlotHistogramHovered] = imgui.ImVec4(1.00, 0.60, 0.00, 0.80)
    colors[clr.TextSelectedBg]       = imgui.ImVec4(0.25, 1.00, 0.00, 0.40)
    colors[clr.ModalWindowDimBg]     = imgui.ImVec4(1.00, 0.98, 0.95, 0.40)
end


function cmd_send_message(data)


    if DEBUG then
        sampAddChatMessage('[Messenger] Отправка данных: ' .. json.encode(data), 0xFFFF00)
    end

    -- Асинхронный HTTP-запрос
    asyncHttpRequest("POST", SERVER_URL .. '/api/send', {
        data = json.encode(data),
        headers = {['Content-Type'] = 'application/json'},
        timeout = 5
    }, function(response)
        if response.status_code == 200 then
            connection_attempts = 0
        else
            local error_msg = response.status_code or 'Нет соединения'
            print('[Messenger] Ошибка отправки сообщения: ' .. error_msg, 0xFF0000)
            if DEBUG then
                print('[Messenger] Debug: ' .. tostring(response.text or 'No response'), 0xFFFF00)
            end
            handle_connection_error()
        end
    end, function(response)
        print('[Messenger] Ошибка запроса: ' .. tostring(response), 0xFF0000)
        handle_connection_error()
    end)
end
local updateinfo, timemeininfo, totalinv2info, Sunday1info, totalmd2info, totaluninv2info, totallek2info, dateweekinfo, Monday1info, Tuesday1info, Wednesday1info, Thursday1info, Friday1info, Saturday1info, Monday1manoyinfo, Tuesday1manoyinfo, Wednesday1manoyinfo, Thursday1manoyinfo, Friday1manoyinfo, Saturday1manoyinfo, Sunday1manoyinfo, totalmoneyEarned2info, totalranksell2info




function check_new_messages()
    asyncHttpRequest("GET", SERVER_URL .. '/api/messages?last_id=0', {
        timeout = 5
    }, function(response)
        if response.status_code == 200 then
            local result = decodeJson(response.text)
            if result and result.status == 'success' then
                for _, msg in ipairs(result.messages) do
                    -- Преобразование текста
					local converted_text = '[Ошибка: текст отсутствует]'
					if msg.text and type(msg.text) == "string" then
						converted_text, err = utf8_to_cp1251:iconv(msg.text)
						if not converted_text then
							print('[Messenger] Ошибка преобразования текста: ' .. tostring(err), 0xFF0000)
							converted_text = '[Ошибка кодировки]'
						end
					else
						print('[Messenger] Ошибка: msg.text отсутствует', 0xFF0000)
					end
					
					id = select(2, sampGetPlayerIdByCharHandle(playerPed))
					nick2 = sampGetPlayerNickname(id)
					
					if msg and msg.data then
						if msg.data.statsinfo and msg.data.statsinfo.tipsend == 1 then
							if msg.data.statsinfo.uid then
								if not uidTable[msg.data.statsinfo.uid] then
									uidTable[msg.data.statsinfo.uid] = true -- Добавляем UID в таблицу
									loadSettingsonline()
									checkstats2 = {
										[msg.data.sender] = {
											uid = msg.data.statsinfo.uid or "Нет данных",
											updateinfo = msg.data.statsinfo.updateinfo or "Нет данных",
											totalinv2info = msg.data.statsinfo.totalinv2info or "Нет данных",
											totalmd2info = msg.data.statsinfo.totalmd2info or "Нет данных",
											totaluninv2info = msg.data.statsinfo.totaluninv2info or "Нет данных",
											totallek2info = msg.data.statsinfo.totallek2info or "Нет данных",
											dateweekinfo = msg.data.statsinfo.dateweekinfo or "Нет данных",
											Monday1info = msg.data.statsinfo.Monday1info or "Нет данных",
											Tuesday1info = msg.data.statsinfo.Tuesday1info or "Нет данных",
											Wednesday1info = msg.data.statsinfo.Wednesday1info or "Нет данных",
											Thursday1info = msg.data.statsinfo.Thursday1info or "Нет данных",
											Friday1info = msg.data.statsinfo.Friday1info or "Нет данных",
											Sunday1info = msg.data.statsinfo.Sunday1info or "Нет данных",
											Saturday1info = msg.data.statsinfo.Saturday1info or "Нет данных",
											Monday1manoyinfo = msg.data.statsinfo.Monday1manoyinfo or "Нет данных",
											Tuesday1manoyinfo = msg.data.statsinfo.Tuesday1manoyinfo or "Нет данных",
											Wednesday1manoyinfo = msg.data.statsinfo.Wednesday1manoyinfo or "Нет данных",
											Thursday1manoyinfo = msg.data.statsinfo.Thursday1manoyinfo or "Нет данных",
											Friday1manoyinfo = msg.data.statsinfo.Friday1manoyinfo or "Нет данных",
											Saturday1manoyinfo = msg.data.statsinfo.Saturday1manoyinfo or "Нет данных",
											Sunday1manoyinfo = msg.data.statsinfo.Sunday1manoyinfo or "Нет данных",
											timemeininfo = msg.data.statsinfo.timemeininfo or "Нет данных",
											totalmoneyEarned2info = msg.data.statsinfo.totalmoneyEarned2info or "Нет данных",
											totalranksell2info = msg.data.statsinfo.totalranksell2info or "Нет данных",
											totaltime = msg.data.statsinfo.totaltime or "Нет данных",
										},
									}
									sampAddChatMessage(tag_q.."Данные успешно получены.", -1)
									-- Проверка существования tatsinfo
									if msg.data.tatsinfo then
										checkstats2[msg.data.sender].tatsinfo = msg.data.tatsinfo.totalinv2info or "Нет данных"
									else
										print("Ошибка: tatsinfo отсутствует в данных.")
									end
					
									checkstats = {}
									lua_thread.create(function()
										for key, value in pairs(loadstats) do
											checkstats[key] = value
										end
										for key, value in pairs(checkstats2) do
											checkstats[key] = value
										end
										wait(1000)
										saveSettingsonline()
									end)
					
									startinfo = false
								end
							else
								print("Ошибка: statsinfo.uid отсутствует.")
							end
						elseif msg.data.statsinfo and msg.data.statsinfo.tipsend == 2 then
							sampAddChatMessage(string.format('[Владелец СФМЦ]: %s', utf8_to_cp1251:iconv(msg.data.statsinfo.sms)), -1)
							startinfo = false
						else
							print("Ошибка: statsinfo отсутствует или некорректно настроено.")
						end
					else
						print("Ошибка: msg или msg.data отсутствует.")
					end
					

                    -- Пример использования данных
                    -- local additional_text = string.format("%s %s %s", text1, text2, utf8_to_cp1251:iconv(mao))

                    -- Вывод в чат без префикса "Additional:"
                    -- sampAddChatMessage(string.format('[Messenger] %s: %s %s', msg.sender, converted_text), -1)

                    if msg.id > last_message_id then
                        last_message_id = msg.id
                    end
                end
            else
                print('[Messenger] Ошибка декодирования JSON', 0xFF0000)
            end
        else
            print('[Messenger] Ошибка получения сообщений: ' .. tostring(response.status_code), 0xFF0000)
        end
    end, function(response)
        print('[Messenger] Ошибка запроса: ' .. tostring(response), 0xFF0000)
    end)
end










function handle_connection_error()
    connection_attempts = connection_attempts + 1
    if connection_attempts >= max_connection_attempts then
        print('[Messenger] Не удалось подключиться к серверу после нескольких попыток. Проверьте настройки и доступность сервера.')
        connection_attempts = 0 -- Сбрасываем счетчик для следующей серии попыток
        wait(retry_delay)
    else
        print(string.format('[Messenger] Ошибка подключения. Попытка %d из %d. Повтор через %d секунд...', 
            connection_attempts, max_connection_attempts, retry_delay / 1000))
        wait(retry_delay)
    end
end

function cmd_toggle_debug()
    DEBUG = not DEBUG
    config.main.debug = DEBUG
    inicfg.save(config, 'messenger')
    sampAddChatMessage('[Messenger] Режим отладки ' .. (DEBUG and 'включен' or 'выключен'), -1)
end

function getNickname()
    local result, id = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if result then
        return sampGetPlayerNickname(id)
    end
    return "Unknown"
end


function decodeJson(text)
    if type(text) ~= "string" or text == "" then
        print("Error: Invalid JSON input. Expected non-empty string.")
        return nil
    end

    local success, result = pcall(json2.decode, text)
    if not success then
        print("Error decoding JSON:", result)
        return nil
    end
    return result
end



function toUtf8(text)
    local iconv = require 'iconv'
    local conv = iconv.new('utf-8', 'cp1251') -- Из CP1251 в UTF-8
    local converted, err = conv:iconv(text)
    if not converted then
        return text -- Возвращаем оригинал, если не удалось
    end
    return converted
end



