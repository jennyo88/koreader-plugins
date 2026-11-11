local DataStorage = require("datastorage")
local LuaSettings = require("luasettings")

local BackupHealth = {}

local SETTINGS_PATH =
    DataStorage:getSettingsDir()
    .. "/readingbrain_backup_health.lua"

local function settings()
    return LuaSettings:open(SETTINGS_PATH)
end

local function basename(path)
    return tostring(path or ""):match("([^/]+)$") or tostring(path or "")
end

local function parse_filename_time(path)
    local name = basename(path)

    local y, m, d, hh, mm, ss =
        name:match(
            "bookmory_(%d%d%d%d)(%d%d)(%d%d)_(%d%d)(%d%d)(%d%d)"
        )

    if not y then
        y, m, d =
            name:match(
                "bookmory_(%d%d%d%d)(%d%d)(%d%d)"
            )
        hh, mm, ss = "12", "00", "00"
    end

    if not y then
        return nil
    end

    return os.time{
        year = tonumber(y),
        month = tonumber(m),
        day = tonumber(d),
        hour = tonumber(hh) or 12,
        min = tonumber(mm) or 0,
        sec = tonumber(ss) or 0,
        isdst = false,
    }
end

function BackupHealth:getLastSynced()
    local s = settings()

    return
        s:readSetting("last_synced_backup"),
        tonumber(
            s:readSetting(
                "last_synced_backup_time",
                0
            )
        ) or 0,
        tonumber(
            s:readSetting(
                "last_sync_time",
                0
            )
        ) or 0
end

function BackupHealth:markSynced(path, backup_time)
    if not path then
        return
    end

    local t =
        tonumber(backup_time)
        or parse_filename_time(path)
        or os.time()

    local s = settings()

    s:saveSetting(
        "last_synced_backup",
        basename(path)
    )

    s:saveSetting(
        "last_synced_backup_time",
        t
    )

    s:saveSetting(
        "last_sync_time",
        os.time()
    )

    s:flush()
end

function BackupHealth:getStatus(path, backup_time)
    if not path then
        return {
            code = "MISSING",
            label = "MISSING",
            detail = "No Bookmory backup found.",
            path = nil,
            backup_time = nil,
            age_days = nil,
            is_new = false,
        }
    end

    backup_time =
        tonumber(backup_time)
        or parse_filename_time(path)
        or 0

    local age_seconds =
        math.max(
            0,
            os.time() - backup_time
        )

    local age_days =
        math.floor(
            age_seconds / 86400
        )

    local last_name, last_time =
        self:getLastSynced()

    local current_name = basename(path)
    local is_new =
        current_name ~= last_name
        and backup_time >= (tonumber(last_time) or 0)

    if is_new then
        return {
            code = "NEW_BACKUP",
            label = "NEW BACKUP",
            detail = "A newer Bookmory backup is waiting to be synced.",
            path = path,
            backup_time = backup_time,
            age_days = age_days,
            is_new = true,
        }
    end

    if age_days >= 14 then
        return {
            code = "STALE",
            label = "STALE",
            detail =
                "Bookmory backup is "
                .. tostring(age_days)
                .. " days old.",
            path = path,
            backup_time = backup_time,
            age_days = age_days,
            is_new = false,
        }
    elseif age_days >= 7 then
        return {
            code = "AGING",
            label = "AGING",
            detail =
                "Bookmory backup is "
                .. tostring(age_days)
                .. " days old.",
            path = path,
            backup_time = backup_time,
            age_days = age_days,
            is_new = false,
        }
    end

    return {
        code = "CURRENT",
        label = "CURRENT",
        detail =
            age_days == 0
            and "Bookmory backup is current."
            or (
                "Bookmory backup is "
                .. tostring(age_days)
                .. " days old."
            ),
        path = path,
        backup_time = backup_time,
        age_days = age_days,
        is_new = false,
    }
end

function BackupHealth:formatBody(status)
    status = status or {
        code = "MISSING",
        label = "MISSING",
    }

    if not status.path then
        return
            "BOOKMORY\n"
            .. "Latest backup ...... Not found\n"
            .. "Status ............. Missing"
    end

    local date_text =
        status.backup_time
        and os.date(
            "%b %d, %Y",
            status.backup_time
        )
        or basename(status.path)

    local age_text =
        status.age_days == 0
        and "Today"
        or (
            tostring(status.age_days or "?")
            .. " days"
        )

    return
        "BOOKMORY\n"
        .. "Latest backup ...... "
        .. date_text
        .. "\n"
        .. "Age ................ "
        .. age_text
        .. "\n"
        .. "Status ............. "
        .. tostring(status.label or "UNKNOWN")
end

return BackupHealth
