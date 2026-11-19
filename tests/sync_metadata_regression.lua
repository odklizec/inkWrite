local Sync=require('domain.sync')
local Store=require('domain.sync_metadata')
local Mock=require('tests.support.sync_mock')
local Native=require('test_native')
local F=require('tests.fixtures.github_contents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local scope={repo='example/inkwrite-docs',branch='main'}
local hash=Mock.hash
local r={remote_path='documents/ideas.md',remote_blob_sha=F.OLD,last_synced_local_fingerprint=hash('saved ž\r\n')}
local h=Mock.host()
local value,raw=Store.load(h.ctx,scope,hash)
check(value.schema_version==1 and raw==false and h.writes==0,'absent metadata initializes without a write')
local changed=assert(Store.checkpoint(value,'ideas.md',r,scope))
check(value.documents['ideas.md']==nil,'copy-on-write checkpoint')
local persisted,next_raw=Store.save(h.ctx,changed,scope,hash,raw)
check(persisted and type(next_raw)=='string' and h.writes==1,'first atomic metadata write')
local loaded,loaded_raw=Store.load(h.ctx,scope,hash)
check(loaded_raw==next_raw and loaded.documents['ideas.md'].remote_blob_sha==F.OLD,'roundtrip')
check(Store.save(h.ctx,changed,scope,hash,false)==nil and h.writes==1,'stale absent revision cannot overwrite')
check(Store.save(h.ctx,changed,scope,hash,nil)==nil,'blind save disallowed')
-- Failures before write preserve old bytes and caller state.
h.fail_write=true
local newrecord={remote_path=r.remote_path,remote_blob_sha=F.NEW,last_synced_local_fingerprint=hash('new')}
local pending=assert(Store.checkpoint(loaded,'ideas.md',newrecord,scope))
check(Store.save(h.ctx,pending,scope,hash,next_raw)==nil,'storage failure visible')
check(h.files[Store.FILE]==next_raw and loaded.documents['ideas.md'].remote_blob_sha==F.OLD,'failed write retains original checkpoint')
h.fail_write=false;h.throw_write=true
check(Store.save(h.ctx,pending,scope,hash,next_raw)==nil and h.files[Store.FILE]==next_raw,'write exception fail closed')
h.throw_write=false;h.fail_read=true
check(Store.load(h.ctx,scope,hash)==nil,'SD read error is not empty metadata')
h.fail_read=false;h.throw_read=true
check(Store.load(h.ctx,scope,hash)==nil,'read exception contained')
h.throw_read=false
-- Lost response after commit: do not acknowledge success, re-load committed snapshot.
h.fail_after_commit=true
check(Store.save(h.ctx,pending,scope,hash,next_raw)==nil,'lost metadata acknowledgement')
h.fail_after_commit=false
loaded,raw=Store.load(h.ctx,scope,hash)
check(loaded.documents['ideas.md'].remote_blob_sha==F.NEW,'complete committed record survives reload')
-- A corrupt post-write read never returns a successful checkpoint.
h.corrupt_write=true
check(Store.save(h.ctx,pending,scope,hash,raw)==nil,'read-back verification rejects corrupt write')
h.corrupt_write=false
local writes=h.writes
check(Store.load(h.ctx,scope,hash)==nil and h.writes==writes,'corrupt metadata preserved')
check(Store.save(h.ctx,Store.empty(scope),scope,hash,'broken')==nil and h.writes==writes,'cannot reset corruption by saving empty metadata')
local function envelope(v)
 local payload=Native.encode(v)
 return Native.encode({format='inkwrite-sync-1',payload=payload,checksum=hash(payload)})
end
local function refused(v,message)
 h.files[Store.FILE]=envelope(v);local before=h.files[Store.FILE];local count=h.writes
 check(Store.load(h.ctx,scope,hash)==nil,message)
 check(Store.save(h.ctx,Store.empty(scope),scope,hash,before)==nil and h.files[Store.FILE]==before and h.writes==count,'invalid metadata never overwritten')
end
refused({schema_version=2,repo=scope.repo,branch=scope.branch,documents={}},'future schema preserved')
refused({schema_version=0,repo=scope.repo,branch=scope.branch,documents={}},'unknown legacy schema not guessed')
refused({schema_version=1,repo='another/repo',branch='main',documents={}},'repository binding')
refused({schema_version=1,repo=scope.repo,branch='other',documents={}},'branch binding')
refused({schema_version=1,repo=scope.repo,branch='main',documents={},token='do not store'},'unknown/secret fields rejected')
local malformed=Store.empty(scope);malformed.documents['ideas.md']={remote_path='../ideas.md',remote_blob_sha=F.OLD,last_synced_local_fingerprint=hash('x')}
refused(malformed,'traversal metadata rejected')
malformed=Store.empty(scope);malformed.documents['ideas.md']=r;malformed.documents['IDEAS.md']={remote_path='documents/IDEAS.md',remote_blob_sha=F.OLD,last_synced_local_fingerprint=r.last_synced_local_fingerprint}
refused(malformed,'case-insensitive duplicate filename')
malformed=Store.empty(scope)
for i=1,65 do local name='page-'..i..'.md';malformed.documents[name]={remote_path='documents/'..name,remote_blob_sha=F.OLD,last_synced_local_fingerprint=r.last_synced_local_fingerprint}end
refused(malformed,'collection cap')
malformed.documents['page-65.md']=nil;check(Store.validate(malformed,scope)~=nil,'64 records accepted')
local good=Store.empty(scope);good.documents['ideas.md']=r
h.files[Store.FILE]=envelope(good)
local env=Native.decode(h.files[Store.FILE]);env.checksum=string.rep('0',64);h.files[Store.FILE]=Native.encode(env)
check(Store.load(h.ctx,scope,hash)==nil,'checksum mismatch, even when JSON shape is valid')
h.files[Store.FILE]=string.rep('x',65537);local reads=h.reads
check(Store.load(h.ctx,scope,hash)==nil and h.reads==reads,'oversized metadata rejected before read/decode')
for _,s in ipairs({{repo='x/y/z',branch='main'},{repo='x/..',branch='main'},{repo='x/y',branch='../main'},{repo='x/y',branch='main.lock'},{repo='x/y',branch='a//b'}})do
 check(Store.empty(s)==nil,'invalid scope refused')
end
-- Crash after imported local bytes but before metadata: untracked different bytes conflict.
local p=assert(Sync.decide('download',{name='ideas.md',revision=0,exists=true,saved=true,bytes='local copy'},
 {exists=true,sha=F.NEW,bytes='different remote'},nil,hash))
check(p.action=='conflict','missing checkpoint never authorizes overwrite')
return n
