-- Visual Library self-update support.
-- Requires an explicitly configured GitHub repository; never modifies Bookshelf.
local Updater = {}
Updater.version = "0.3.1"

local function shellquote(s)
    return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

function Updater.validRepo(repo)
    if type(repo) ~= "string" or #repo > 110 then return false end
    local owner, name = repo:match("^([%w%-]+)/([%w%._%-]+)$")
    return owner ~= nil and name ~= nil and #owner <= 39
        and owner:match("^[%w]") ~= nil and owner:match("[%w]$") ~= nil
        and name:match("^[%w]") ~= nil and not name:find("%.%.", 1, false)
end

local function versionParts(version)
    if type(version) ~= "string" then return nil end
    local major, minor, patch = version:match("^v?(%d+)%.(%d+)%.(%d+)$")
    if not major then return nil end
    return tonumber(major), tonumber(minor), tonumber(patch)
end

function Updater.newer(remote, local_version)
    local a,b,c = versionParts(remote)
    local x,y,z = versionParts(local_version)
    if not a or not x then return false end
    if a ~= x then return a > x end
    if b ~= y then return b > y end
    return c > z
end

local function sourceDir()
    local source = debug.getinfo(1, "S").source
    if source:sub(1,1) ~= "@" then return nil end
    return source:sub(2):match("^(.*)/updater%.lua$")
end

local function commandOk(command)
    local result, why, code = os.execute(command)
    return result == true or result == 0 or (result == "exit" and code == 0)
end

local function readFile(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

-- A new release must be published to the repository's GitHub Releases.
-- No network activity happens unless the user explicitly checks for updates.
function Updater.check(repo, settings_dir)
    if not Updater.validRepo(repo) then return nil, "Set your GitHub repository first (owner/repo)." end
    local payload = settings_dir .. "/.visual_library_latest.json"
    os.remove(payload)
    local url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
    local command = "curl --fail --location --silent --show-error --connect-timeout 8 --max-time 20 "
        .. "-H 'Accept: application/vnd.github+json' -H 'User-Agent: VisualLibrary-KOReader' "
        .. shellquote(url) .. " -o " .. shellquote(payload) .. " >/dev/null 2>&1"
    if not commandOk(command) then
        os.remove(payload)
        return nil, "Couldn't check GitHub. Check Wi-Fi, the repository, and its Releases page."
    end
    local json = readFile(payload)
    os.remove(payload)
    if not json then return nil, "GitHub returned no release information." end
    -- Only accept straightforward version tags, never arbitrary data in a shell command.
    local tag = json:match('"tag_name"%s*:%s*"([^"]+)"')
    if not tag or not versionParts(tag) then
        return nil, "Latest GitHub Release needs a tag like v0.3.2."
    end
    return {tag=tag, version=tag:gsub("^v", ""), newer=Updater.newer(tag, Updater.version)}
end

function Updater.install(repo, release, settings_dir)
    local dir = sourceDir()
    if not Updater.validRepo(repo) or not release or not release.tag or not versionParts(release.tag) then
        return false, "Invalid update source or release version."
    end
    if not Updater.newer(release.tag, Updater.version) then
        return false, "No newer release available."
    end
    if not dir or not dir:match("/visual_library%.koplugin$") then
        return false, "Cannot locate the Visual Library plugin directory."
    end
    local script = dir .. "/install_update.sh"
    local f = io.open(script, "rb")
    if not f then return false, "Update installer is missing." end
    f:close()
    local log = settings_dir .. "/visual_library_update.log"
    local cmd = "sh " .. shellquote(script) .. " " .. shellquote(repo) .. " "
        .. shellquote(release.tag) .. " " .. shellquote(dir) .. " >" .. shellquote(log) .. " 2>&1"
    if commandOk(cmd) then
        return true, "Visual Library " .. release.version .. " installed. Fully exit and restart KOReader to load it."
    end
    local output = readFile(log)
    local reason = output and output:match("ERROR: ([^\r\n]+)") or nil
    return false, "Update failed: " .. (reason or "check settings/visual_library_update.log")
end

return Updater
