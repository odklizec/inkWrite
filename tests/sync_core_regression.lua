local Sync=require('domain.sync')
local API=require('domain.github_payload')
local Mock=require('tests.support.sync_mock')
local F=require('tests.fixtures.github_contents')
local Native=require('test_native')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local hash=Mock.hash
local scope={repo='example/inkwrite-docs',branch='main'}
local old='Žluťoučký kůň\r\nč š ž á\r\n'
local newer=old..'local change\n'
local remote_bytes=old..'remote change\n'
local function file(bytes,name,revision)return {exists=true,saved=true,name=name or 'ideas.md',revision=revision or 7,bytes=bytes}end
local function absent(name)return {exists=false,name=name or 'ideas.md',revision=0}end
local function remote(bytes,sha)return {exists=true,bytes=bytes,sha=sha or F.OLD}end
local missing={exists=false}
local record={remote_path='documents/ideas.md',remote_blob_sha=F.OLD,last_synced_local_fingerprint=hash(old)}
check(hash('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','test primitive is SHA256')
check(hash('a\r\n')~=hash('a\n'),'fingerprint preserves line endings')
local cases={
 {'upload',file(old),missing,nil,'create'},
 {'upload',file(old),remote(old),nil,'mark_synced'},
 {'upload',file(newer),remote(old),record,'update'},
 {'upload',file(old),remote(remote_bytes,F.NEW),record,'conflict','remote_changed'},
 {'upload',file(newer),remote(remote_bytes,F.NEW),record,'conflict','both_changed'},
 {'upload',file(old),missing,record,'conflict','remote_deleted'},
 {'upload',file(newer,'renamed.md'),missing,nil,'create'},
 {'upload',absent(),remote(old),record,'local_missing'},
 {'upload',file(newer),remote(remote_bytes),nil,'conflict','untracked_remote'},
 {'download',absent(),remote(old),nil,'download_copy'},
 {'download',file(old),remote(old),record,'mark_synced'},
 {'download',file(old),remote(remote_bytes,F.NEW),record,'download_copy'},
 {'download',file(newer),remote(old),record,'conflict','local_changed'},
 {'download',file(newer),remote(remote_bytes,F.NEW),record,'conflict','both_changed'},
 {'download',file(old),missing,record,'remote_missing'},
 {'download',file(old),remote(remote_bytes),nil,'conflict','untracked_local'},
 {'upload',file(old),remote(remote_bytes),record,'conflict','metadata_inconsistent'},
}
for i,c in ipairs(cases)do
 local p=assert(Sync.decide(c[1],c[2],c[3],c[4],hash))
 check(p.action==c[5] and p.reason==c[6],'decision matrix '..i)
 check(p.action~='delete' and p.action~='replace','no destructive intents')
end
for _,name in ipairs({'../secret.md','a/secret.md','C:\\secret.txt','a..md','NUL.txt','notes.pdf','/x.md','a\0.md'})do
 check(not Sync.name_ok(name),'unsafe filename rejected')
end
for _,bytes in ipairs({string.rep('x',32769),'bad\0text','\255'})do
 check(Sync.decide('upload',file(bytes),missing,nil,hash)==nil,'invalid local bytes rejected')
 check(Sync.decide('download',absent(),remote(bytes),nil,hash)==nil,'invalid remote bytes rejected')
end
local unsaved=file(old);unsaved.saved=false
check(Sync.decide('upload',unsaved,missing,nil,hash)==nil,'unsaved buffer refused')
check(Sync.decide('upload',file(old),missing,{remote_blob_sha=F.OLD},hash)==nil,'corrupt metadata fails closed')
check(Sync.decide('upload',file(old),missing,nil,function()return 'weak'end)==nil,'weak or failed hash refused')
check(Sync.decide('upload',file(old),missing,nil,function()error('private body')end)==nil,'hash exception contained')
local core=Sync.new(hash)
check(core.state=='disabled' and core:begin('upload',file(old))==nil,'default disabled')
core:configure(true,false);check(core.state=='disconnected','disconnected')
core:configure(true,true)
local id,fetch=core:begin('upload',file(newer))
check(core.state=='checking' and fetch.path=='documents/ideas.md','begin bounded check')
check(core:begin('upload',file(old))==nil,'single operation')
local p=core:checked(id,remote(old),record)
check(p.action=='update' and p.sha==F.OLD and core.state=='uploading','blob SHA precondition')
p.path='documents/other.md' -- Public action is a copy of internal state.
local receipt={ok=true,status=200,path='documents/ideas.md',sha=F.NEW,fingerprint=hash(newer)}
local cp=assert(core:finish(id,receipt,file(newer)))
check(cp.action=='checkpoint' and cp.record.remote_blob_sha==F.NEW and cp.record.last_synced_local_fingerprint==hash(newer),'verified upload checkpoint')
check(core:finish(id,receipt,file(newer))==nil,'duplicate response ignored')
-- Late callbacks and changes during request cannot certify new bytes.
id=core:begin('upload',file(newer));core:checked(id,remote(old),record)
local changed=file(newer..' typing',nil,8)
check(core:finish(id,receipt,changed)==nil and core.state=='idle','local edit remains pending')
id=core:begin('upload',file(newer));core:checked(id,remote(old),record)
check(core:finish(id,receipt,file(newer,'other.md'))==nil,'document switch ignored')
id=core:begin('upload',file(newer));core:cancel();local next_id=core:begin('upload',file(old))
check(core:checked(id,remote(old),record)==nil and core.state=='checking','stale callback cannot affect new operation')
core:configure(false,false)
check(core:checked(next_id,remote(old),record)==nil and core.state=='disabled','disable cancels operation')
for _,c in ipairs({{401,'auth_required'},{403,'auth_required'},{409,'conflict'},{422,'conflict'},{429,'error'},{500,'error'}})do
 core:configure(true,true);id=core:begin('upload',file(old));core:failed(id,c[1],'private response')
 check(core.state==c[2] and core.reason~='private response','HTTP failure classification '..c[1])
end
for _,err in ipairs({'no_network','timeout','io_error'})do
 core:configure(true,true);id=core:begin('upload',file(old));core:failed(id,nil,err)
 check(core.state=='offline','offline classification')
end
-- New local copy verification; never mark the source synced after importing elsewhere.
core:configure(true,true);id=core:begin('download',absent());core:checked(id,remote(old),nil)
local imported={ok=true,new_copy=true,verified=true,name='ideas.md',sha=F.OLD,bytes=old}
cp=assert(core:finish(id,imported,file(old,nil,0)));check(cp.record.last_synced_local_fingerprint==hash(old),'verified first import checkpoint')
id=core:begin('download',absent());core:checked(id,remote(old),nil)
check(core:finish(id,imported,absent())==nil,'missing post-import file cannot checkpoint')
id=core:begin('download',absent());core:checked(id,remote(old),nil)
check(core:finish(id,imported,file('another writer',nil,0))==nil,'new import changed again cannot checkpoint')
id=core:begin('download',file(old));core:checked(id,remote(remote_bytes,F.NEW),record)
imported.name='remote-copy.md';imported.sha=F.NEW;imported.bytes=remote_bytes
cp=assert(core:finish(id,imported,file(old)));check(cp.action=='imported_copy' and cp.record==nil,'copy does not mark original synced')
id=core:begin('download',file(old));core:checked(id,remote(remote_bytes,F.NEW),record)
imported.name='ideas.md'
check(core:finish(id,imported,file(old))==nil,'same-name existing import refused')
id=core:begin('download',absent());core:checked(id,remote(old),nil);imported.verified=false
check(core:finish(id,imported,file(old,nil,0))==nil,'unverified import refused')
-- Actual JSON/base64 Contents fixtures, including encoding edge cases.
for _,bytes in ipairs({'','a','ab','abc',old,string.rep('x',32768)})do
 local payload=Native.decode(Native.encode(F.file('ideas.md',bytes)))
 local r=assert(API.read(200,payload,'documents/ideas.md',Mock.codec))
 check(r.bytes==bytes and r.sha==F.OLD,'exact fixture bytes')
 local req=assert(API.write_request(scope,'documents/ideas.md',bytes,F.OLD,Mock.codec))
 check(req.body.sha==F.OLD and Native.base64_decode(req.body.content)==bytes,'exact update request')
end
local payload=F.file('ideas.md',old);payload.content=payload.content:sub(1,8)..'\n'..payload.content:sub(9)
check(API.read(200,payload,'documents/ideas.md',Mock.codec)~=nil,'GitHub base64 line wrapping')
for _,patch in ipairs({{size=32769},{size=-1},{type='dir'},{path='documents/other.md'},{sha='commit'},{encoding='none'},
 {content='A==='},{content='!!!!'},{content='YQ==ignored'},{content='YQ==',size=2},
 {content=Native.base64_encode('\255'),size=1},{content=Native.base64_encode('x\0'),size=2}})do
 local bad=F.file('ideas.md',old);for k,v in pairs(patch)do bad[k]=v end
 check(API.read(200,bad,'documents/ideas.md',Mock.codec)==nil,'reject malformed content boundary')
end
check(API.read(404,nil,'documents/ideas.md',Mock.codec).exists==false,'404 is absent observation')
for code in pairs(F.errors)do check(API.read(code,F.errors[code],'documents/ideas.md',Mock.codec)==nil,'HTTP errors are not content')end
check(API.write_request(scope,'documents/../bad.md',old,nil,Mock.codec)==nil,'write traversal refused')
check(API.write_request(scope,'documents/ideas.md',old,nil,Mock.codec).body.sha==nil,'first create has no SHA')
local written=assert(API.written(201,F.written('documents/ideas.md'),'documents/ideas.md',hash(newer)))
check(written.sha==F.NEW,'write response takes content blob SHA')
check(API.written(200,{commit={sha=F.NEW}},'documents/ideas.md',hash(newer))==nil,'commit-only response refused')
check(API.written(200,F.written('documents/other.md'),'documents/ideas.md',hash(newer))==nil,'write response bound to path')
check(API.written(409,F.errors[409],'documents/ideas.md',hash(newer))==nil,'racing update has no success receipt')
-- Mock transport: lost write response/crash -> re-fetch equal bytes, no duplicate PUT.
local t=Mock.transport();core:configure(true,true);id=core:begin('upload',file(newer))
local fetched
t:request({method='GET',path='documents/ideas.md'},function(status,body)fetched=assert(API.read(status,body,'documents/ideas.md',Mock.codec))end)
t:respond(200,F.file('ideas.md',old))
p=core:checked(id,fetched,record)
local request=assert(API.write_request(scope,p.path,newer,p.sha,Mock.codec))
t:request(request,function()end);t:respond(200,F.written(p.path)) -- remote succeeds; caller crashes before checkpoint
core=Sync.new(hash);core:configure(true,true);id=core:begin('upload',file(newer))
p=core:checked(id,remote(newer,F.NEW),record)
check(p.action=='mark_synced' and t.calls==2,'crash reconciliation avoids duplicate commit')
cp=core:finish(id,{ok=true,sha=F.NEW},file(newer));check(cp.record.remote_blob_sha==F.NEW,'reconciled blob SHA, not commit SHA')
for i=1,12 do t:request({method='GET',path='documents/ideas.md'},function()end);t:respond(404,nil)end
check(#t.history==8,'mock history bounded')
return n
