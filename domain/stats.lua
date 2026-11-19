local M={};local S={};S.__index=S
local FILE="writing-stats-v1.txt"
local function leap(y) return y%4==0 and (y%100~=0 or y%400==0) end
local function days(y,m) return ({31,leap(y) and 29 or 28,31,30,31,30,31,31,30,31,30,31})[m] end
local function ordinal(y,m,d)
  local n=365*(y-2000)
  for a=2000,y-1 do if leap(a) then n=n+1 end end
  for a=1,m-1 do n=n+days(y,a) end
  return n+d-1
end
local function date(ctx)
  local c=ctx.clock:now()
  if not c.valid or type(c.year)~="number" or type(c.month)~="number" or type(c.day)~="number" or c.year%1~=0 or c.month%1~=0 or c.day%1~=0 or c.year<2000 or c.year>2099 or c.month<1 or c.month>12 or c.day<1 or c.day>days(c.year,c.month) then return nil end
  return ordinal(c.year,c.month,c.day),c
end
function M.new(ctx)
  local s=setmetatable({history="",word=0,typing=0,app=0,last=ctx.clock:millis(),saved=ctx.clock:millis()},S)
  local ok,data,err=pcall(function() return ctx.storage:read(FILE) end)
  if not ok or (not data and err~="not_found") then s.error="Statistics unavailable";return s end
  if data then
    if #data>24000 or (#data>0 and (data:sub(-1)~="\n" or data:sub(1,1)=="\n" or data:find("\n\n",1,true))) then s.error="Statistics file protected";return s end
    local count,previous,offset,history_end=0,-1,0,0
    for line in data:gmatch("[^\n]+") do
      local d,w,t,a=line:match("^(%d+),(%d+),(%d+),(%d+)$")
      d,w,t,a=tonumber(d),tonumber(w),tonumber(t),tonumber(a)
      if not d or d>36600 or d<=previous or w>9999999 or t>86400000 or a>86400000 then s.error="Statistics file protected";return s end
      count=count+1;if count>400 then s.error="Statistics file protected";return s end
      if s.day then history_end=offset end
      offset=offset+#line+1
      s.day,s.word,s.typing,s.app=d,w,t,a;previous=d
    end
    s.history=data:sub(1,history_end)
  end
  s:tick(ctx);return s
end
function S:line() return self.day and self.day..","..self.word..","..self.typing..","..self.app.."\n" or "" end
function S:flush(ctx)
  if self.error or not self.dirty or not self.day then return end
  local ok,result=pcall(function() return ctx.storage:write(FILE,self.history..self:line()) end)
  self.save_error=not ok or not result
  if not self.save_error then self.dirty=false end
  -- One attempt per interval: a failed write is retried a minute later, not on
  -- every tick.
  self.due=false
  self.saved=ctx.clock:millis()
end
function S:tick(ctx,allow_flush)
  local now=ctx.clock:millis();local day=date(ctx)
  local delta=self.last and ((now-self.last)&0x7fffffff) or 0;self.last=now
  if self.error or not day or (self.day and day<self.day) then self.active=nil;return end
  if self.day~=day then
    if self.day then self.history=self.history..self:line() end
    local rows=0;for _ in self.history:gmatch("\n") do rows=rows+1 end
    while rows>=400 do self.history=self.history:sub((self.history:find("\n",1,true) or 0)+1);rows=rows-1 end
    self.day,self.word,self.typing,self.app=day,0,0,0;delta=0;self.active=nil
  end
  if delta>60000 then delta=0;self.active=nil end
  if delta>0 then
    self.app=math.min(86400000,self.app+delta)
    if self.active then
      local idle=(now-self.active)&0x7fffffff
      local active=math.max(0,delta-math.max(0,idle-30000))
      self.typing=math.min(86400000,self.typing+active)
    end
    self.dirty=true
  end
  -- Never write the file from a keystroke: an edit only marks the checkpoint
  -- as due. The idle tick or pause/exit performs the write.
  if self.dirty and ((now-self.saved)&0x7fffffff)>=60000 then self.due=true end
  if self.due and allow_flush then self:flush(ctx) end
end
function S:edit(ctx,words)
  self:tick(ctx)
  local day=date(ctx);if self.error or day~=self.day then return end
  self.active=ctx.clock:millis();self.word=math.min(9999999,self.word+math.max(0,words));self.dirty=true
end
function S:pause(ctx) self:tick(ctx,true);self:flush(ctx);self.last=nil;self.active=nil end
function S:resume(ctx) self.last=ctx.clock:millis();self.active=nil end
function S:report(ctx,mode)
  local day,c=date(ctx);if not day then return nil,"Set the device date to record statistics" end
  local start,count,elapsed,title
  if mode==1 then local weekday=(day+5)%7;start=day-weekday;count=7;elapsed=weekday+1;title="This week (Mon-Sun)"
  elseif mode==2 then start=ordinal(c.year,c.month,1);count=days(c.year,c.month);elapsed=c.day;title=string.format("%04d-%02d",c.year,c.month)
  else start=ordinal(c.year,1,1);count=12;elapsed=day-start+1;title=tostring(c.year) end
  local r={bins={},words=0,typing=0,app=0,title=title,count=count,elapsed=elapsed}
  for i=1,count do r.bins[i]=0 end
  local function add(d,w,t,a)
    if d<start or d>day then return end
    local i=d-start+1
    if mode==3 then i=1;local left=d-start;while left>=days(c.year,i) and i<12 do left=left-days(c.year,i);i=i+1 end end
    if i>count then return end
    local seconds=t//1000;r.bins[i]=r.bins[i]+seconds;r.words=r.words+w;r.typing=r.typing+seconds;r.app=r.app+a//1000
  end
  for d,w,t,a in self.history:gmatch("(%d+),(%d+),(%d+),(%d+)\n") do add(tonumber(d),tonumber(w),tonumber(t),tonumber(a)) end
  if self.day then add(self.day,self.word,self.typing,self.app) end
  r.average=r.typing//elapsed;return r
end
function M.duration(seconds)
  if seconds<60 then return tostring(seconds).."s" end
  if seconds<3600 then return tostring(seconds//60).."m "..tostring(seconds%60).."s" end
  return string.format("%dh %02dm",seconds//3600,(seconds%3600)//60)
end
return M
