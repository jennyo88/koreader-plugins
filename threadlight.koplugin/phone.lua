-- Threadlight phone editor: temporary, local-only HTTP service for the open EPUB.
-- Requires LuaSocket shipped with KOReader. No files, shell commands or cloud services.
local M = {}

local function decode(value)
    return (value:gsub('+', ' '):gsub('%%(%x%x)', function(hex)
        return string.char(tonumber(hex, 16))
    end))
end

function M.parseForm(body)
    local out = {}
    for pair in (body .. '&'):gmatch('(.-)&') do
        local k, v = pair:match('^([^=]+)=(.*)$')
        if k then out[decode(k)] = decode(v) end
    end
    return out
end

local function escape(s)
    return tostring(s or ''):gsub('&','&amp;'):gsub('<','&lt;'):gsub('>','&gt;')
        :gsub('"','&quot;'):gsub("'", '&#39;')
end
M.escape = escape

function M.page(token, status, archive)
    local action = '/?key=' .. token
    local msg = status and ('<p class="notice">' .. escape(status) .. '</p>') or ''
    return [[<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="referrer" content="no-referrer"><title>Threadlight · Phone editor</title>
<style>
:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f4f1ea;color:#25231f;font:16px system-ui,-apple-system,sans-serif}
main{max-width:620px;margin:auto;padding:28px 20px 64px}h1{font:600 2rem Georgia,serif;margin:0 0 6px}
small{color:#625c54}h2{font-size:1.15rem;margin:32px 0 12px}label{display:block;font-weight:600;margin:14px 0 6px}
textarea,input{width:100%;padding:12px;border:1px solid #999085;border-radius:8px;background:white;color:#222;font:inherit}
textarea{min-height:118px;resize:vertical}input{height:48px}button{margin-top:16px;border:0;border-radius:8px;background:#292e2b;color:white;padding:13px 20px;font:600 1rem system-ui;min-height:48px}
.notice{padding:12px;background:#e4efe1;border-radius:8px}section{padding-bottom:28px;border-bottom:1px solid #ccc6bd}footer{margin-top:20px;color:#625c54;font-size:.9rem;line-height:1.5}
</style></head><body><main><h1>Threadlight</h1><small>Phone editor · current open book · local Wi-Fi only</small>]] .. msg ..
    '<section><h2>Save a checkpoint</h2><form method="post" action="'..action..'">' ..
    '<input type="hidden" name="type" value="checkpoint">' ..
    '<label for="what">What just happened?</label><textarea id="what" name="what" maxlength="4000" required></textarea>' ..
    '<label for="remember">What should I remember next time?</label><textarea id="remember" name="remember" maxlength="4000"></textarea>' ..
    '<button type="submit">Save checkpoint</button></form></section>' ..
    '<section><h2>Start a story thread</h2><form method="post" action="'..action..'">' ..
    '<input type="hidden" name="type" value="thread">' ..
    '<label for="name">Thread name or question</label><input id="name" name="name" maxlength="160" required>' ..
    '<label for="note">What do I know so far?</label><textarea id="note" name="note" maxlength="4000"></textarea>' ..
    '<button type="submit">Start thread</button></form></section>' ..
    '<section><h2>Highlights by checkpoint</h2><p>Existing KOReader highlights, grouped by reading position. Tap a checkpoint to expand.</p>' .. (archive or '<p>Open the page again to refresh highlights.</p>') .. '</section>' ..
    '<footer>Saved notes belong to the EPUB currently open on your Kindle and use its current reading position. Keep the Kindle awake and leave Phone editor enabled until you finish. Stop the editor on Kindle afterward. Anyone with this page link on your local network can add notes while the editor is active.</footer>' ..
    '</main></body></html>'
end

function M.localIP(socket)
    local udp = socket.udp()
    if not udp then return nil end
    udp:settimeout(0)
    -- UDP connect just selects a route; no data is transmitted.
    local ok = udp:setpeername('192.0.2.1', 9)
    local ip = ok and udp:getsockname() or nil
    udp:close()
    if ip and ip ~= '0.0.0.0' and ip ~= '127.0.0.1' then return ip end
end

function M.newToken()
    local f = io.open('/dev/urandom', 'rb')
    if not f then return nil end -- fail closed, never substitute predictable math.random
    local bytes = f:read(18)
    f:close()
    if not bytes or #bytes ~= 18 then return nil end
    return (bytes:gsub('.', function(c) return string.format('%02x', c:byte()) end))
end

local Server = {}
Server.__index = Server

function M.start(callback)
    local ok, socket = pcall(require, 'socket')
    if not ok then return nil, 'LuaSocket is unavailable.' end
    local token = M.newToken()
    if not token then return nil, 'Secure random bytes are unavailable.' end
    local ip = M.localIP(socket)
    if not ip then return nil, 'Could not find a Wi-Fi IP address. Connect to Wi-Fi first.' end
    local listener, err = socket.bind(ip, 0)
    if not listener then return nil, err or 'Unable to listen on Wi-Fi.' end
    listener:settimeout(0)
    local _, port = listener:getsockname()
    return setmetatable({ socket = socket, listener = listener, ip = ip, port = port,
        token = token, callback = callback, started = os.time(), client = nil }, Server)
end

function Server:url()
    return string.format('http://%s:%d/?key=%s', self.ip, self.port, self.token)
end

function Server:closeClient()
    if self.client then pcall(function() self.client:close() end) end
    self.client, self.buffer, self.sending = nil, nil, nil
end

function Server:stop()
    self:closeClient()
    if self.listener then self.listener:close(); self.listener = nil end
end

function Server:reply(code, body)
    local title = ({[200]='OK',[400]='Bad Request',[403]='Forbidden',[405]='Method Not Allowed',
        [413]='Payload Too Large'})[code] or 'Error'
    self.sending = string.format('HTTP/1.1 %d %s\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: %d\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\nContent-Security-Policy: default-src \'none\'; style-src \'unsafe-inline\'; form-action \'self\'; base-uri \'none\'\r\nReferrer-Policy: no-referrer\r\nConnection: close\r\n\r\n', code, title, #body) .. body
end

function Server:process()
    local headEnd = self.buffer:find('\r\n\r\n', 1, true)
    if not headEnd then
        if #self.buffer > 8192 then self:reply(413, 'Request too large.') end
        return
    end
    if headEnd > 8192 then self:reply(413, 'Request too large.'); return end
    local header = self.buffer:sub(1, headEnd - 1)
    local method, target, proto = header:match('^(%u+)%s+([^%s]+)%s+(HTTP/1%.[01])\r\n')
    if not method or not target or not proto then self:reply(400, 'Invalid request.'); return end
    local key = target:match('^/%?key=([a-f0-9]+)$')
    if key ~= self.token then self:reply(403, 'Invalid or expired editor link.'); return end
    if method == 'GET' then
        local ok, archive = self.callback({ type = 'overview' })
        self:reply(200, M.page(self.token, nil, ok and archive or nil)); return
    end
    if method ~= 'POST' then self:reply(405, 'Only GET and POST are supported.'); return end
    local length = header:lower():match('\r\ncontent%-length:%s*(%d+)%s*\r?')
    if not length then
        length = header:lower():match('\r\ncontent%-length:%s*(%d+)%s*$')
    end
    length = tonumber(length)
    if not length then self:reply(400, 'Missing Content-Length.'); return end
    if length > 12000 then self:reply(413, 'Note is too long.'); return end
    if not header:lower():find('content%-type:%s*application/x%-www%-form%-urlencoded') then
        self:reply(400, 'Unsupported form encoding.'); return
    end
    local body = self.buffer:sub(headEnd + 4)
    if #body < length then return end
    local form = M.parseForm(body:sub(1, length))
    local success, message = self.callback(form)
    local archive_ok, archive = self.callback({ type = 'overview' })
    self:reply(success and 200 or 400, M.page(self.token, message, archive_ok and archive or nil))
end

function Server:poll()
    if not self.listener then return end
    if not self.client then
        local c = self.listener:accept()
        if not c then return end
        c:settimeout(0)
        self.client, self.buffer, self.sending, self.connected_at = c, '', nil, os.time()
    end
    if os.time() - self.connected_at > 20 then self:closeClient(); return end
    if not self.sending then
        local data, err, partial = self.client:receive(8192)
        local chunk = data or partial or ''
        if chunk ~= '' then self.buffer = self.buffer .. chunk end
        if #self.buffer > 22000 then self:reply(413, 'Request too large.')
        elseif #self.buffer > 0 then self:process() end
        if err == 'closed' and not self.sending then self:closeClient(); return end
    end
    if self.sending then
        local sent, err, last = self.client:send(self.sending)
        local n = sent or last or 0
        if n > 0 then self.sending = self.sending:sub(n + 1) end
        if self.sending == '' or (err and err ~= 'timeout') then self:closeClient() end
    end
end

return M
