-- Two bounded session slots. The controller owns shared UI and cancels its
-- outgoing timers before publishing a successful activation.
local Session=require('domain.editor_session')
local Docs=require('domain.documents')
local M={}
local function slot_ok(slot)return slot==1 or slot==2 end
function M.new()
  return {sessions={},active=1,direction='horizontal',direction_auto=true,ratio='1:1',split=false}
end
function M.effective_direction(w,screen)
  if w.direction_auto then return screen.width>screen.height and 'vertical'or 'horizontal'end
  return w.direction
end
function M.find(w,name)
  if type(name)~='string' then return nil end
  for i=1,2 do local s=w.sessions[i]
    if s and s.doc.name:lower()==name:lower() then return i end
  end
end
function M.put(w,slot,session)
  if not slot_ok(slot) or type(session)~='table' or type(session.doc)~='table'
    or type(session.doc.name)~='string' or type(session.buffer)~='table'
    or session.recovery_slot~=slot then return nil,'Invalid session slot' end
  local existing=M.find(w,session.doc.name)
  if existing and existing~=slot then return nil,'Document already open',existing end
  local old=w.sessions[slot]
  if old and old~=session and old.dirty then return nil,'Save the document before replacing it' end
  w.sessions[slot]=session
  return true
end
function M.reserved_names(w)
  local names={}
  for i=1,2 do local s=w.sessions[i];if s then names[#names+1]=s.doc.name end end
  return names
end
function M.activate(ctx,w,slot)
  if not slot_ok(slot) or not w.sessions[slot] then return nil,'Pane has no document' end
  if slot==w.active then return true end
  local outgoing=w.sessions[w.active]
  if outgoing and outgoing.dirty then
    local ok,e=Session.checkpoint(ctx,outgoing)
    if not ok then return nil,e end
  end
  w.active=slot
  return true
end
function M.dirty(w)
  for i=1,2 do local s=w.sessions[i];if s and s.dirty then return true end end
  return false
end
function M.auto_blocked(w)
  for i=1,2 do local s=w.sessions[i];if s and (s.dirty or s.save_failed)then return true end end
  return false
end
function M.remember(ctx,w)
  if not w.slotted then return end
  local value={schema=1,active=w.active,split=w.split,direction=w.direction,direction_auto=w.direction_auto,ratio=w.ratio,sessions={}}
  for i=1,2 do local s=w.sessions[i]
    if s then value.sessions[i]={name=s.doc.name,cursor=s.buffer.pos,top=s.top}end
  end
  ctx.state.inkwrite_workspace=value
end
local function integer(v)return type(v)=='number'and v==v and v>=0 and v<=32768 and v%1==0 end
local function settings(ctx)
  local v=ctx.state.inkwrite_workspace
  if v==nil then return false end
  if type(v)~='table'or v.schema~=1 or not slot_ok(v.active)or type(v.split)~='boolean'
    or (v.direction~='horizontal'and v.direction~='vertical')
    or (v.direction_auto~=nil and type(v.direction_auto)~='boolean')
    or (v.ratio~='1:1'and v.ratio~='2:1'and v.ratio~='1:2')or type(v.sessions)~='table'then return nil,'Workspace settings protected'end
  local names={};local count=0
  for k,r in pairs(v.sessions)do
    count=count+1
    if count>2 or not slot_ok(k)or type(r)~='table'or not Docs.name_ok(r.name)
      or not integer(r.cursor)or not integer(r.top)or names[r.name:lower()]then return nil,'Workspace documents protected'end
    names[r.name:lower()]=true
  end
  if not v.sessions[v.active]then return nil,'Workspace active pane protected'end
  return v
end
function M.restore(ctx,time)
  local v,e=settings(ctx);if v==nil then return nil,e end
  local recs={}
  for i=1,2 do local rec,err=Docs.load_recovery(ctx,i)
    if rec==nil then return nil,'Pane recovery protected: '..tostring(err)end
    recs[i]=rec
  end
  if not v and not recs[1]and not recs[2]then return false end
  local legacy,err=Docs.load_recovery(ctx);if legacy==nil then return nil,err end
  if legacy then
    local migrated,why=Docs.migrate_recovery(ctx,1);if not migrated then return nil,why end
    recs[1]=migrated
  end
  local w=M.new();w.slotted=true
  if v then
    w.active=v.active;w.split=v.split;w.direction=v.direction;w.ratio=v.ratio
    -- Auto is also the default for older settings without a saved policy.
    w.direction_auto=v.direction_auto~=false
  end
  local names={}
  for i=1,2 do names[i]=recs[i]and recs[i].name or v and v.sessions[i]and v.sessions[i].name end
  if names[1]and names[2]and names[1]:lower()==names[2]:lower()then return nil,'Duplicate pane recovery protected'end
  local notice
  for i=1,2 do
    local rec=recs[i];local name=names[i]
    if name then
      local text,why=Docs.read(ctx,name);local base=text;local dirty=false
      if not text and why~='not_found'and not (rec and tostring(why):find('32 KiB',1,true))then return nil,'Pane file protected: '..tostring(why)end
      if rec and rec.text==''and not text and why=='not_found'then
        text='';base=nil
      elseif rec and text~=rec.text then
        name,why=Docs.fresh_name(ctx,'recovered',name:lower():sub(-4)=='.txt'and '.txt'or '.md',names)
        if not name then return nil,why end
        text=rec.text;base=nil;dirty=true;notice='Recovered writing in a separate document.'
      elseif not text then
        name,why=Docs.fresh_name(ctx,'untitled',nil,names);if not name then return nil,why end
        text='';base=nil;notice='A previous pane file is missing; opened an empty page.'
      end
      names[i]=name
      local s,why=Session.new(name,text,base,dirty,time,i);if not s then return nil,why end
      local saved=v and v.sessions[i]
      if saved and saved.name==name then
        if s.buffer:is_boundary(saved.cursor)then s.buffer:seek(saved.cursor)end
        if s.buffer:is_boundary(saved.top)then s.top=saved.top end
      end
      if dirty then local ok,why=Session.checkpoint(ctx,s);if not ok then return nil,why end end
      w.sessions[i]=s
    end
  end
  if not w.sessions[w.active]then w.active=w.sessions[1]and 1 or 2 end
  if not w.sessions[w.active]then return nil,'Workspace has no recoverable document'end
  if w.split and (not w.sessions[1]or not w.sessions[2])then w.split=false end
  return w,notice
end
function M.enable(ctx,w,time)
  if not w.slotted then
    local s=w.sessions[w.active]
    local ok,e=Session.checkpoint(ctx,s);if not ok then return nil,e end
    local rec,why=Docs.migrate_recovery(ctx,1);if not rec then return nil,why end
    s.recovery_slot=1;s.recovery_doc=nil;s.recovery_revision=nil
    w.sessions={s};w.active=1;w.slotted=true
  end
  for i=1,2 do if not w.sessions[i]then
    local name,e=Docs.fresh_name(ctx,'untitled',nil,M.reserved_names(w));if not name then return nil,e end
    local s=assert(Session.new(name,'',nil,false,time,i))
    local ok,why=Session.checkpoint(ctx,s);if not ok then return nil,why end
    w.sessions[i]=s
  end end
  w.split=true;M.remember(ctx,w)
  return true
end
return M
