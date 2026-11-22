local Buffer=require("domain.buffer")
local M={}
-- All host calls can return nil/error or raise an allocation exception.
local function call(obj,method,...)
  local ok,a,b=pcall(obj[method],obj,...)
  if not ok then return nil,tostring(a) end
  return a,b
end
M.call=call
-- nil preserves the released single-document format. Explicit slots are for
-- the two workspace sessions; callers cannot select arbitrary private files.
function M.recovery_key(slot)
  if slot==nil then return 'recovery.txt' end
  if slot==1 then return 'recovery-a.txt' end
  if slot==2 then return 'recovery-b.txt' end
  return nil,'Invalid recovery slot'
end
local function reserved_name(name,reserved)
  if type(reserved)=='string' then return name:lower()==reserved:lower() end
  if type(reserved)=='table' then
    for i=1,2 do
      if type(reserved[i])=='string' and name:lower()==reserved[i]:lower() then return true end
    end
  end
  return false
end
function M.name_ok(n)
  if type(n)~="string" or #n==0 or #n>128 or not utf8.len(n) then return false end
  if n:sub(1,1)=="." or n:sub(-1)=="." or n:sub(-1)==" " then return false end
  if n:find('[%z\1-\31\127/\\:*?"<>|~]') then return false end
  local stem=n:match("^([^.]*)"):upper()
  if stem=="CON" or stem=="PRN" or stem=="AUX" or stem=="NUL" or stem:match("^COM[1-9]$") or stem:match("^LPT[1-9]$") then return false end
  local lower=n:lower()
  return lower:sub(-3)==".md" or lower:sub(-4)==".txt"
end
function M.missing(ctx,name)
  if not ctx.files then return false end
  local size,err=call(ctx.files,"size",name)
  return size==nil and err=="not_found"
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
function M.fresh_name(ctx,prefix,extension,reserved)
  extension=extension or ".md"
  if extension~=".md" and extension~=".txt" then return nil,"Unsupported extension" end
  for i=1,512 do
    local name=prefix..string.format("-%03d",i)..extension
    local n,e=call(ctx.files,"size",name)
    if n==nil and e=="not_found" and not reserved_name(name,reserved)then return name end
    if n==nil and e=="not_found" then e=false end
    if n==nil and e then return nil,e end
  end
  return nil,"No free filename; move older files off the SD card"
end
function M.recovery(ctx,name,text,slot)
  local key,e=M.recovery_key(slot);if not key then return nil,e end
  if not M.name_ok(name) or not Buffer.valid(text) or #text>Buffer.MAX then return nil,"Invalid recovery" end
  return call(ctx.storage,"write",key,"INKWRITE1\n"..name.."\n"..text)
end
function M.load_recovery(ctx,slot)
  local key,e=M.recovery_key(slot);if not key then return nil,e end
  local s,e=call(ctx.storage,"read",key)
  if not s then if e=="not_found" then return false end; return nil,e end
  if type(s)~='string' or #s>Buffer.MAX+140 then return nil,"Unreadable recovery; kept untouched" end
  local name,text=s:match("^INKWRITE1\n([^\n]+)\n(.*)$")
  if not name or not M.name_ok(name) or not Buffer.valid(text) or #text>Buffer.MAX then return nil,"Unreadable recovery; kept untouched" end
  return {name=name,text=text}
end
-- Migration is opt-in until the workspace startup can recover both slots.
-- Copy/read-verify first; interrupted cleanup leaves two recoverable copies.
function M.migrate_recovery(ctx,slot)
  if slot~=1 and slot~=2 then return nil,'Invalid recovery slot' end
  local legacy,e=M.load_recovery(ctx);if legacy==nil then return nil,e end
  local target,err=M.load_recovery(ctx,slot);if target==nil then return nil,err end
  if not legacy then return target end
  if target and (target.name~=legacy.name or target.text~=legacy.text) then return nil,'Recovery slot already occupied' end
  if not target then
    local ok,why=M.recovery(ctx,legacy.name,legacy.text,slot);if not ok then return nil,why end
    target,err=M.load_recovery(ctx,slot)
    if not target or target.name~=legacy.name or target.text~=legacy.text then return nil,err or 'Recovery migration verification failed' end
  end
  local current,why=M.load_recovery(ctx)
  if not current or current.name~=legacy.name or current.text~=legacy.text then return nil,why or 'Recovery changed during migration' end
  local ok,why=call(ctx.storage,'remove','recovery.txt');if not ok then return nil,why end
  return target
