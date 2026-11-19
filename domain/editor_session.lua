-- Document and pane-view ownership. No fonts, shared UI, timers or saved state
-- are acquired here; the controller schedules work for an explicit session.
local Buffer=require('domain.buffer')
local Docs=require('domain.documents')
local M={}

function M.new(name,text,base,dirty,time,slot)
  if not Docs.name_ok(name) then return nil,'Unsupported filename' end
  if base~=nil and (not Buffer.valid(base) or #base>Buffer.MAX) then return nil,'Invalid saved base' end
  local key,e=Docs.recovery_key(slot);if not key then return nil,e end
  local buffer,err=Buffer.new(text);if not buffer then return nil,err end
  return {doc={name=name,base=base},buffer=buffer,recovery_slot=slot,
    top=0,rows={},dirty=dirty==true,save_failed=false,
    status=dirty and 'Unsaved' or 'Saved on SD card',
    first_dirty=time or 0,last_edit=time or 0,layout_dirty_from=0,browsing=false}
end

function M.selection(s)
  local p=s.buffer.pos;local a=s.anchor or p
  return math.min(a,p),math.max(a,p)
end

function M.changed(s,time,from)
  s.goal_x=nil
  if not s.dirty then s.first_dirty=time end
  s.dirty=true;s.last_edit=time;s.save_failed=false
  s.layout_dirty_from=math.min(s.layout_dirty_from or s.buffer.size,from or 0)
end

function M.save(ctx,s,reserved)
  s.recovery_doc=nil;s.recovery_revision=nil;s.recovery_name=nil
  local ok,e=Docs.save(ctx,s.doc,s.buffer:text(),s.recovery_slot,reserved)
  if not ok then return nil,e end
  s.dirty=false;s.save_failed=false;s.status='Saved on SD card'
  return true
end

function M.checkpoint(ctx,s)
  -- A rename can change the filename without changing the buffer revision.
  if s.recovery_doc==s.doc and s.recovery_revision==s.buffer.revision
    and s.recovery_name==s.doc.name then return true end
  local ok,result,err=pcall(function()
    return Docs.recovery(ctx,s.doc.name,s.buffer:text(),s.recovery_slot)
  end)
  if not ok then return nil,tostring(result) end
  if not result then return nil,err end
  s.recovery_doc=s.doc;s.recovery_revision=s.buffer.revision;s.recovery_name=s.doc.name
  return true
end

function M.snapshot(ctx,s)
  if s.dirty or s.doc.base==nil then return nil end
  local bytes=s.buffer:text()
  if bytes~=s.doc.base or Docs.read(ctx,s.doc.name)~=bytes then return nil end
  return {identity=s.doc,name=s.doc.name,revision=s.buffer.revision,bytes=bytes,saved=true,exists=true}
end
return M
