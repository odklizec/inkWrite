local Session=require('domain.editor_session')
local Workspace=require('domain.workspace')
local Docs=require('domain.documents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function host()
  local h={private={},public={},writes=0,public_writes=0,ctx={storage={},files={}}}
  h.ctx.storage.read=function(_,k)
    if h.read_fail==k then return nil,'io_error' end
    local v=h.private[k];return v,v and nil or 'not_found'
  end
  h.ctx.storage.write=function(_,k,v)
    h.writes=h.writes+1
    if h.write_fail==k then return nil,'io_error' end
    h.private[k]=h.corrupt==k and 'broken' or v;return true
  end
  h.ctx.storage.remove=function(_,k)
    if h.remove_fail==k then return nil,'io_error' end
    h.private[k]=nil;return true
  end
  h.ctx.files.size=function(_,k)local v=h.public[k];return v and #v or nil,v and nil or 'not_found'end
  h.ctx.files.read=function(_,k,a,z)local v=h.public[k];return v and v:sub(a+1,a+z) or nil,v and nil or 'not_found'end
  h.ctx.files.write=function(_,k,v)
    if h.public_fail then return nil,'io_error' end
    h.public[k]=v;h.public_writes=h.public_writes+1;return true
  end
  return h
end
local text='Alpha čaj\r\n'
local a=assert(Session.new('alpha.md',text,text,false,1,1))
local b=assert(Session.new('beta.txt','Beta','Beta',false,1,2))
local h=host();h.public['alpha.md']=text;h.public['beta.txt']='Beta'
check(a.buffer~=b.buffer and a.rows~=b.rows and a.doc~=b.doc,'sessions own distinct buffers, views and identities')
local snapshot=assert(Session.snapshot(h.ctx,a))
check(snapshot.identity==a.doc and snapshot.bytes==text,'snapshot captures exact saved identity and bytes')
local bpos=b.buffer.pos
a.anchor=0;a.top=2;a.goal_x=30;a.buffer:replace(a.buffer.size,a.buffer.size,'new');Session.changed(a,20,0)
check(b.buffer:text()=='Beta' and b.buffer.pos==bpos and not b.dirty and b.anchor==nil and b.top==0,'edit and view changes stay in A')
check(Session.snapshot(h.ctx,a)==nil and Session.snapshot(h.ctx,b)~=nil,'dirty A does not prevent an explicit B snapshot')
check(a.buffer:undo_edit()==true and a.buffer:text()==text,'A owns its undo')
check(b.buffer:undo_edit()==false,'B never receives A undo entries')
local x,z=Session.selection(a);check(x==0 and z==#text,'selection uses the supplied session')
a.buffer:replace(a.buffer.size,a.buffer.size,'A edit');Session.changed(a,30,0)
b.buffer:replace(b.buffer.size,b.buffer.size,' B edit');Session.changed(b,40,0)
check(Session.checkpoint(h.ctx,a) and Session.checkpoint(h.ctx,b),'both dirty sessions checkpoint')
local saved_a=h.private['recovery-a.txt'];local saved_b=h.private['recovery-b.txt']
check(Docs.load_recovery(h.ctx,1).text==a.buffer:text() and Docs.load_recovery(h.ctx,2).text==b.buffer:text(),'each slot restores its exact bytes')
local writes=h.writes;check(Session.checkpoint(h.ctx,a) and h.writes==writes,'unchanged recovery is not rewritten')
check(Session.save(h.ctx,b),'saving B succeeds')
check(h.private['recovery-a.txt']==saved_a and h.private['recovery-b.txt']==nil,'saving B cannot remove A recovery')
check(a.dirty and not b.dirty and h.public['alpha.md']==text,'saving B leaves A dirty and its SD file unchanged')
h.public_fail=true
check(Session.save(h.ctx,a)==nil,'SD failure is reported')
check(a.dirty and a.doc.base==text and h.private['recovery-a.txt']==saved_a,'failed save retains A text, base and recovery')
h.public_fail=false;h.public['alpha.md']='External SD edit'
local reserved={'conflict-001.md',b.doc.name}
check(Session.save(h.ctx,a,reserved),'external change saves a conflict copy')
check(a.doc.name=='conflict-002.md' and h.public['alpha.md']=='External SD edit','conflict copy reserves another unsaved document name')
check(h.public[a.doc.name]==a.buffer:text() and b.buffer:text()=='Beta B edit','external-change save preserves both sessions')
check(h.private['recovery-a.txt']==nil,'successful A save clears only its recovery')
check(Session.checkpoint(h.ctx,a),'saved session may be explicitly checkpointed')
a.doc.name='renamed.md';writes=h.writes
check(Session.checkpoint(h.ctx,a) and h.writes==writes+1 and Docs.load_recovery(h.ctx,1).name=='renamed.md','same-revision rename refreshes recovery name')
-- Invalid slot selection must never fall back to the released recovery file.
h.private['recovery.txt']='legacy sentinel';writes=h.writes
for _,slot in ipairs({0,3,'1',false,math.huge})do
  check(Docs.recovery(h.ctx,'alpha.md','x',slot)==nil,'invalid recovery slot refused')
  check(Docs.load_recovery(h.ctx,slot)==nil,'invalid read slot refused')
end
check(h.writes==writes and h.private['recovery.txt']=='legacy sentinel','invalid slots perform no writes')
-- Workspace activation checkpoints the outgoing document; it never saves it publicly.
h=host();a=assert(Session.new('a.md','A',nil,true,0,1));b=assert(Session.new('b.md','B',nil,true,0,2))
local w=Workspace.new();check(Workspace.put(w,1,a) and Workspace.put(w,2,b),'two sessions attach to their own slots')
h.write_fail='recovery-a.txt'
check(Workspace.activate(h.ctx,w,2)==nil and w.active==1,'failed outgoing checkpoint keeps A active')
h.write_fail=nil
check(Workspace.activate(h.ctx,w,2) and w.active==2 and h.public_writes==0,'switch checkpoints without public Save')
check(Docs.load_recovery(h.ctx,1).text=='A','inactive A has durable recovery')
local alias=assert(Session.new('A.MD','alias',nil,true,0,2))
local ok,err,existing=Workspace.put(w,2,alias)
check(not ok and existing==1 and w.sessions[2]==b,'case alias activates existing document rather than creating two writers')
check(Workspace.put(w,1,assert(Session.new('new.md','new',nil,true,0,1)))==nil and w.sessions[1]==a,'dirty session cannot be replaced')
check(Workspace.put(w,3,b)==nil and Workspace.activate(h.ctx,w,3)==nil,'third session is refused')
local names=Workspace.reserved_names(w)
check(Docs.fresh_name(h.ctx,'a',nil,{'A-001.MD','a-002.md'})=='a-003.md','fresh names reserve both case-insensitive loaded names')
local imported=assert(Docs.import_copy(h.ctx,'A.MD','download',names))
check(imported=='download-001.md' and h.public['A.MD']==nil,'remote import cannot occupy an unsaved loaded name')
-- Explicit migration keeps the legacy source until a verified slot exists.
for _,flag in ipairs({'write_fail','corrupt','remove_fail'})do
  h=host();assert(Docs.recovery(h.ctx,'legacy.md',text))
  local original=h.private['recovery.txt']
  h[flag]=flag=='remove_fail' and 'recovery.txt' or 'recovery-a.txt'
  check(Docs.migrate_recovery(h.ctx,1)==nil,'migration failure surfaced: '..flag)
  check(h.private['recovery.txt']==original,'legacy recovery retained: '..flag)
end
h=host();assert(Docs.recovery(h.ctx,'legacy.md',text));h.remove_fail='recovery.txt'
Docs.migrate_recovery(h.ctx,1);h.remove_fail=nil
check(Docs.migrate_recovery(h.ctx,1).text==text and h.private['recovery.txt']==nil,'interrupted cleanup resumes idempotently')
check(Docs.migrate_recovery(h.ctx,1).text==text,'completed migration is idempotent')
h=host();assert(Docs.recovery(h.ctx,'legacy.md',text));assert(Docs.recovery(h.ctx,'other.md','other',1))
check(Docs.migrate_recovery(h.ctx,1)==nil and Docs.load_recovery(h.ctx,1).text=='other' and Docs.load_recovery(h.ctx).text==text,'occupied slot and legacy are both preserved')
h.private['recovery.txt']='INKWRITE1\nlegacy.md\n\255'
local bad=h.private['recovery.txt'];check(Docs.migrate_recovery(h.ctx,2)==nil and h.private['recovery.txt']==bad and h.private['recovery-b.txt']==nil,'corrupt legacy is protected without creating a new slot')
-- Two maximum documents remain exact UTF-8/CRLF, with no document bytes in ctx.state.
h=host();local maximum=string.rep('č\r\n',8192)
a=assert(Session.new('max-a.md',maximum,nil,true,0,1));b=assert(Session.new('max-b.md',maximum,nil,true,0,2))
check(Session.checkpoint(h.ctx,a) and Session.checkpoint(h.ctx,b),'two maximum documents fit separate recovery records')
check(Docs.load_recovery(h.ctx,1).text==maximum and Docs.load_recovery(h.ctx,2).text==maximum and h.ctx.state==nil,'exact maximum bytes stay out of saved state')
-- Real controller keeps its UI/shared services outside the session and rejects
-- a delayed callback from a document replaced through the public New command.
package.loaded['domain.stats']={new=function()return setmetatable({saved=0},{__index=function()return function()end end})end}
local App=require('domain.app')
h=host();local c=h.ctx;c.state={last='start.md'};h.public['start.md']='Start'
c.screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}}
local f={line_height=24,measure=function(_,s)return (utf8.len(s) or 0)*12 end}
c.fonts={medium=f,large=f,size=function()return f end}
c.clock={millis=function()return 0 end,now=function()return {valid=false}end}
c.input={listen=function()return true end};c.budget={extend=function()end}
c.invalidate=function()end;c.set_tick=function()end;c.defer_full_refresh=function()end
c.after=function(_,ms,fn)return {fn=fn,cancel=function(self)self.cancelled=true end}end
App.load(c)
local controller
for i=1,50 do local key,value=debug.getupvalue(App.draw,i);if key=='A' then controller=value;break end end
check(controller and controller.editor.buffer:text()=='Start','controller loads into explicit editor session')
check(controller.buffer==nil and controller.doc==nil and controller.editor.keyboard==nil and controller.editor.sync==nil,'document state and shared services have distinct owners')
local function key(code,text,mods)App.input(c,{type='key',source='keyboard',phase='down',code=code,text=text,mods=mods or {}})end
key('KeyQ','q');local previous=controller.editor;local late=previous.redraw_timer
check(previous.dirty and late~=nil,'typing creates a session-owned pending frame')
key('KeyN',nil,{ctrl=true})
check(controller.editor~=previous and previous.buffer:text()=='Startq' and controller.editor.buffer:text()=='','New creates a separate session without mutating the outgoing buffer')
check(h.public['start.md']=='Startq' and late.cancelled,'New saves the outgoing file and cancels its timer')
local next_editor=controller.editor;local prepared=next_editor.prepared
late.fn(c)
check(controller.editor==next_editor and next_editor.prepared==prepared and next_editor.redraw_timer==nil,'late cancelled timer cannot prepare or reschedule work for the replacement document')
return n
