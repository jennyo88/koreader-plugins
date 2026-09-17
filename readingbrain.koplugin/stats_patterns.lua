local SQ3 = require("lua-ljsqlite3/init")
local lfs = require("libs/libkoreader-lfs")

local StatsPatterns = {}
local DB_PATH = "/mnt/us/readingbrain/readingbrain.sqlite3"
local MONTHS = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
local WEEKDAYS = {"Sun","Mon","Tue","Wed","Thu","Fri","Sat"}

local function exists(path)
    local a = lfs.attributes(path)
    return a and a.mode == "file"
end

local function normalize(v)
    if type(v) ~= "string" then return "" end
    v=v:lower():gsub("&"," and "):gsub("[^%w%s]"," "):gsub("%s+"," ")
    return v:match("^%s*(.-)%s*$") or ""
end

local function human(seconds)
    seconds=tonumber(seconds) or 0
    local m=math.floor(seconds/60)
    local h=math.floor(m/60)
    m=m%60
    if h>0 then return string.format("%dh %02dm",h,m) end
    return string.format("%dm",m)
end

local function span(seconds)
    local d=(tonumber(seconds) or 0)/86400
    if d<1 then return string.format("%.1fh",(tonumber(seconds) or 0)/3600) end
    if d<10 then return string.format("%.1f days",d) end
    return string.format("%.0f days",d)
end

local function bar(value,max_value,width)
    width=width or 16
    if not max_value or max_value<=0 then return string.rep("░",width) end
    local n=math.floor((value/max_value)*width+0.5)
    n=math.max(0,math.min(width,n))
    return string.rep("█",n)..string.rep("░",width-n)
end

local function latest_rating(book)
    local r=tonumber(book.last_read_done_star)
    if r and r>0 then return r end
    local reads=book.reads or {}
    for i=#reads,1,-1 do
        r=tonumber(reads[i].star)
        if r and r>0 then return r end
    end
end

local function tags_for(book)
    local out={}
    if type(book.tags)=="table" then
        for _,t in ipairs(book.tags) do if type(t)=="string" and t~="" then table.insert(out,t) end end
    elseif type(book.tags)=="string" then
        for t in book.tags:gmatch("#([^#]+)") do
            t=t:match("^%s*(.-)%s*$")
            if t and t~="" then table.insert(out,t) end
        end
    end
    return out
end

local function authors_for(book)
    if type(book.authors)=="table" then return book.authors end
    if type(book.authors)=="string" and book.authors~="" then return {book.authors} end
    if type(book.author)=="string" and book.author~="" then return {book.author} end
    return {}
end

local function bookmory_sessions(book)
    local out={}
    for _,read in ipairs(book.reads or {}) do
        for _,timer in ipairs(read.read_timer_list or {}) do
            local ms=tonumber(timer.read_started_at) or tonumber(timer.created_at) or 0
            local st=math.floor(ms/1000)
            local dur=tonumber(timer.elapsed_sec) or 0
            if st>0 and dur>0 then table.insert(out,{start_time=st,duration=dur}) end
        end
    end
    table.sort(out,function(a,b) return a.start_time<b.start_time end)
    return out
end

local function unified_sessions()
    local out={}
    if not exists(DB_PATH) then return out end
    local ok=pcall(function()
        local db=SQ3.open(DB_PATH)
        db:exec("PRAGMA query_only = ON;")
        local stmt=db:prepare([[SELECT b.title,b.authors,s.medium,s.start_time,s.duration FROM sessions s LEFT JOIN books b ON b.book_key=s.book_key WHERE s.duration>0 ORDER BY s.start_time;]])
        local rows,n=stmt:reset():resultset("i")
        if rows and n and n>0 then
            for i=1,n do
                table.insert(out,{title=rows[1][i] or "Unknown title",authors=rows[2][i] or "",medium=rows[3][i] or "Unknown",start_time=tonumber(rows[4][i]) or 0,duration=tonumber(rows[5][i]) or 0})
            end
        end
        stmt:close(); db:close()
    end)
    if not ok then return {} end
    return out
end


