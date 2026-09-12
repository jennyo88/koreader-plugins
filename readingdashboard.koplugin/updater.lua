local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local UIManager = require("ui/uimanager")

local lfs = require("libs/libkoreader-lfs")
local ltn12 = require("ltn12")
local rapidjson = require("rapidjson")
local socket = require("socket")
local socketutil = require("socketutil")
local https = require("ssl.https")

local _ = require("gettext")


local Updater = {}


-- ---------------------------------------------------------
-- Configuration
-- ---------------------------------------------------------

Updater.plugin_id = "readingdashboard"
Updater.plugin_name = "Reading Dashboard"

Updater.repo_owner = "jennyo88"
Updater.repo_name = "koreader-plugins"
Updater.branch = "main"

Updater.base_url =
    "https://raw.githubusercontent.com/"
    .. Updater.repo_owner
    .. "/"
    .. Updater.repo_name
    .. "/"
    .. Updater.branch

Updater.manifest_url =
    Updater.base_url .. "/manifest.json"

Updater.plugin_url =
    Updater.base_url
    .. "/readingdashboard.koplugin"


-- ---------------------------------------------------------
-- File helpers
-- ---------------------------------------------------------

local function file_exists(path)
    local attr = lfs.attributes(path)
    return attr ~= nil
end


local function is_dir(path)
    local attr = lfs.attributes(path)
    return attr and attr.mode == "directory"
end


local function mkdir(path)
    if is_dir(path) then
        return true
    end

    local ok, err = lfs.mkdir(path)

    if not ok and not is_dir(path) then
        return false, err
    end

    return true
end


local function read_file(path)
    local file = io.open(path, "rb")

    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()

    return content
end


local function write_file(path, content)
    local file, err = io.open(path, "wb")

    if not file then
        return false, err
    end

    file:write(content)
    file:close()

    return true
end


local function copy_file(source, destination)
    local content = read_file(source)

    if not content then
        return false, "Could not read " .. source
    end

    return write_file(destination, content)
end


local function remove_file(path)
    if file_exists(path) then
        os.remove(path)
    end
end


local function remove_directory(path)
    if not is_dir(path) then
        return
    end

    for item in lfs.dir(path) do
        if item ~= "." and item ~= ".." then
            local full_path = path .. "/" .. item
            local attr = lfs.attributes(full_path)

            if attr and attr.mode == "directory" then
                remove_directory(full_path)
            else
                os.remove(full_path)
            end
        end
    end

    lfs.rmdir(path)
end


local function ensure_clean_directory(path)
    remove_directory(path)

    local ok, err = mkdir(path)

    if not ok then
        return false, err
    end

    return true
end


-- ---------------------------------------------------------
-- Network helpers
-- ---------------------------------------------------------

local function download(url)
    local sink = {}

    socketutil:set_timeout(
        socketutil.LARGE_BLOCK_TIMEOUT,
        socketutil.LARGE_TOTAL_TIMEOUT
    )

    local request = {
        url = url,
        method = "GET",
        sink = ltn12.sink.table(sink),
        headers = {
            ["User-Agent"] =
                "KOReader-ReadingDashboard-Updater",
            ["Accept"] = "*/*",
        },
    }

    local _, code, headers, status =
        https.request(request)

    socketutil:reset_timeout()

    if not code then
        return nil, status or "Network error"
    end

    if tonumber(code) ~= 200 then
        return nil,
            string.format(
                "HTTP %s: %s",
                tostring(code),
                tostring(status or "")
            )
    end

    return table.concat(sink)
end


-- ---------------------------------------------------------
-- Version helpers
-- ---------------------------------------------------------

local function version_parts(version)
    local parts = {}

    for number in tostring(version):gmatch("%d+") do
        table.insert(parts, tonumber(number))
    end

    return parts
end


