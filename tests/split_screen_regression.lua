local Host=require('tests.support.writer_host')
local Docs=require('domain.documents')
local Session=require('domain.editor_session')
local App=require('domain.app')
local Layout=require('domain.layout');local rows=Layout.rows
local drawing=false
Layout.rows=function(...)assert(not drawing,'no wrapping during draw');return rows(...)end
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function contains(h,text)
 for _,v in ipairs(h.texts)do if v.text:find(text,1,true)then return true end end
 for _,v in ipairs(h.boxes)do if v.text:find(text,1,true)then return true end end
end
local h=Host.new();local a=h:state();local original=a.editor
h:split(2);a=h:state()
check(a.workspace.split and a.workspace.direction=='horizontal'and a.workspace.slotted,'horizontal split enables two recovery slots')
check(a.workspace.sessions[1]==original and a.workspace.sessions[2]~=original,'split keeps the first session and creates a distinct second one')
check(h.private['recovery.txt']==nil and Docs.load_recovery(h.ctx,1).text==original.buffer:text(),'legacy recovery is migrated before split activation')
check(contains(h,'A ')and contains(h,'B '),'both pane filename strips are drawn')
h:switch();h:open('bravo.md');a=h:state();local b=a.editor
check(a.workspace.active==2 and b.doc.name=='bravo.md'and a.workspace.sessions[1].doc.name=='alpha.md','Open targets active B and preserves A')
h:edit(' B edit');h:switch();h:edit(' A edit');local newestA=a.editor.buffer:text();local newestB=b.buffer:text()
check(h.files['alpha.md']~=newestA and h.files['bravo.md']~=newestB,'editing both panes does not imply public Save')
local before=h.public_writes;h:save()
check(h.files['alpha.md']==newestA and h.files['bravo.md']~=newestB and h.public_writes==before+1,'Save A writes A only')
check(Docs.load_recovery(h.ctx,2).text==newestB,'Save A retains unsaved B recovery')
h:switch();h:save();check(h.files['bravo.md']==newestB and not b.dirty,'Save B writes B')
h:edit(' newest B');newestB=b.buffer:text();h:switch();h:edit(' newest A');newestA=a.editor.buffer:text()
a=h:restart()
check(a.workspace.split and a.workspace.active==1,'restart restores split layout and active pane')
check(a.workspace.sessions[1].buffer:text()==newestA and a.workspace.sessions[2].buffer:text()==newestB,'restart recovers both exact dirty buffers')
check(h.files['alpha.md']~=newestA and h.files['bravo.md']~=newestB,'recovery does not overwrite public originals')
-- Switching, ratios and focus retain session identity, undo and selection.
h=Host.new();h:split(3);h:switch();h:open('bravo.md');h:edit(' edit');a=h:state();b=a.editor;local pos=b.buffer.pos;b.anchor=0
h:split(5);check(a.workspace.ratio=='2:1'and a.editor==b and b.buffer.pos==pos and b.anchor==0,'ratio change preserves selected text and session identity')
h:key('KeyF',nil,{ctrl=true,shift=true});h:draw();check(a.focus_mode and a.workspace.split and contains(h,'Alpha')and contains(h,'Bravo'),'focus shows both documents')
check(h.saved_state.focus_mode==true,'split focus preference is checkpointed immediately before a forced runtime restart')
h:split(6);check(a.focus_mode and a.workspace.ratio=='1:2','focus split settings preserve focus and change ratio')
h.ctx.screen:set_orientation('landscape');h:advance(1);h:key('KeyR',nil,{ctrl=true});h:draw()
check(a.workspace.direction=='vertical'and a.editor==b and b.anchor==0,'screen rotation keeps split direction and selection')
h:split(8);check(not a.workspace.split and a.editor==b and a.workspace.sessions[1]~=nil,'single-pane mode retains the hidden document')
h:split(3);check(a.workspace.split and a.editor==b,'re-enabling split restores both sessions')
h:key('KeyZ',nil,{ctrl=true});check(b.buffer:text()=='Bravo original.\r\n','B undo history survives all layout changes')
-- Duplicate file requests select the owning pane instead of duplicating a writer.
h:open('alpha.md');check(a.workspace.active==1 and a.editor==a.workspace.sessions[1]and a.workspace.sessions[2]==b,'opening an already-loaded filename selects its pane')
-- A failed checkpoint cannot switch away from newly edited text.
h:edit(' protected');h.fail_private='recovery-a.txt';h:switch()
check(a.workspace.active==1 and a.editor.dirty and a.message:find('Cannot switch',1,true),'failed private write keeps A active with a visible error')
h.fail_private=nil;h:switch();check(a.workspace.active==2,'explicit switch succeeds after storage recovers')
-- Actual Classic controls and focus settings remain reachable without touch.
h:key('Left');App.input(h.ctx,{type='key',key='left',phase='down'});check(a.workspace.active==1,'Classic Left activates A')
App.input(h.ctx,{type='key',key='right',phase='down'});check(a.workspace.active==2,'Classic Right activates B')
if not a.focus_mode then h:key('KeyF',nil,{ctrl=true,shift=true})end
App.input(h.ctx,{type='key',key='ok',phase='down'});check(a.view=='split'and a.focus_mode,'Classic OK opens split controls in focus')
App.input(h.ctx,{type='key',key='back',phase='up'});check(a.view=='editor'and a.focus_mode,'Classic Back restores focused split')
-- Dirty hidden sessions still autosave; failures retain the failed session.
h=Host.new();h:split(2);h:switch();h:open('bravo.md');h:edit(' hidden');a=h:state();b=a.editor;h:switch();h:split(8)
h:advance(6000);h:tick();check(not b.dirty and h.files['bravo.md']==b.buffer:text(),'idle autosave includes hidden inactive B')
h:edit(' failed');h.fail_public=true;h:advance(6000);h:tick()
check(a.editor.dirty and a.editor.save_failed and Docs.load_recovery(h.ctx,1).text==a.editor.buffer:text(),'failed autosave keeps newest recovery and dirty state')
h.fail_public=false
-- Exit Save applies to both dirty sessions, and refuses to quit on failure.
h=Host.new();h:split(2);h:switch();h:open('bravo.md');h:edit(' B');h:switch();h:edit(' A');a=h:state();b=a.workspace.sessions[2]
App.input(h.ctx,{type='key',key='back',phase='up'});check(a.close_modal and a.close_modal.dirty,'close confirmation sees both dirty documents')
h.fail_public=true;h:key('ArrowRight');h:key('Enter');check(not h.quit and a.editor.dirty,'failed Save and close stays open')
h.fail_public=false;App.input(h.ctx,{type='key',key='back',phase='up'});h:key('ArrowRight');h:key('Enter')
check(h.quit and not a.editor.dirty and not b.dirty and h.files['bravo.md']==b.buffer:text(),'Save and close saves both documents before quitting')
-- Every renderer path is prepared outside draw for both screen orientations.
for _,size in ipairs({{480,800},{800,480}})do for _,mode in ipairs({false,true})do
 for _,direction in ipairs({2,3})do for _,ratio in ipairs({4,5,6})do
  h=Host.new({width=size[1],height=size[2]});h:split(direction);h:switch();h:open('bravo.md');h:split(ratio);a=h:state()
  if mode then h:key('KeyF',nil,{ctrl=true,shift=true})end
  drawing=true;h:draw();drawing=false
  check(contains(h,'Alpha')and contains(h,'Bravo'),'both real document contents render in each layout')
  local first=a.workspace.sessions[1].prepared;local second=a.workspace.sessions[2].prepared
  check(first and second and first.doc~=second.doc and first.key~=second.key,'prepared frames retain distinct document and geometry identities')
 h:edit('x');check(a.workspace.sessions[1].prepared==first,'typing in B reuses inactive A prepared frame')
 end end