function StatsPatterns:overview(bookmory_books)
    local sessions =
        read_unified_sessions()

    if #sessions == 0 then
        return
            "No unified history yet.\n\n"
            .. "Run Sync Unified History first."
    end

    local year = current_year()
    local total = 0
    local kindle = 0
    local audio = 0
    local hybrid = 0
    local days = {}
    local books = {}
    local session_count = 0

    for _, s in ipairs(sessions) do
        if same_year(s, year) then
            total = total + s.duration
            session_count = session_count + 1

            if s.medium == "Kindle" then
                kindle = kindle + s.duration
            elseif s.medium == "Audiobook" then
                audio = audio + s.duration
            elseif s.medium == "External/Hybrid" then
                hybrid = hybrid + s.duration
            end

            days[os.date("%Y-%m-%d", s.start_time)] = true
            books[normalize(s.title)] = true
        end
    end

    local active_days = 0
    for _ in pairs(days) do
        active_days = active_days + 1
    end

    local book_count = 0
    for key in pairs(books) do
        if key ~= "" then
            book_count = book_count + 1
        end
    end

    local average_session =
        session_count > 0
        and total / session_count
        or 0

    local max_format =
        math.max(kindle, audio, hybrid, 1)

    local lines = {}

    section(lines, tostring(year))
    table.insert(lines, "Total reading    " .. human_time(total))
    table.insert(lines, "Reading days     " .. tostring(active_days))
    table.insert(lines, "Books active     " .. tostring(book_count))
    table.insert(lines, "Avg. session     " .. human_time(average_session))

    section(lines, "FORMAT MIX")
    table.insert(lines, "Kindle           " .. bar(kindle, max_format, 10) .. "  " .. human_time(kindle))
    table.insert(lines, "Audiobook        " .. bar(audio, max_format, 10) .. "  " .. human_time(audio))
    table.insert(lines, "External/Hybrid  " .. bar(hybrid, max_format, 10) .. "  " .. human_time(hybrid))

    return table.concat(lines, "\n")
end

function StatsPatterns:thisYear(bookmory_books)
    return self:overview(bookmory_books)
end

function StatsPatterns:monthlyReading(bookmory_books)
    local sessions=unified_sessions(); if #sessions==0 then return "No unified history yet.\n\nRun Sync Unified History first." end
    local year=tonumber(os.date("%Y")); local m={}; for i=1,12 do m[i]=0 end
    local maxv=0
    for _,s in ipairs(sessions) do
        if tonumber(os.date("%Y",s.start_time))==year then local mo=tonumber(os.date("%m",s.start_time)); m[mo]=m[mo]+s.duration; maxv=math.max(maxv,m[mo]) end
    end
    local lines={tostring(year),""}
    for i=1,12 do table.insert(lines,string.format("%s  %s  %s",MONTHS[i],bar(m[i],maxv,14),human(m[i]))) end
    return table.concat(lines,"\n")
end

function StatsPatterns:readingFormats(bookmory_books)
    local sessions = read_unified_sessions()

    if #sessions == 0 then
        return
            "No unified history yet.

