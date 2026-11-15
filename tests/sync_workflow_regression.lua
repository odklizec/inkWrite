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
 c.files={size=function(_,name)local t=h.files[name];return t and #t or nil,t and nil or 'not_found'end,
 read=function(_,name,a,z)local t=h.files[name];return t and t:sub(a+1,a+z)or nil,t and nil or 'not_found'end,
 write=function(_,name,t)
   if (h.fail_backup and name~='ideas.md')or (h.fail_main and name=='ideas.md')then return nil,'io_error'end
   h.public_writes=h.public_writes+1;h.files[name]=t;return true
 end}
 local rawwrite=c.storage.write
 c.storage.write=function(self,name,t)
   if h.fail_recovery and name=='recovery.txt'then return nil,'io_error'end
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
h:offer();check(h.s.file_status=='Remote changes found'and h.files['ideas.md']==OLD and h.a.buffer:text()==OLD,'remote-only change offers update without changing local content')
h.a.buffer:seek(4);h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']==NEW and h.a.buffer:text()==NEW and not h.a.dirty,'real editor hook updates public file and current buffer')
check(h.files['before-sync-001.md']==OLD and h.private.files['recovery.txt']==nil,'verified prior version backup and matching recovery cleanup')
local m=assert(Store.load(h.ctx,Host.config().scope,Mock.hash))
check(m.documents['ideas.md'].remote_blob_sha==F.NEW and m.documents['ideas.md'].last_synced_local_fingerprint==Mock.hash(NEW),'only verified updated bytes checkpoint')
check(h.a.doc.name=='ideas.md'and h.a.buffer:is_boundary(h.a.buffer.pos)and h.options.method=='GET','same filename, valid caret and no remote write during local update')
-- Editing locally after the offer blocks any remote read/update.
h=setup();h:offer();h.a.buffer:replace(0,0,'local');h.a.dirty=true;count=h.calls;h.s:update_local(h.ctx)
check(h.calls==count and h.files['ideas.md']==OLD and h.a.buffer:text()~=OLD,'dirty editor blocks offered replacement before network')
-- Remote SHA drift after confirmation never replaces local contents.
h=setup();h:offer();h.s:update_local(h.ctx);h:read('newer remote',F.RACE)
check(h.files['ideas.md']==OLD and h.a.buffer:text()==OLD and h.public_writes==0,'remote change between offer and update fails closed')
-- Existing divergent recovery is protected, even if the editor itself is clean.
h=setup();h:offer();h.private.files['recovery.txt']='INKWRITE1\nother.md\nunsaved other writing';h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']==OLD and h.public_writes==0 and h.private.files['recovery.txt']:find('unsaved other writing',1,true),'unrelated recovery cannot be overwritten by remote update')
for _,flag in ipairs({'fail_backup','fail_recovery','fail_main'})do
 h=setup();h:offer();h[flag]=true;h.s:update_local(h.ctx);h:read(NEW,F.NEW)
 check(h.files['ideas.md']==OLD and h.a.buffer:text()==OLD and h.s.file_status~='Up to date at last sync','storage failure preserves open document: '..flag)
 m=assert(Store.load(h.ctx,Host.config().scope,Mock.hash));check(m.documents['ideas.md'].remote_blob_sha==F.OLD,'failed update retains old checkpoint')
end
h=setup();h:offer();h.race_after_recovery=true;h.s:update_local(h.ctx);h:read(NEW,F.NEW)
check(h.files['ideas.md']=='External concurrent edit'and h.a.buffer:text()==OLD and h.files['before-sync-001.md']==OLD,'final prewrite check protects external SD edits')
h=setup();h:offer();h.s:update_local(h.ctx);h:verify(h.s);h.s:pause(h.ctx);count=h.public_writes
check(not h.s.busy and h.public_writes==count and h.files['ideas.md']==OLD,'pause cancels remote update before local writes')
-- Both sides changed: remain in copy-based conflict flow, never offer replace.
h=setup();h.a.buffer:replace(0,0,'Local change ');h.a.dirty=true;h.s:sync(h.ctx);h:read(NEW,F.NEW)
check(h.s.conflict and not h.s.pending_update and h.a.buffer:text()~=NEW,'both-changed conflict keeps conservative copy choices')
-- Record write after local update is separate from successful SD protection.
h=setup();h:offer();h.s:update_local(h.ctx);h.private.fail_write=true
-- Recovery must succeed; fail only the sync checkpoint.
local write=h.ctx.storage.write
h.ctx.storage.write=function(self,name,t)if name==Store.FILE then return nil,'io_error'end;local old=h.private.fail_write;h.private.fail_write=false;local a,b=write(self,name,t);h.private.fail_write=old;return a,b end
h:read(NEW,F.NEW)
check(h.files['ideas.md']==NEW and h.files['before-sync-001.md']==OLD and h.s.notice:find('record not saved',1,true),'metadata failure does not undo verified local update or lose backup')
return n