local function compare_versions(a, b)
    local av = version_parts(a)
    local bv = version_parts(b)

    local count =
        math.max(#av, #bv)

    for i = 1, count do
        local x = av[i] or 0
        local y = bv[i] or 0

        if x < y then
            return -1
        elseif x > y then
            return 1
        end
    end

    return 0
end


-- ---------------------------------------------------------
-- Manifest
-- ---------------------------------------------------------

function Updater:getManifest()
    local body, err =
        download(self.manifest_url)

    if not body then
        return nil,
            "Could not download manifest:\n"
            .. tostring(err)
    end

    local ok, manifest =
        pcall(
            rapidjson.decode,
            body
        )

    if not ok or not manifest then
        return nil,
            "Could not read manifest.json."
    end

    if not manifest.plugins then
        return nil,
            "Manifest does not contain plugins."
    end

    local plugin =
        manifest.plugins[self.plugin_id]

    if not plugin then
        return nil,
            "Reading Dashboard was not found in manifest."
    end

    if not plugin.version then
        return nil,
            "Manifest does not contain a version."
    end

    if not plugin.files then
        return nil,
            "Manifest does not contain a file list."
    end

    return plugin
end


-- ---------------------------------------------------------
-- Paths
-- ---------------------------------------------------------

function Updater:getPluginDirectory()
    return "/mnt/us/koreader/plugins/"
        .. self.plugin_id
        .. ".koplugin"
end


function Updater:getBackupDirectory()
    return "/mnt/us/koreader/plugins/"
        .. self.plugin_id
        .. ".koplugin.backup"
end


function Updater:getTempDirectory()
    return "/tmp/"
        .. self.plugin_id
        .. "-update"
end


-- ---------------------------------------------------------
-- Backup
-- ---------------------------------------------------------

function Updater:createBackup(files)
    local plugin_dir =
        self:getPluginDirectory()

    local backup_dir =
        self:getBackupDirectory()

    local ok, err =
        ensure_clean_directory(
            backup_dir
        )

    if not ok then
        return false,
            "Could not create backup:\n"
            .. tostring(err)
    end

    for _, filename in ipairs(files) do
        local source =
            plugin_dir
            .. "/"
            .. filename

        local destination =
            backup_dir
            .. "/"
            .. filename

        if file_exists(source) then
            local copied, copy_err =
                copy_file(
                    source,
                    destination
                )

            if not copied then
                return false,
                    "Backup failed for "
                    .. filename
                    .. ":\n"
                    .. tostring(copy_err)
            end
        end
    end

    return true
end


-- ---------------------------------------------------------
-- Download update
-- ---------------------------------------------------------

function Updater:downloadFiles(files)
    local temp_dir =
        self:getTempDirectory()

    local ok, err =
        ensure_clean_directory(
            temp_dir
        )

    if not ok then
        return false,
            "Could not create temporary update folder:\n"
            .. tostring(err)
    end

    for _, filename in ipairs(files) do
        local url =
            self.plugin_url
            .. "/"
            .. filename

        local content, download_err =
            download(url)

        if not content then
            remove_directory(temp_dir)

            return false,
                "Could not download "
                .. filename
                .. ":\n"
                .. tostring(download_err)
        end

        if #content == 0 then
            remove_directory(temp_dir)

            return false,
                filename
                .. " downloaded as an empty file."
        end

        local destination =
            temp_dir
            .. "/"
            .. filename

        local written, write_err =
            write_file(
                destination,
                content
            )

        if not written then
            remove_directory(temp_dir)

            return false,
                "Could not save "
                .. filename
                .. ":\n"
                .. tostring(write_err)
        end
    end

    return true
end


-- ---------------------------------------------------------
-- Install downloaded update
-- ---------------------------------------------------------

function Updater:installFiles(files)
    local temp_dir =
        self:getTempDirectory()

    local plugin_dir =
        self:getPluginDirectory()

    for _, filename in ipairs(files) do
        local source =
            temp_dir
            .. "/"
            .. filename

        if not file_exists(source) then
            return false,
                "Missing downloaded file: "
                .. filename
        end
    end

    local backed_up, backup_err =
        self:createBackup(files)

    if not backed_up then
        return false,
            backup_err
    end

    for _, filename in ipairs(files) do
        local source =
            temp_dir
            .. "/"
            .. filename

        local destination =
            plugin_dir
            .. "/"
            .. filename

        local copied, copy_err =
            copy_file(
                source,
                destination
            )

        if not copied then
            return false,
                "Could not install "
                .. filename
                .. ":\n"
                .. tostring(copy_err)
        end
    end

    remove_directory(temp_dir)

    return true
end


-- ---------------------------------------------------------
-- Restore backup
-- ---------------------------------------------------------

function Updater:restoreBackup()
    local plugin_dir =
        self:getPluginDirectory()

    local backup_dir =
        self:getBackupDirectory()

    if not is_dir(backup_dir) then
        UIManager:show(
            InfoMessage:new{
                text =
                    _("No previous version backup exists."),
            }
        )

        return
    end

    local restored = 0

    for filename in lfs.dir(backup_dir) do
        if filename ~= "."
            and filename ~= ".." then

            local source =
                backup_dir
                .. "/"
                .. filename

            local destination =
                plugin_dir
                .. "/"
                .. filename

            local attr =
                lfs.attributes(source)

            if attr
                and attr.mode == "file" then

                local ok =
                    copy_file(
                        source,
                        destination
                    )

                if ok then
                    restored =
                        restored + 1
                end
            end
        end
    end

    if restored > 0 then
        UIManager:show(
            InfoMessage:new{
                text =
                    _(
                        "Previous version restored.\n\nRestart KOReader to apply it."
                    ),
            }
        )
    else
        UIManager:show(
            InfoMessage:new{
                text =
                    _("Backup could not be restored."),
            }
        )
    end
end


function Updater:confirmRestore()
    UIManager:show(
        ConfirmBox:new{
            text =
                _(
                    "Restore the previous version of Reading Dashboard?"
                ),

            ok_text =
                _("Restore"),

            ok_callback =
                function()
                    self:restoreBackup()
                end,
        }
    )
end


-- ---------------------------------------------------------
-- Update
-- ---------------------------------------------------------

function Updater:performUpdate(plugin)
    UIManager:show(
        InfoMessage:new{
            text =
                _(
                    "Downloading Reading Dashboard update…"
                ),
        }
    )

    local downloaded, download_err =
        self:downloadFiles(
            plugin.files
        )

    if not downloaded then
        UIManager:show(
            InfoMessage:new{
                text =
                    _(
                        "Update failed.\n\n"
                    )
                    .. tostring(
                        download_err
                    ),
            }
        )

        return
    end

    local installed, install_err =
        self:installFiles(
            plugin.files
        )

    if not installed then
        UIManager:show(
            InfoMessage:new{
                text =
                    _(
                        "Update could not be installed.\n\n"
                    )
                    .. tostring(
                        install_err
                    )
                    .. _(
                        "\n\nYour previous version was backed up."
                    ),
            }
        )

        return
    end

    UIManager:show(
        ConfirmBox:new{
            text =
                string.format(
                    _(
                        "Reading Dashboard %s installed successfully.\n\nThis will take effect on next restart."
                    ),
                    tostring(
                        plugin.version
                    )
                ),
            ok_text =
                _("Restart now"),
            
            cancel_text =
                _("Restart later"),
            
            ok_callback =
                function()
                    UIManager:restartKOReader()
                end,
        }
    )
end


function Updater:checkForUpdates(installed_version)

    local checking_message =
        InfoMessage:new{
            text =
                _("Checking for updates…"),
        }

    UIManager:show(
        checking_message
    )


    local plugin, err =
        self:getManifest()


    -- Always close the temporary checking message
    -- before showing the result.
    UIManager:close(
        checking_message
    )


    if not plugin then

        UIManager:show(
            InfoMessage:new{
                text =
                    _(
                        "Could not check for updates.\n\n"
                    )
                    .. tostring(err),
            }
        )

        return
    end


    local comparison =
        compare_versions(
            installed_version,
            plugin.version
        )


    if comparison >= 0 then

        UIManager:show(
            InfoMessage:new{
                text =
                    string.format(
                        _(
                            "Reading Dashboard is up to date.\n\nInstalled: %s\nLatest: %s"
                        ),
                        tostring(
                            installed_version
                        ),
                        tostring(
                            plugin.version
                        )
                    ),
            }
        )

        return
    end


    UIManager:show(
        ConfirmBox:new{
            text =
                string.format(
                    _(
                        "A Reading Dashboard update is available.\n\nInstalled: %s\nAvailable: %s"
                    ),
                    tostring(
                        installed_version
                    ),
                    tostring(
                        plugin.version
                    )
                ),

            ok_text =
                _("Update"),

            cancel_text =
                _("Cancel"),

            ok_callback =
                function()

                    self:performUpdate(
                        plugin
                    )
                end,
        }
    )
end


return Updater
