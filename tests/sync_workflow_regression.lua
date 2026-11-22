-- Full editor hooks + actual auth/transport/metadata with synthetic GitHub/SD.
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local Native=require('test_native')
local F=require('tests.fixtures.github_contents')
package.loaded['domain.sync_config']=Host.config()
local App=require('domain.app')
local Store=require('domain.sync_metadata')
local Sync=require('domain.sync')
local Docs=require('domain.documents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function state()for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then return v end end end
local OLD='Pôvodný čaj\r\n';local NEW='Žluťoučký kůň\r\nDruhý riadok\r\n'
local function setup(track)
 local h=Host.new();local c=h.ctx;h.private=Mock.host();c.storage=h.private.ctx.storage
 c.state={last='ideas.md',github_sync_enabled=true};c.invalidate=function()end;c.set_tick=function()end;c.defer_full_refresh=function()end
 c.after=function()return {cancel=function()end}end
 c.screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}}
 local font={line_height=24,measure=function(_,t)return (utf8.len(t)or 0)*10 end}
 c.fonts={medium=font,large=font,size=function()return font end};c.input={listen=function()return true end}
 c.clock.now=function()return {valid=true,epoch_sec=h.epoch,year=2026,month=11,day=15,hour=12,min=0,sec=0,weekday=0}end
 c.hash={sha256=function(_,t)return (Native.sha256(t):gsub('..',function(x)return string.char(tonumber(x,16))end))end}
 c.hex={encode=function(_,t)return (t:gsub('.',function(x)return string.format('%02x',x:byte())end))end}
 c.base64={encode=function(_,t)return Native.base64_encode(t)end,decode=function(_,t)return Native.base64_decode(t)end}
 h.files={['ideas.md']=OLD};h.public_writes=0
 c.files={list=function()local out={};for name,text in pairs(h.files)do out[#out+1]={name=name,size=#text}end;table.sort(out,function(a,b)return a.name<b.name end);return out end,
 size=function(_,name)local t=h.files[name];return t and #t or nil,t and nil or 'not_found'end,
 read=function(_,name,a,z)local t=h.files[name];return t and t:sub(a+1,a+z)or nil,t and nil or 'not_found'end,
 write=function(_,name,t)
   if (h.fail_backup and name~='ideas.md')or (h.fail_main and name=='ideas.md')then return nil,'io_error'end
   h.public_writes=h.public_writes+1;h.files[name]=t;return true
 end}
 local rawwrite=c.storage.write
 c.storage.write=function(self,name,t)
   if h.fail_recovery and name:match('^recovery.*%.txt$')then return nil,'io_error'end
   local ok,e=rawwrite(self,name,t)
   if name=='recovery.txt'and h.race_after_recovery then h.files['ideas.md']='External concurrent edit'end
   return ok,e
 end
 App.load(c);h.a=state();h.s=h.a.sync.session
 if track~=false then
   local m=Store.empty(Host.config().scope)
   m=assert(Store.checkpoint(m,'ideas.md',{remote_path='documents/ideas.md',remote_blob_sha=F.OLD,last_synced_local_fingerprint=Mock.hash(OLD)},Host.config().scope))
   assert(Store.save(c,m,Host.config().scope,Mock.hash,false))
 end
 h.s:connect(c);h:respond(Host.code());h.time=5000;h.s:poll(c);h:respond(Host.token());h:verify(h.s)
 assert(h.s:status(c).connected)
 function h:read(bytes,sha)self:verify(self.s);self:respond(F.file('ideas.md',bytes,sha))end
 function h:offer()self.s:sync(c);self:read(NEW,F.NEW);assert(self.s.pending_update,'no remote update offer')end
 return h
end
local h=setup(false);h.s:refresh_file_status(h.ctx)
check(h.s.file_status=='Changes waiting to upload','untracked saved document has clear upload status')
h.s:sync(h.ctx);h:verify(h.s);h:respond({},404);h:verify(h.s)
check(h.options.method=='PUT','one Sync creates a new remote document')
h:respond(F.written('documents/ideas.md'),201)
check(h.s.file_status=='Up to date at last sync'and h.s.notice:find('Synced:',1,true),'successful unified Sync reports file status')
local count=h.calls;h.s:sync(h.ctx);h:read(OLD,F.NEW)
check(h.calls==count+6 and h.s.notice:find('Up to date:',1,true),'equal content has no duplicate commit')
h=setup();h.s:refresh_file_status(h.ctx);check(h.s.file_status=='Up to date at last sync','stored checkpoint status is explicitly historical')
h:offer();check(h.s.file_status=='Remote changes found'and h.files['ideas.md']==OLD and h.a.editor.buffer:text()==OLD,'remote-only change offers update without changing local content')
h.a.editor.buffer:seek(4);h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']==NEW and h.a.editor.buffer:text()==NEW and not h.a.editor.dirty,'real editor hook updates public file and current buffer')
check(h.files['before-sync-001.md']==OLD and h.private.files['recovery.txt']==nil,'verified prior version backup and matching recovery cleanup')
local m=assert(Store.load(h.ctx,Host.config().scope,Mock.hash))
check(m.documents['ideas.md'].remote_blob_sha==F.NEW and m.documents['ideas.md'].last_synced_local_fingerprint==Mock.hash(NEW),'only verified updated bytes checkpoint')
check(h.a.editor.doc.name=='ideas.md'and h.a.editor.buffer:is_boundary(h.a.editor.buffer.pos)and h.options.method=='GET','same filename, valid caret and no remote write during local update')
-- Editing locally after the offer blocks any remote read/update.
h=setup();h:offer();h.a.editor.buffer:replace(0,0,'local');h.a.editor.dirty=true;count=h.calls;h.s:update_local(h.ctx)
check(h.calls==count and h.files['ideas.md']==OLD and h.a.editor.buffer:text()~=OLD,'dirty editor blocks offered replacement before network')
-- Remote SHA drift after confirmation never replaces local contents.
h=setup();h:offer();h.s:update_local(h.ctx);h:read('newer remote',F.RACE)
check(h.files['ideas.md']==OLD and h.a.editor.buffer:text()==OLD and h.public_writes==0,'remote change between offer and update fails closed')
-- Existing divergent recovery is protected, even if the editor itself is clean.
h=setup();h:offer();h.private.files['recovery.txt']='INKWRITE1\nother.md\nunsaved other writing';h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']==OLD and h.public_writes==0 and h.private.files['recovery.txt']:find('unsaved other writing',1,true),'unrelated recovery cannot be overwritten by remote update')
for _,flag in ipairs({'fail_backup','fail_recovery','fail_main'})do
 h=setup();h:offer();h[flag]=true;h.s:update_local(h.ctx);h:read(NEW,F.NEW)
 check(h.files['ideas.md']==OLD and h.a.editor.buffer:text()==OLD and h.s.file_status~='Up to date at last sync','storage failure preserves open document: '..flag)
 m=assert(Store.load(h.ctx,Host.config().scope,Mock.hash));check(m.documents['ideas.md'].remote_blob_sha==F.OLD,'failed update retains old checkpoint')
end
h=setup();h:offer();h.race_after_recovery=true;h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']=='External concurrent edit'and h.a.editor.buffer:text()==OLD and h.files['before-sync-001.md']==OLD,'final prewrite check protects external SD edits')
h=setup();h:offer();h.s:update_local(h.ctx);h:verify(h.s);h.s:pause(h.ctx);count=h.public_writes
check(not h.s.busy and h.public_writes==count and h.files['ideas.md']==OLD,'pause cancels remote update before local writes')
-- Both sides changed: remain in copy-based conflict flow, never offer replace.
h=setup();h.a.editor.buffer:replace(0,0,'Local change ');h.a.editor.dirty=true;h.s:sync(h.ctx);h:read(NEW,F.NEW)
check(h.s.conflict and not h.s.pending_update and h.a.editor.buffer:text()~=NEW,'both-changed conflict keeps conservative copy choices')
-- Record write after local update is separate from successful SD protection.
h=setup();h:offer();h.s:update_local(h.ctx);h.private.fail_write=true
-- Recovery must succeed; fail only the sync checkpoint.
local write=h.ctx.storage.write
h.ctx.storage.write=function(self,name,t)if name==Store.FILE then return nil,'io_error'end;local old=h.private.fail_write;h.private.fail_write=false;local a,b=write(self,name,t);h.private.fail_write=old;return a,b end
h:read(NEW,F.NEW)
check(h.files['ideas.md']==NEW and h.files['before-sync-001.md']==OLD and h.s.notice:find('record not saved',1,true),'metadata failure does not undo verified local update or lose backup')
-- Actual editor Save enqueues only after success; typing cancels without SD/network work.
h=setup();h.ctx.state.github_sync_auto=true;h.a.sync.auto:load(h.ctx)
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyA',text='a',mods={}})
local calls=h.calls
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyS',mods={ctrl=true}})
check(not h.a.editor.dirty and #h.a.sync.auto.items==1 and h.calls==calls,'Ctrl+S saves locally and queues without a synchronous network request')
h.time=h.time+30000;App.tick(h.ctx)
check(h.s.busy,'foreground idle tick starts queued saved document')
local writes=h.public_writes
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyB',text='b',mods={}})
check(h.a.editor.dirty and not h.s.busy and h.public_writes==writes and h.calls==calls+1,'typing interrupts automatic transfer without file IO or another request')
h.s:sync(h.ctx);h:read(OLD,F.OLD);h:verify(h.s);h:respond(F.written('documents/ideas.md'),201)
check(#h.a.sync.auto.items==0,'successful manual Sync removes the exact matching automatic queue entry')
h=setup();h.ctx.state.github_sync_auto=true;h.a.sync.auto:load(h.ctx)
h.fail_main=true;App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyA',text='a',mods={}})
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyS',mods={ctrl=true}})
check(h.a.editor.save_failed and #h.a.sync.auto.items==0,'failed public Save never enters automatic queue')
-- Explicit conflict review supports both directions with verified backups and fresh SHAs.
local LOCAL='Local conflicting draft\r\n'
local function reviewed()
 local x=setup();x.a.editor.buffer:replace(0,#OLD,LOCAL);x.a.editor.dirty=true
 x.s:review_document(x.ctx);x:read(NEW,F.NEW);assert(x.s.review);return x
end
h=reviewed();check(h.s.review.file.bytes==LOCAL and h.s.review.remote.bytes==NEW,'review captures both exact versions after safely saving local edits')
h.s:resolve_review(h.ctx,'local');h:read(NEW,F.NEW)
check(h.a.editor.buffer:text()==NEW and h.files['ideas.md']==NEW and h.files['before-sync-001.md']==LOCAL,'confirmed GitHub-to-local resolution replaces editor and preserves local backup')
check(not h.s.review and Store.load(h.ctx,Host.config().scope,Mock.hash).documents['ideas.md'].remote_blob_sha==F.NEW,'resolved local version checkpoints reviewed blob SHA')
h=reviewed();h.s:resolve_review(h.ctx,'github');h:read(NEW,F.NEW)
check(h.files['github-before-001.md']==NEW and h.a.editor.buffer:text()==LOCAL,'GitHub original is backed up locally before an overwrite request')
h:verify(h.s);local body=Native.decode(h.options.body)
check(h.options.method=='PUT'and body.sha==F.NEW and Native.base64_decode(body.content)==LOCAL,'explicit GitHub overwrite uses fresh reviewed blob SHA and exact local bytes')
h:respond({content={type='file',path='documents/ideas.md',sha=string.rep('c',40)}},200)
check(not h.s.review and h.files['ideas.md']==LOCAL and Store.load(h.ctx,Host.config().scope,Mock.hash).documents['ideas.md'].remote_blob_sha==string.rep('c',40),'confirmed remote replacement preserves local editor and checkpoints receipt')
h=reviewed();h.s:resolve_review(h.ctx,'github');h:read(NEW,F.OLD)
check(not h.s.busy and h.files['github-before-001.md']==nil and h.files['ideas.md']==LOCAL,'changed remote SHA is rejected before backup or overwrite')
h=reviewed();local calls=h.calls;h.a.editor.buffer:replace(0,0,'new edit');h.a.editor.dirty=true;h.s:resolve_review(h.ctx,'github')
check(h.calls==calls and not h.s.review,'local edits after review prevent resolution before any request')
h=reviewed();h.fail_backup=true;h.s:resolve_review(h.ctx,'github');h:read(NEW,F.NEW)
check(not h.s.busy and h.files['github-before-001.md']==nil and h.files['ideas.md']==LOCAL,'failed GitHub backup blocks remote overwrite')
h=reviewed();h.fail_recovery=true;h.s:resolve_review(h.ctx,'local');h:read(NEW,F.NEW)
check(h.files['ideas.md']==LOCAL and h.a.editor.buffer:text()==LOCAL,'failed recovery protection blocks local replacement')
h=reviewed();h.ctx.storage:write('recovery.txt','INKWRITE1\nother.md\nUnrelated recovery');h.s:resolve_review(h.ctx,'local');h:read(NEW,F.NEW)
check(h.files['ideas.md']==LOCAL and h.ctx.storage:read('recovery.txt'):find('Unrelated recovery',1,true),'unrelated recovery survives refused local replacement')
h=reviewed();h.s:resolve_review(h.ctx,'github');h:read(NEW,F.NEW);h:verify(h.s);h:respond({},409)
check(not h.s.busy and h.files['github-before-001.md']==NEW and h.files['ideas.md']==LOCAL,'GitHub write race preserves both local data and remote backup')
h=setup();h.s:review_document(h.ctx);h:read(OLD,F.OLD);h.s:resolve_review(h.ctx,'github');local calls=h.calls;h:read(OLD,F.OLD)
check(h.calls==calls+5 and not h.s.review,'already equal versions checkpoint without a redundant PUT')
h=setup();h.files['other.md']='Other local';local current=h.a.editor.buffer:text()
h.s:review_document(h.ctx,'other.md');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
check(h.s.review.name=='other.md'and h.s.review.file.bytes=='Other local','pending files can be reviewed without opening them in editor')
h.s:resolve_review(h.ctx,'local');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
check(h.files['other.md']=='Other GitHub'and h.a.editor.buffer:text()==current and h.a.editor.doc.name=='ideas.md','resolving another file preserves active editor identity and bytes')
-- Badge is visible and clickable, including focus mode; close dialogs retain input ownership.
local badge
local g=setmetatable({text=function(_,x,y,t,o)if t=='GitHub !'then badge={x=x,y=y}end end},{__index=function()return function()end end})
local function has_badge(x)
 badge=nil;App.draw(x.ctx,g);return badge~=nil
end

-- A held upload can predate a manual save when automatic uploads are off.
local stale=setup();local stale_queue=stale.a.sync.auto
stale.ctx.state.github_sync_auto=true;stale_queue:saved(stale.ctx,'ideas.md',OLD)
stale_queue.items[1].held=true;stale_queue.items[1].reason='conflict'
stale.ctx.state.github_sync_auto=false
stale.a.editor.buffer:replace(0,#OLD,LOCAL);stale.a.editor.dirty=true
check(has_badge(stale),'held upload is visible before manual Sync')
stale.s:sync(stale.ctx);stale:read(OLD,F.OLD);stale:verify(stale.s);stale:respond(F.written('documents/ideas.md'),200)
check(stale.s.notice=='Synced: ideas.md'and stale.s.file_status=='Up to date at last sync','manual Sync verifies and records the current SD version')
check(#stale_queue.items==0 and not has_badge(stale),'manual Sync clears a superseded upload hold for the same filename')
check(stale_queue:flush(stale.ctx),'the cleared hold is saved')
local reloaded=require('domain.sync_auto').new(stale.s,{})
reloaded:load(stale.ctx,true)
check(#reloaded.items==0 and not reloaded.bad,'a fresh queue cannot restore the superseded hold')

local orphan=setup();local orphan_queue=orphan.a.sync.auto
orphan.ctx.state.github_sync_auto=true
orphan_queue:saved(orphan.ctx,'removed.md','previous file')
orphan_queue.items[1].held=true;orphan_queue.items[1].reason='conflict'
orphan.s.needs_review='removed.md'
check(has_badge(orphan),'a legacy hold can refer to a file removed from the SD card')
local requests=orphan.calls
App.input(orphan.ctx,{type='pointer',phase='up',gesture='tap',x=badge.x,y=badge.y})
check(orphan.calls==requests and #orphan_queue.items==0 and not orphan.s.needs_review
 and orphan.s.notice=='Local file no longer on the SD card: removed.md','badge retires a missing file and reports its name without a GitHub request')
App.input(orphan.ctx,{type='key',key='back',phase='up'})
check(not has_badge(orphan),'returning to writing clears the badge for the removed file')

local other=setup();local other_queue=other.a.sync.auto
other.ctx.state.github_sync_auto=true
other.files['conflict.md']='Local version';other_queue:saved(other.ctx,'conflict.md',other.files['conflict.md'])
other_queue:saved(other.ctx,'unreadable.md','Unconfirmed SD contents')
other_queue:saved(other.ctx,'removed.md','Previous file')
for _,item in ipairs(other_queue.items)do item.held=true;item.reason='conflict'end
local original_size=other.ctx.files.size
other.ctx.files.size=function(self,name)
 if name=='unreadable.md'then return nil,'io_error'end
 return original_size(self,name)
end
other.a.sync:sync_document(other.ctx);other:read(OLD,F.OLD)
check(#other_queue.items==2 and other_queue.items[1].name=='conflict.md'and other_queue.items[2].name=='unreadable.md',
 'Sync removes confirmed missing files and preserves other conflicts and SD read failures')
App.input(other.ctx,{type='key',key='back',phase='up'})
check(has_badge(other),'a separate existing conflict keeps the attention badge')

local function held_offline()
 local x=setup();local c=x.ctx;local q=x.a.sync.auto
 c.state.github_sync_auto=true;c.state.github_sync_remember=true
 x.s:remember(c);q:saved(c,'ideas.md',OLD)
 for _,wait in ipairs({30000,30000,120000})do
  x.time=x.time+wait;App.tick(c);x:verify(x.s);x:respond('',200,{ok=false,err='no_network'})
 end
 assert(q.items[1].held and q.items[1].reason=='no_network')
 return x,q
end
local offline,q=held_offline()
offline.s:refresh_file_status(offline.ctx)
check(has_badge(offline)and offline.s.file_status=='Up to date at last sync','cached checkpoint and held offline upload can coexist')
offline.s:disconnect(offline.ctx);offline.s:connect(offline.ctx)
offline:respond('',200,{ok=false,err='no_network'})
check(has_badge(offline)and q.items[1].attempts==3,'failed reconnect leaves offline attention and retry count intact')
offline.s:connect(offline.ctx);offline:verify(offline.s)
check(not has_badge(offline)and #q.items==1 and q.items[1].attempts==0,'verified reconnect clears offline attention and requeues the same saved file')
check(q.items[1].fingerprint==Mock.hash(OLD)and q.dirty,'recovery retains the queued fingerprint and marks the change for persistence')
offline.time=offline.time+30000;App.tick(offline.ctx);offline:read(OLD,F.OLD)
check(not has_badge(offline)and #q.items==0 and offline.options.method=='GET','recovery verifies matching bytes and clears the queue without a redundant write')
offline,q=held_offline()
offline.files['other.md']='Other saved document';q:saved(offline.ctx,'other.md',offline.files['other.md'])
offline.time=offline.time+30000;App.tick(offline.ctx);offline:verify(offline.s)
offline:respond(F.file('other.md',offline.files['other.md'],F.NEW))
check(#q.items==1 and q.items[1].held and q.items[1].attempts==3,'background success on a different file leaves exhausted retry budgets intact')
offline,q=held_offline()
offline.files['other.md']='different';offline.files['limited.md']='limited'
q.items[2]={name='other.md',fingerprint=Mock.hash('different'),held=true,reason='conflict',attempts=1,last=offline.time}
q.items[3]={name='limited.md',fingerprint=Mock.hash('limited'),held=true,reason='rate_limited',attempts=3,last=offline.time}
App.input(offline.ctx,{type='key',source='keyboard',phase='down',code='KeyG',mods={ctrl=true}})
offline:read(OLD,F.OLD);offline.a.sync:tick(offline.ctx)
check(not q.items[1].held and q.items[2].held and q.items[3].held,'a successful review using the existing login requeues offline work and keeps conflict and rate-limit holds')
h=setup();h.a.sync.auto.items={{name='ideas.md',held=true,reason='conflict'}}
App.draw(h.ctx,g);check(badge~=nil,'writing screen displays a conflict badge without replacing local Saved status')
App.input(h.ctx,{type='pointer',phase='up',gesture='tap',x=badge.x,y=badge.y});h:read(NEW,F.NEW);h.a.sync:tick(h.ctx)
check(h.a.sync.active and h.a.sync.page=='compare','badge tap opens actual two-version review')
h.s:close(h.ctx);h.a.sync.active=false;App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyF',mods={ctrl=true,shift=true}});badge=nil;App.draw(h.ctx,g)
check(badge~=nil,'focus mode retains the GitHub attention indicator')
h.a.close_modal={dirty=false};App.input(h.ctx,{type='pointer',phase='up',gesture='tap',x=badge.x,y=badge.y})
check(not h.a.sync.active,'badge cannot bypass an open close confirmation')
h=reviewed();h.s:resolve_review(h.ctx,'github');h:read(NEW,F.NEW);h.files['ideas.md']='Changed during verification';h:verify(h.s)
check(not h.s.busy and h.options.method=='GET'and h.files['github-before-001.md']==NEW,'local disk revision is checked again immediately before the GitHub PUT')
h=reviewed();h.s:resolve_review(h.ctx,'local');h:verify(h.s);h:respond({},404)
check(not h.s.busy and h.files['ideas.md']==LOCAL and h.a.editor.buffer:text()==LOCAL,'GitHub deletion during review cannot replace local text')
h=reviewed();h.s:resolve_review(h.ctx,'github');h:respond({},401)
check(not h.s.busy and not h.s:status(h.ctx).connected and h.files['github-before-001.md']==nil,'revoked authorization prevents backup/overwrite during resolution')
h=setup();local calls=h.calls;h.s:review_document(h.ctx,'IDEAS.md')
check(h.calls==calls and not h.s.review,'case-alias filename cannot bypass the active editor replacement guard')
h=setup();h.a.sync.auto.items={{name='ideas.md',held=true,reason='conflict'}}
local measure=h.a.ui_small.measure;local badge_measures=0
h.a.ui_small.measure=function(self,text)if text=='GitHub !'then badge_measures=badge_measures+1 end;return measure(self,text)end
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyA',text='a',mods={}})
check(badge_measures==0,'typing never computes pointer-only badge geometry or measures its label')
-- Both loaded panes participate in real sync snapshot/apply and auto guards.
local Session=require('domain.editor_session')
local Workspace=require('domain.workspace')
local function split_with_other()
 local x=setup()
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='KeyP',mods={ctrl=true,shift=true}})
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='ArrowDown',mods={}})
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='Enter',mods={}})
 assert(x.a.workspace.split)
 x.files['other.md']='Other local'
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='Tab',mods={ctrl=true}})
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='KeyO',mods={ctrl=true}})
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='ArrowDown',mods={}})
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='Enter',mods={}})
 local editor=x.a.editor;assert(editor.doc.name=='other.md')
 App.input(x.ctx,{type='key',source='keyboard',phase='down',code='Tab',mods={ctrl=true}})
 return x,editor
