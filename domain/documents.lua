local Buffer=require("domain.buffer")
local M={}
-- All host calls can return nil/error or raise an allocation exception.
local function call(obj,method,...)
  local ok,a,b=pcall(obj[method],obj,...)
  if not ok then return nil,tostring(a) end
  return a,b
end
M.call=call
function M.name_ok(n)
  if type(n)~="string" or #n==0 or #n>128 or not utf8.len(n) then return false end
  if n:sub(1,1)=="." or n:sub(-1)=="." or n:sub(-1)==" " then return false end
  if n:find('[%z\1-\31\127/\\:*?"<>|~]') then return false end
  local stem=n:match("^([^.]*)"):upper()
  if stem=="CON" or stem=="PRN" or stem=="AUX" or stem=="NUL" or stem:match("^COM[1-9]$") or stem:match("^LPT[1-9]$") then return false end
  local lower=n:lower()
  return lower:sub(-3)==".md" or lower:sub(-4)==".txt"
end
function M.read(ctx,name)
  if not M.name_ok(name) then return nil,"Unsupported filename" end
  local n,e=call(ctx.files,"size",name); if n==nil then return nil,e end
  if n>Buffer.MAX then return nil,"Read-only: file exceeds 32 KiB; original preserved" end
  -- The extra byte detects growth between size() and read().
  local s,err=call(ctx.files,"read",name,0,Buffer.MAX+1)
  if not s then return nil,err end
  if #s>Buffer.MAX then return nil,"File grew beyond 32 KiB" end
  if not Buffer.valid(s) then return nil,"Invalid UTF-8 or zero byte; original preserved" end
  return s
end
function M.fresh_name(ctx,prefix,extension)
  extension=extension or ".md"
  if extension~=".md" and extension~=".txt" then return nil,"Unsupported extension" end
  for i=1,512 do
    local name=prefix..string.format("-%03d",i)..extension
    local n,e=call(ctx.files,"size",name)
    if n==nil and e=="not_found" then return name end
    if n==nil then return nil,e end
  end
  return nil,"No free filename; move older files off the SD card"
end
function M.recovery(ctx,name,text)
  if not M.name_ok(name) or not Buffer.valid(text) or #text>Buffer.MAX then return nil,"Invalid recovery" end
  return call(ctx.storage,"write","recovery.txt","INKWRITE1\n"..name.."\n"..text)
end
function M.load_recovery(ctx)
  local s,e=call(ctx.storage,"read","recovery.txt")
  if not s then if e=="not_found" then return false end; return nil,e end
  local name,text=s:match("^INKWRITE1\n([^\n]+)\n(.*)$")
  if not name or not M.name_ok(name) or not Buffer.valid(text) or #text>Buffer.MAX then return nil,"Unreadable recovery; kept untouched" end
  return {name=name,text=text}
end
function M.save(ctx,doc,text)
  -- Recovery is committed first. Never overwrite external changes.
  local ok,e=M.recovery(ctx,doc.name,text)
  if not ok then return nil,"Recovery: "..tostring(e) end
  local current,err=M.read(ctx,doc.name)
  if not current and err~="not_found" then return nil,"Check file: "..tostring(err) end
  if current~=doc.base then
    local copy,ce=M.fresh_name(ctx,"conflict")
    if not copy then return nil,ce end
    doc.name=copy; doc.base=nil
    ok,e=M.recovery(ctx,doc.name,text)
    if not ok then return nil,"Recovery: "..tostring(e) end
  end
  ok,e=call(ctx.files,"write",doc.name,text)
  if not ok then return nil,"SD save: "..tostring(e) end
  doc.base=text
  -- A stale matching recovery is harmless and removed again on startup.
  call(ctx.storage,"remove","recovery.txt")
  return true
end
-- No native rename exists. Copy and compare in 1 KiB timer slices, then remove.
-- An interrupted/failed copy leaves the source intact, possibly alongside a copy.
function M.rename(ctx,old,new,done)
  if not M.name_ok(old) or not M.name_ok(new) then return nil,"Use a valid .md or .txt filename" end
  if old:lower()==new:lower() then return nil,"Choose a different filename (case-only changes are unsupported)" end
  local n,e=call(ctx.files,"size",old);if n==nil then return nil,e end
  local exists,err=call(ctx.files,"size",new)
  if exists~=nil then return nil,"That filename already exists" end
  if err~="not_found" then return nil,err end
  local job={offset=0,phase="copy",created=false,cancelled=false}
  local function fail(error) job.finished=true;done(ctx,false,tostring(error)..(job.created and "; original kept; check the new copy" or "")) end
  local function step(c)
    if job.cancelled then return end
    local size,se=call(c.files,"size",old)
    if size~=n then fail(se or "Source changed during rename");return end
    if not job.created then
      local size,er=call(c.files,"size",new)
      if size~=nil or er~="not_found" then fail(er or "Destination already exists");return end
      local ok,we=call(c.files,"write",new,"");if not ok then fail(we);return end
      job.created=true
    elseif job.offset<n then
      local length=math.min(1024,n-job.offset)
      local data,re=call(c.files,"read",old,job.offset,length)
      if not data or #data~=length then fail(re or "Source changed during rename");return end
      if job.phase=="copy" then
        local ok,we=call(c.files,"append",new,data);if not ok then fail(we);return end
      else
        local copy,ce=call(c.files,"read",new,job.offset,length)
        if copy~=data then fail(ce or "Rename verification failed");return end
      end
      job.offset=job.offset+length
    elseif job.phase=="copy" then
      job.phase="verify";job.offset=0
    else
      local size,er=call(c.files,"size",new)
      if size~=n then fail(er or "Copy size changed");return end
      local ok,de=call(c.files,"remove",old)
      if not ok then fail(de);return end
      job.finished=true;done(c,true);return
    end
    job.timer=c:after(1,step)
    if not job.timer then fail("Rename scheduling failed") end
  end
  job.timer=ctx:after(1,step)
  if not job.timer then return nil,"Rename scheduling failed" end
  function job:cancel() self.cancelled=true;if self.timer then self.timer:cancel() end end
  return job
end
function M.list(ctx)
  local rows,e=call(ctx.files,"list")
  if not rows then return nil,e end
  local out={}
  for _,r in ipairs(rows) do if M.name_ok(r.name) then out[#out+1]={name=r.name,size=r.size} end end
  return out
end
return M