end end
-- Touch activation and caret movement use the target pane's displayed snapshot.
h=Host.new();h:split(2);h:switch();h:open('bravo.md');a=h:state()
local function header(letter)
 h:draw();for _,v in ipairs(h.boxes)do if v.text:match('^'..letter..'[!* ]')then return v end end
 error('missing pane header')
end
local function text_point(slot)
 local p=a.workspace.sessions[slot].prepared;local v={};for part in p.key:gmatch('[^:]+')do v[#v+1]=tonumber(part)end
 return v[2]+25,v[3]+8
end
local head=header('A');h:touch(head.x+8,head.y+20);h:draw()
check(a.workspace.active==1,'touching A header activates A')
head=header('B');local bp=a.workspace.sessions[2].buffer.pos;h:touch(head.x+8,head.y+20);h:draw()
check(a.workspace.active==2 and a.editor.buffer.pos==bp,'header activation preserves B caret')
local tx,ty=text_point(1);h:advance(100);h:touch(tx,ty);h:draw()
check(a.workspace.active==1 and a.editor.buffer.pos<5 and a.editor.prepared.pos==a.editor.buffer.pos,'tap in inactive A activates it and publishes A caret immediately')
h:advance(100);h:touch(tx,ty,'double_tap');h:draw()
check(a.editor.anchor~=nil and a.editor.buffer:slice(a.editor.anchor,a.editor.buffer.pos)=='Alpha','double-tap selects a word in the correct pane')
head=header('B');h:touch(head.x+8,head.y+20);h:draw();local old=a.editor.buffer.pos
tx,ty=text_point(1);local bx,by=text_point(2)
h:touch(tx,ty,'tap','down');h:touch(bx,by,'swipe_up','up',tx,ty);h:draw()
check(a.workspace.active==2 and a.editor.buffer.pos==old and a.pointer_down_x==nil,'cross-divider swipe does not retarget either document or retain a stale touch origin')
head=header('A');h:touch(head.x+8,head.y+20,'tap','hold')
check(a.view=='split','long hold on a pane header opens split settings')
-- Blank secondary panes remain blank after restart instead of creating recovered copies.
h=Host.new();h:split(2);a=h:state();local empty_name=a.workspace.sessions[2].doc.name;a=h:restart()
check(a.workspace.sessions[2].doc.name==empty_name and not a.workspace.sessions[2].dirty,'empty B restores without a spurious recovered file')
-- Bad workspace state and either unreadable recovery are preserved, never reset.
h=Host.new({state={inkwrite_workspace={schema=999}}});a=h:state()
check(a.blocked and h.ctx.state.inkwrite_workspace.schema==999 and h.public_writes==0,'unknown workspace schema is protected')
h=Host.new({private={['recovery-b.txt']='broken'}});a=h:state()
check(a.blocked and h.private['recovery-b.txt']=='broken'and h.public_writes==0,'corrupt secondary recovery blocks destructive startup')
-- Notice is shared below the whole split, rather than overwriting B's header.
h=Host.new();h:split(2);a=h:state();h:edit(' protected');h.fail_private='recovery-a.txt';h:switch();h:draw()
local lower=header('B');local notice
for _,v in ipairs(h.boxes)do if v.text:find('Cannot switch',1,true)then notice=v end end
check(notice and notice.y>=lower.y+lower.h,'save/recovery notice is below both pane headers')
-- New reserves the other pane even when neither new filename exists on SD.
h=Host.new();h:split(2);h:switch();h:key('KeyN',nil,{ctrl=true});a=h:state();local bn=a.editor.doc.name
h:switch();h:key('KeyN',nil,{ctrl=true})
check(a.editor.doc.name~=bn and h.files[bn]==nil,'New allocates different filenames for two unsaved panes')
local same=a.editor;h:edit(' cannot save');h.fail_public=true;h:key('KeyN',nil,{ctrl=true})
check(a.editor==same and a.editor.dirty,'failed Save prevents New from replacing the active document')
-- Library management cannot rename or delete a dirty document open in B.
h=Host.new();h:split(2);h:switch();h:open('bravo.md');h:edit(' unsaved B');a=h:state();b=a.editor;h:switch()
local bbytes=b.buffer:text();h:key('KeyO',nil,{ctrl=true});h:key('ArrowDown');h:key('ArrowRight');h:key('ArrowRight');h:key('Enter')
check(a.view=='delete_confirm','library delete still requires confirmation')
h:key('ArrowRight');h:key('Enter')
check(h.files['bravo.md']=='Bravo original.\r\n'and b.buffer:text()==bbytes and b.dirty and a.message:find('open in pane B',1,true),'library cannot delete the inactive B file or its unsaved edits')
h:key('Escape');h.ctx.input.text=function(_,spec,done)done(h.ctx,'renamed.md');return true end
h:key('KeyO',nil,{ctrl=true});h:key('ArrowDown');h:key('ArrowRight');h:key('Enter')
check(h.files['bravo.md']~=nil and h.files['renamed.md']==nil and b.doc.name=='bravo.md'and a.message:find('open in pane B',1,true),'library cannot rename an inactive loaded document behind its session')
-- Workspace settings failure does not remove either document recovery.
h=Host.new();h.fail_state=true;h:split(2);a=h:state()
check(a.workspace.split and a.message:find('settings could not be saved',1,true)and Docs.load_recovery(h.ctx,1)and Docs.load_recovery(h.ctx,2),'failed preference checkpoint leaves both recoveries discoverable')
-- A cancelled multi-document discard keeps the writer open and repairs snapshots.
h=Host.new();h:split(2);h:switch();h:open('bravo.md');h:edit(' B');h:switch();h:edit(' A');a=h:state()
h.fail_remove='recovery-b.txt';App.input(h.ctx,{type='key',key='back',phase='up'});h:key('ArrowRight');h:key('ArrowRight');h:key('Enter')
check(not h.quit and Docs.load_recovery(h.ctx,1).text==a.workspace.sessions[1].buffer:text()and Docs.load_recovery(h.ctx,2).text==a.workspace.sessions[2].buffer:text(),'failed Discard keeps writer open and restores both dirty recovery snapshots')
h.fail_remove=nil;App.input(h.ctx,{type='key',key='back',phase='up'});h:key('ArrowRight');h:key('ArrowRight');h:key('Enter')
check(h.quit and Docs.load_recovery(h.ctx,1)==false and Docs.load_recovery(h.ctx,2)==false,'confirmed Discard removes both dirty recoveries before exit')
h=Host.new();h:split(2);h:switch();h:open('bravo.md');h:edit(' B');h:switch();h:edit(' A');a=h:state();b=a.workspace.sessions[2]
h.fail_public='bravo.md';App.input(h.ctx,{type='key',key='back',phase='up'});h:key('ArrowRight');h:key('Enter')
check(not h.quit and not a.editor.dirty and b.dirty and b.save_failed,'partial Save and close success still stays open when inactive B fails')
check(h.files['alpha.md']==a.editor.buffer:text()and Docs.load_recovery(h.ctx,2).text==b.buffer:text(),'partial Save and close protects saved A and recoverable B')
-- Small keyboard-constrained panes and fallback fonts never draw body rows outside their pane.
for _,size in ipairs({{480,800},{800,480}})do for _,height in ipairs({24,44})do
 for _,direction in ipairs({2,3})do for _,ratio in ipairs({4,5,6})do
  h=Host.new({width=size[1],height=size[2],line=height});h:split(direction);h:switch();h:open('bravo.md');h:split(ratio);a=h:state()
  a.virtual=true;h:key('KeyR',nil,{ctrl=true});h:draw()
  for slot=1,2 do local p=a.workspace.sessions[slot].prepared;local v={};for part in p.key:gmatch('[^:]+')do v[#v+1]=tonumber(part)end
    for i,row in ipairs(p.rows)do check(v[3]+(i-1)*v[6]+height<=v[5],'keyboard/fallback layout only draws complete rows inside its own pane')end
  end
 end end
end end
return n
