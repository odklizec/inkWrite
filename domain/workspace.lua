-- Two bounded session slots. The controller owns shared UI and cancels its
-- outgoing timers before publishing a successful activation.
local Session=require('domain.editor_session')
local M={}
local function slot_ok(slot)return slot==1 or slot==2 end
function M.new()
  return {sessions={},active=1,direction='horizontal',ratio='1:1',split=false}
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
return M