"
            .. "Run Sync Unified History first."
    end

    local totals = {}
    local total = 0

    for _, s in ipairs(sessions) do
        totals[s.medium] =
            (totals[s.medium] or 0)
            + s.duration

        total = total + s.duration
    end

    local order = {
        "Kindle",
        "Audiobook",
        "External/Hybrid",
    }

    local lines = {}

    for _, medium in ipairs(order) do
        local seconds = totals[medium] or 0
        local pct =
            total > 0
            and (seconds / total * 100)
            or 0

        table.insert(
            lines,
            string.format(
                "%-16s %5.1f%%  %s",
                medium,
                pct,
                human_time(seconds)
            )
        )

        table.insert(
            lines,
            bar(seconds, total, 16)
        )

        table.insert(lines, "")
    end

    return table.concat(lines, "
")
end

function StatsPatterns:ratings(bookmory_books)
    local dist={}; for r=0.5,5,0.5 do dist[r]=0 end
    local count,total=0,0
    for _,book in ipairs(bookmory_books or {}) do
        local r=latest_rating(book)
        if r then r=math.floor(r*2+0.5)/2; if dist[r]~=nil then dist[r]=dist[r]+1 end; count=count+1; total=total+r end
    end
    if count==0 then return "No ratings were found in the Bookmory backup." end
    local maxv=0; for _,v in pairs(dist) do maxv=math.max(maxv,v) end
    local lines={string.format("Rated books: %d",count),string.format("Average rating: %.2f★",total/count),""}
    for r=5,0.5,-0.5 do table.insert(lines,string.format("%3.1f★  %s  %d",r,bar(dist[r] or 0,maxv,12),dist[r] or 0)) end
    return table.concat(lines,"\n")
end

function StatsPatterns:authorsAndGenres(bookmory_books)
    local astats,tstats={},{}
    for _,book in ipairs(bookmory_books or {}) do
        local r=latest_rating(book)
        if r then
            for _,a in ipairs(authors_for(book)) do local k=normalize(a); if k~="" then local s=astats[k] or {label=a,count=0,total=0}; s.count=s.count+1; s.total=s.total+r; astats[k]=s end end
            for _,t in ipairs(tags_for(book)) do local k=normalize(t); if k~="" then local s=tstats[k] or {label=t,count=0,total=0}; s.count=s.count+1; s.total=s.total+r; tstats[k]=s end end
        end
    end
    local authors,tags={},{}
    for _,s in pairs(astats) do if s.count>=2 then s.avg=s.total/s.count; table.insert(authors,s) end end
    for _,s in pairs(tstats) do if s.count>=3 then s.avg=s.total/s.count; table.insert(tags,s) end end
    table.sort(authors,function(a,b) if a.avg==b.avg then return a.count>b.count end return a.avg>b.avg end)
    table.sort(tags,function(a,b) if a.avg==b.avg then return a.count>b.count end return a.avg>b.avg end)
    local lines={"TOP REPEAT AUTHORS"}
    for i=1,math.min(5,#authors) do local x=authors[i]; table.insert(lines,string.format("%d. %s  %.2f★ (%d)",i,x.label,x.avg,x.count)) end
    table.insert(lines,""); table.insert(lines,"HIGHEST-RATED RECURRING TAGS")
    for i=1,math.min(7,#tags) do local x=tags[i]; table.insert(lines,string.format("%d. %s  %.2f★ (%d)",i,x.label,x.avg,x.count)) end
    return table.concat(lines,"\n")
end

function StatsPatterns:readingHabits(bookmory_books)
    local sessions=unified_sessions(); if #sessions==0 then return "No unified history yet.\n\nRun Sync Unified History first." end
    local wd={}; for i=1,7 do wd[i]=0 end
    local parts={Morning=0,Afternoon=0,Evening=0,["Late night"]=0}; local total=0
    for _,s in ipairs(sessions) do
        local w=tonumber(os.date("%w",s.start_time))+1; wd[w]=wd[w]+s.duration
        local h=tonumber(os.date("%H",s.start_time)); local p=(h>=5 and h<12) and "Morning" or (h>=12 and h<17) and "Afternoon" or (h>=17 and h<22) and "Evening" or "Late night"
        parts[p]=parts[p]+s.duration; total=total+s.duration
    end
    local maxw=0; for i=1,7 do maxw=math.max(maxw,wd[i]) end
    local lines={"BY DAY OF WEEK"}; for i=1,7 do table.insert(lines,string.format("%s  %s  %s",WEEKDAYS[i],bar(wd[i],maxw,10),human(wd[i]))) end
    table.insert(lines,""); table.insert(lines,"BY TIME OF DAY"); local maxp=math.max(parts.Morning,parts.Afternoon,parts.Evening,parts["Late night"])
    for _,p in ipairs({"Morning","Afternoon","Evening","Late night"}) do table.insert(lines,string.format("%-10s %s  %s",p,bar(parts[p],maxp,10),human(parts[p]))) end
    table.insert(lines,""); table.insert(lines,"Average session: "..human(total/#sessions))
    return table.concat(lines,"\n")
end

local function tag_patterns(books)
    local stats={}
    for _,book in ipairs(books or {}) do
        local r=latest_rating(book)
        if r then for _,t in ipairs(tags_for(book)) do local k=normalize(t); if k~="" then local s=stats[k] or {label=t,ratings={}}; table.insert(s.ratings,r); stats[k]=s end end end
    end
    local reliable,unpredictable
    for _,s in pairs(stats) do
        if #s.ratings>=4 then
            local sum=0; for _,v in ipairs(s.ratings) do sum=sum+v end; s.mean=sum/#s.ratings
            local var=0; for _,v in ipairs(s.ratings) do var=var+(v-s.mean)^2 end; s.variance=var/#s.ratings
            if s.mean>=4 and (not reliable or s.mean>reliable.mean or (s.mean==reliable.mean and #s.ratings>#reliable.ratings)) then reliable=s end
            if not unpredictable or s.variance>unpredictable.variance then unpredictable=s end
        end
    end
    return reliable,unpredictable
end

local function timing_patterns(books)
    local fastest,comeback
    for _,book in ipairs(books or {}) do
        local ss=bookmory_sessions(book); local r=latest_rating(book)
        if #ss>=2 then
            local spanv=(ss[#ss].start_time+ss[#ss].duration)-ss[1].start_time
            if r and r>=4.5 and #ss>=3 and (not fastest or spanv<fastest.span) then fastest={title=book.title or "Unknown title",span=spanv,rating=r} end
            local gap=0; for i=2,#ss do local prev=ss[i-1].start_time+ss[i-1].duration; gap=math.max(gap,ss[i].start_time-prev) end
            if gap>=7*86400 and (not comeback or gap>comeback.gap) then comeback={title=book.title or "Unknown title",gap=gap} end
        end
    end
    return fastest,comeback
end

function StatsPatterns:interestingPatterns(bookmory_books)
    local lines={}; local sessions=unified_sessions()
    if #sessions>0 then
        local wd={0,0,0,0,0,0,0}; for _,s in ipairs(sessions) do local w=tonumber(os.date("%w",s.start_time))+1; wd[w]=wd[w]+s.duration end
        local best=1; for i=2,7 do if wd[i]>wd[best] then best=i end end
        if wd[best]>0 then table.insert(lines,"• "..WEEKDAYS[best].." is your biggest reading day, with "..human(wd[best]).." logged overall.") end
    end
    local reliable,unpredictable=tag_patterns(bookmory_books)
    if reliable then table.insert(lines,"• "..reliable.label.." is one of your most reliable recurring tags: "..string.format("%.2f★ average across %d rated books.",reliable.mean,#reliable.ratings)) end
    if unpredictable and unpredictable.variance>=0.35 then table.insert(lines,"• "..unpredictable.label.." is especially unpredictable for you: your ratings vary widely across "..#unpredictable.ratings.." books.") end
    local fastest,comeback=timing_patterns(bookmory_books)
    if fastest then table.insert(lines,"• Fastest obsession: "..fastest.title.." — "..span(fastest.span).." from first to last logged session, rated "..string.format("%.1f★.",fastest.rating)) end
    if comeback then table.insert(lines,"• Biggest comeback: "..comeback.title.." — you returned after a "..span(comeback.gap).." break.") end
    if #lines==0 then return "Not enough evidence yet for reliable pattern observations." end
    return table.concat(lines,"\n\n")
end

function StatsPatterns:readingRecords(bookmory_books)
    local sessions=unified_sessions(); if #sessions==0 then return "No unified history yet.\n\nRun Sync Unified History first." end
    local longest,daily,books=nil,{},{}
    for _,s in ipairs(sessions) do
        if not longest or s.duration>longest.duration then longest=s end
        local d=os.date("%Y-%m-%d",s.start_time); daily[d]=(daily[d] or 0)+s.duration
        local k=normalize(s.title); if k~="" then local b=books[k] or {title=s.title,duration=0}; b.duration=b.duration+s.duration; books[k]=b end
    end
    local bestday,bestsec=nil,0; for d,sec in pairs(daily) do if sec>bestsec then bestday,bestsec=d,sec end end
    local most; for _,b in pairs(books) do if not most or b.duration>most.duration then most=b end end
    local lines={}
    if longest then table.insert(lines,"LONGEST SESSION\n"..longest.title.."\n"..longest.medium.." • "..human(longest.duration).."\n"..os.date("%b %d, %Y",longest.start_time)) end
    if bestday then table.insert(lines,"MOST INTENSE READING DAY\n"..bestday.."\n"..human(bestsec)) end
    if most then table.insert(lines,"MOST LOGGED READING TIME\n"..most.title.."\n"..human(most.duration)) end
    return table.concat(lines,"\n\n────────────────────\n\n")
end

return StatsPatterns