end
h,b=split_with_other();local active=h.a.editor
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyA',text='a',mods={}})
local active_bytes=active.buffer:text();local recovery=h.private.files['recovery-a.txt']
h.s:review_document(h.ctx,'other.md');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
check(h.s.review and h.s.review.file.identity==b.doc,'named review captures inactive B session identity rather than treating B as an unloaded disk file')
h.s:resolve_review(h.ctx,'local');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
check(h.a.editor==active and active.dirty and active.buffer:text()==active_bytes,'remote update of B preserves dirty active A and its identity')
check(b.buffer:text()=='Other GitHub'and h.files['other.md']=='Other GitHub'and not b.dirty,'confirmed remote update changes the loaded inactive B buffer and saved base')
check(h.private.files['recovery-a.txt']==recovery and h.files['before-sync-001.md']=='Other local','B update leaves A recovery intact and creates the verified B backup')
h,b=split_with_other()
h.s:review_document(h.ctx,'other.md');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
b.buffer:replace(0,0,'Unsaved B ');Session.changed(b,h.time,0);local writes=h.public_writes;local calls=h.calls
h.s:resolve_review(h.ctx,'local')
check(h.calls==calls and h.public_writes==writes and b.dirty and b.buffer:text()=='Unsaved B Other local','late dirty edit in inactive B rejects local replacement before network or IO')
h,b=split_with_other();h.s:review_document(h.ctx,'other.md');h:verify(h.s)
local replacement=assert(Session.new('other.md','Other local','Other local',false,h.time,2))
assert(Workspace.put(h.a.workspace,2,replacement));h:respond(F.file('other.md','Other GitHub',F.NEW))
check(not h.s.review and h.files['other.md']=='Other local'and replacement.buffer:text()=='Other local','stale review callback cannot attach to a replacement B session with the same filename and revision')
h,b=split_with_other();h.s:review_document(h.ctx,'OTHER.md');local calls=h.calls
check(not h.s.review and not h.s.busy,'case alias of inactive B cannot bypass loaded-session guards')
h,b=split_with_other();h.s:review_document(h.ctx,'other.md');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
h.fail_recovery=true;h.s:resolve_review(h.ctx,'local');h:verify(h.s);h:respond(F.file('other.md','Other GitHub',F.NEW))
check(h.files['other.md']=='Other local'and b.buffer:text()=='Other local','failed B recovery write prevents remote replacement of inactive B')
h,b=split_with_other();h.ctx.state.github_sync_auto=true;h.ctx.state.github_sync_delay=15
App.input(h.ctx,{type='key',source='keyboard',phase='down',code='KeyS',mods={ctrl=true}})
check(#h.a.sync.auto.items==1,'saving A queues its saved version')
h.time=h.time+25000;b.buffer:replace(0,0,'Dirty B ');Session.changed(b,h.time,0)
local calls=h.calls;App.tick(h.ctx)
check(h.calls==calls and not h.s.busy and b.dirty,'dirty inactive B blocks automatic uploads while active A is clean')
return n
