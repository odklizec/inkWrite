local Session=require('domain.sync_session')
local Auth=require('domain.sync_auth')
local Store=require('domain.sync_metadata')
local Docs=require('domain.documents')
local Payload=require('domain.github_payload')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local F=require('tests.fixtures.github_contents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function setup()
 local h=Host.new();local private=Mock.host();h.ctx.storage=private.ctx.storage
 h.ctx.state.github_sync_enabled=true;h.ctx.invalidate=function()end
 h.ctx.random={uuid=function()return '12345678-abcd-abcd-abcd-123456789012'end}
 local files={['ideas.md']='Čaj\r\n\n'};h.files=files;h.private=private
 h.ctx.files={size=function(_,name)local v=files[name:lower()];return v and #v or nil,v and nil or 'not_found'end,
 read=function(_,name,a,b)local v=files[name:lower()];return v and v:sub(a+1,a+b)or nil,v and nil or 'not_found'end,
 write=function(_,name,v)if h.fail_sd then return nil,'io_error'end;files[name:lower()]=v;return true end}
 local identity={};h.snapshot={name='ideas.md',bytes=files['ideas.md'],saved=true,exists=true,revision=1,identity=identity}
 local auth
 local s=Session.new({snapshot=function(_,save_first)
   if h.unsaved or files[h.snapshot.name]~=h.snapshot.bytes then return nil end
   if save_first then h.save_calls=(h.save_calls or 0)+1 end
   local v={};for k,x in pairs(h.snapshot)do v[k]=x end;return v
 end,reserved_name=function()return h.snapshot.name end,can_import=function()return not h.protected end},
 {config=Host.config(),primitives={hash=Mock.hash,codec=Mock.codec},auth_factory=function(c,p)auth=assert(Auth.new(c,p));return auth end})
 s:connect(h.ctx);h:respond(Host.code());h.time=5000;s:poll(h.ctx);h:respond(Host.token());h:verify(auth)
 check(s:status(h.ctx).connected,'actual auth/transport connected with synthetic fixtures')
 h.auth=auth;h.session=s
 function h:read(remote,status)self:verify(auth);self:respond(remote,status)end
 function h:written(name,bytes,sha)
   self:verify(auth)
   check(self.options.method=='PUT','writes use HTTPS PUT')
   local body=self.ctx.json:decode(self.options.body)
   check(Mock.codec.decode(body.content)==bytes and body.branch=='main','exact bytes and explicit branch in PUT')
   self:respond({content={type='file',path='documents/'..name,sha=sha or F.NEW}},201)
 end
 return s,h
end
local s,h=setup();s:upload(h.ctx);h:read({},404)
check(h.save_calls==1,'explicit upload captures saved document')
h:written('ideas.md',h.snapshot.bytes)
local metadata=assert(Store.load(h.ctx,Host.config().scope,Mock.hash))
check(metadata.documents['ideas.md'].remote_blob_sha==F.NEW and not s.busy,'verified upload checkpoints blob SHA')
local calls=h.calls;s:upload(h.ctx);h:read(F.file('ideas.md',h.snapshot.bytes,F.NEW))
check(h.calls==calls+6 and not s.busy,'unchanged upload has no PUT or duplicate commit')
h.snapshot.bytes='Changed ž\r\n';h.snapshot.revision=2;h.files['ideas.md']=h.snapshot.bytes
s:upload(h.ctx);h:read(F.file('ideas.md','Čaj\r\n\n',F.NEW));h:written('ideas.md',h.snapshot.bytes,F.OLD)
check(s.notice:find('Uploaded and verified',1,true),'local-only change uploads after SHA precondition')
s:upload(h.ctx);h:read(F.file('ideas.md','Remote change',F.NEW))
check(s.conflict and not s.busy and h.options.method=='GET','remote change becomes conflict without PUT')
local original=h.files['ideas.md'];h.private.files['recovery.txt']='recovery preserved'
s:download(h.ctx,s.conflict);h:read(F.file('ideas.md','Remote change',F.NEW))
check(h.files['ideas.md']==original and h.files['download-001.md']=='Remote change','conflict import preserves both originals')
check(h.private.files['recovery.txt']=='recovery preserved','import leaves recovery untouched')
-- Freshly listed SHA is required again at download time.
s:download(h.ctx,{name='other.md',sha=F.NEW});h:read(F.file('other.md','changed',F.OLD))
check(h.files['other.md']==nil and not s.busy,'remote change between list and read fails closed')
s:download(h.ctx,{name='other.md',sha=F.NEW});h:read(F.file('other.md','Pôvodný\r\n',F.NEW))
check(h.files['other.md']=='Pôvodný\r\n','new basename preserves exact accented UTF8 and CRLF')
metadata=assert(Store.load(h.ctx,Host.config().scope,Mock.hash))
check(metadata.documents['other.md'].remote_blob_sha==F.NEW,'new original basename owns its checkpoint')
-- Imports never steal the active-but-absent local filename.
h.files['ideas.md']=nil
check(Docs.import_copy(h.ctx,'ideas.md','remote','download-002.md')=='ideas.md','unreserved absent target available')
check(Docs.import_copy(h.ctx,'ideas.md','remote','download-002.md')=='download-003.md','allocator excludes reserved filename as well as existing copies')
h.fail_sd=true;s:download(h.ctx,{name='failure.md',sha=F.NEW});h:read(F.file('failure.md','x',F.NEW))
check(h.files['failure.md']==nil and not s.busy,'SD failure never marks download complete')
h.fail_sd=false;h.protected=true;calls=h.calls;s:download(h.ctx,{name='failure.md',sha=F.NEW})
check(h.calls==calls,'protected recovery blocks imports before networking')
-- Local source changes during the PUT preflight: prevent the PUT itself.
s,h=setup();s:upload(h.ctx);h:read({},404);h.files['ideas.md']='External edit';h:verify(h.auth)
check(h.options.method=='GET'and not s.busy and h.private.writes==0,'external source change before PUT prevents remote commit')
s,h=setup();s:upload(h.ctx);h:read({},404);h.private.fail_write=true;h:written('ideas.md',h.snapshot.bytes)
check(s.notice:find('record not saved',1,true)and h.files['ideas.md']==h.snapshot.bytes,'remote success plus metadata failure is explicit; local save stays authoritative')
-- Recheck after uncertain completion recognizes matching remote bytes without PUT.
h.private.fail_write=false;s:upload(h.ctx);h:read(F.file('ideas.md',h.snapshot.bytes,F.NEW))
check(s.notice:find('Uploaded and verified',1,true),'retry after uncheckpointed commit can adopt exact matching remote')
s,h=setup();s:upload(h.ctx);h:verify(h.auth)
local replay=h:respond({},404);s:disconnect(h.ctx);local count=h.calls;replay()
check(h.calls==count and not s.busy and h.private.writes==0,'late callback after cancellation cannot write or checkpoint')
s,h=setup();h.unsaved=true;calls=h.calls;s:upload(h.ctx)
check(h.calls==calls and not s.busy,'failed local save prevents network operation')
s,h=setup();h.private.files[Store.FILE]='broken';calls=h.calls;s:upload(h.ctx)
check(h.calls==calls and h.private.files[Store.FILE]=='broken','corrupt metadata preserved and upload refused')
-- NEW remote copy never overwrites or aliases the original checkpoint.
s,h=setup();s:upload(h.ctx,true);h:read({},404)
local newname='local-12345678-abcd-abcd-abcd-123456789012.md'
h:written(newname,h.snapshot.bytes)
check(h.private.writes==0 and h.files['ideas.md']==h.snapshot.bytes,'upload-as-new preserves original local and checkpoint')
-- List through actual auth -> tree -> folder -> validated filename rows.
s,h=setup();s:browse(h.ctx);h:verify(h.auth)
check(h.options.url:find('/git/trees/main',1,true)and not h.options.url:find('recursive',1,true),'nonrecursive root tree request')
h:respond({sha=F.OLD,truncated=false,tree={{path='documents',type='tree',mode='040000',sha=F.NEW}}})
h:respond({sha=F.NEW,truncated=false,tree={{path='Ž.txt',type='blob',mode='100644',sha=F.OLD,size=3},{path='link.md',type='blob',mode='120000',sha=F.OLD,size=3}}})
check(#s.rows==1 and s.rows[1].name=='Ž.txt'and not s.busy,'bounded list ignores symbolic links')
local tree={sha=F.NEW,truncated=false,tree={{path='A.md',type='blob',mode='100644',sha=F.OLD,size=0},{path='a.md',type='blob',mode='100644',sha=F.OLD,size=0}}}
check(Payload.directory(tree)==nil,'case-insensitive duplicate remote basenames refused')
tree.tree={};tree.truncated=true;check(Payload.directory(tree)==nil,'truncated lists refused')
tree.truncated=false;tree.tree[2]={};check(Payload.directory(tree)==nil,'sparse tree refused')
return n