end
function M.save(ctx,doc,text,slot,reserved)
  local key,e=M.recovery_key(slot);if not key then return nil,e end
  -- Recovery is committed first. Never overwrite external changes.
  local ok,e=M.recovery(ctx,doc.name,text,slot)
  if not ok then return nil,"Recovery: "..tostring(e) end
  local current,err=M.read(ctx,doc.name)
  if not current and err~="not_found" then return nil,"Check file: "..tostring(err) end
  if current~=doc.base then
    local copy,ce=M.fresh_name(ctx,"conflict",nil,reserved)
    if not copy then return nil,ce end
    doc.name=copy; doc.base=nil
    ok,e=M.recovery(ctx,doc.name,text,slot)
    if not ok then return nil,"Recovery: "..tostring(e) end
  end
  ok,e=call(ctx.files,"write",doc.name,text)
  if not ok then return nil,"SD save: "..tostring(e) end
  doc.base=text
  -- A stale matching recovery is harmless and removed again on startup.
  call(ctx.storage,"remove",key)
  return true
end
-- Remote import never replaces the active document or touches its recovery.
function M.import_copy(ctx,name,text,reserved)
  if not M.name_ok(name)or name:find('..',1,true)or not Buffer.valid(text)or #text>Buffer.MAX then return nil,'invalid_import'end
  local size,err=call(ctx.files,'size',name)
  if size==nil and err~='not_found'then return nil,'import_check_failed'end
  local target=name
  if size~=nil or reserved_name(name,reserved)then
    target,err=M.fresh_name(ctx,'download',name:lower():sub(-4)=='.txt'and '.txt'or '.md',reserved)
    if not target then return nil,'import_name_failed'end
  end
  -- Recheck immediately before writing. The host has no exclusive-create/CAS.
  size,err=call(ctx.files,'size',target)
  if size~=nil or err~='not_found'then return nil,'import_destination_changed'end
  local ok=call(ctx.files,'write',target,text)
  if not ok then return nil,'import_write_failed'end
  local verified=M.read(ctx,target)
  if verified~=text then return nil,'import_verify_failed',target end
  return target
end
-- Explicit remote-only update. Keep a verified public backup and recovery first.
-- The host offers atomic writes, but no compare-and-swap against external writers.
function M.update_from_remote(ctx,name,old,text,slot,reserved)
  if not M.name_ok(name)or name:find('..',1,true)or not Buffer.valid(old)or not Buffer.valid(text)
    or #old>Buffer.MAX or #text>Buffer.MAX then return nil,'invalid_update'end
  local current=M.read(ctx,name)
  if current~=old then return nil,'local_changed'end
  local rec=M.load_recovery(ctx,slot)
  if rec==nil or (rec and (rec.name:lower()~=name:lower()or rec.text~=old))then return nil,'recovery_protected'end
  local target=M.fresh_name(ctx,'before-sync',name:lower():sub(-4)=='.txt'and '.txt'or '.md',reserved or name)
  if not target then return nil,'backup_failed'end
  local backup=M.import_copy(ctx,target,old,reserved or name)
  if not backup then return nil,'backup_failed'end
  if not M.recovery(ctx,name,old,slot)then return nil,'recovery_write_failed',backup end
  if M.read(ctx,name)~=old then return nil,'local_changed',backup end
  if not call(ctx.files,'write',name,text)then return nil,'update_write_failed',backup end
  if M.read(ctx,name)~=text then return nil,'update_verify_failed',backup end
  return backup
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
