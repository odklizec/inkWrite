-- Explicit, bounded private storage adapter. No automatic load/save or migration.
local Sync=require('domain.sync')
local M={FILE='github-sync.json',MAX_BYTES=65536,SCHEMA=1}
local function call(obj,method,...)
  if obj==nil then return nil,'unavailable'end
  local got,fn=pcall(function()return obj[method]end)
  if not got or type(fn)~='function'then return nil,'unavailable'end
  local ok,a,b=pcall(fn,obj,...)
  if ok then return a,b end
  return nil,'host_exception'
end
local function same_scope(a,b)return a.repo==b.repo and a.branch==b.branch end
function M.empty(scope)
  if not Sync.scope_ok(scope)then return nil,'invalid_scope'end
  return {schema_version=1,repo=scope.repo,branch=scope.branch,documents={}}
end
function M.validate(value,scope)
  if not Sync.scope_ok(scope)then return nil,'invalid_scope'end
  if not Sync.fields(value,{schema_version=true,repo=true,branch=true,documents=true})then return nil,'invalid_metadata'end
  if value.schema_version~=1 then return nil,'unsupported_schema'end
  if not same_scope(value,scope)then return nil,'scope_mismatch'end
  if type(value.documents)~='table'then return nil,'invalid_metadata'end
  local clean=M.empty(scope);local names={};local n=0
  for name,r in pairs(value.documents)do
    n=n+1;if n>Sync.MAX_RECORDS then return nil,'metadata_full'end
    if not Sync.record_ok(name,r)or names[name:lower()]then return nil,'invalid_metadata'end
    names[name:lower()]=true
    clean.documents[name]={remote_path=r.remote_path,remote_blob_sha=r.remote_blob_sha,last_synced_local_fingerprint=r.last_synced_local_fingerprint}
  end
  return clean
end
local function decode(ctx,raw,scope,hash)
  if type(raw)~='string'or #raw>M.MAX_BYTES then return nil,'metadata_too_large'end
  local envelope=call(ctx.json,'decode',raw)
  if not Sync.fields(envelope,{format=true,payload=true,checksum=true})or envelope.format~='inkwrite-sync-1'
    or type(envelope.payload)~='string'or #envelope.payload>M.MAX_BYTES
    or not Sync.hex_ok(envelope.checksum,64)then return nil,'invalid_envelope'end
  local checksum=Sync.digest(hash,envelope.payload)
  if not checksum or checksum~=envelope.checksum then return nil,'checksum_mismatch'end
  local value=call(ctx.json,'decode',envelope.payload)
  return M.validate(value,scope)
end
function M.load(ctx,scope,hash,file)
  file=file or M.FILE
  if not Sync.scope_ok(scope)then return nil,'invalid_scope'end
  local size,err=call(ctx.storage,'size',file)
  if size==nil then
    if err=='not_found'then return M.empty(scope),false end
    return nil,'metadata_read_failed'
  end
  if type(size)~='number'or size<0 or size>M.MAX_BYTES then return nil,'metadata_too_large'end
  local raw=call(ctx.storage,'read',file)
  if type(raw)~='string'or #raw~=size then return nil,'metadata_read_failed'end
  local clean,why=decode(ctx,raw,scope,hash)
  if not clean then return nil,why end
  return clean,raw
end
function M.save(ctx,value,scope,hash,expected,file)
  file=file or M.FILE
  if expected~=false and type(expected)~='string'then return nil,'expected_revision_required'end
  local clean,err=M.validate(value,scope);if not clean then return nil,err end
  local old,raw=M.load(ctx,scope,hash,file);if not old then return nil,raw end
  if raw~=expected then return nil,'metadata_changed'end
  local payload=call(ctx.json,'encode',clean)
  if type(payload)~='string'or #payload>M.MAX_BYTES then return nil,'metadata_encode_failed'end
  local checksum=Sync.digest(hash,payload);if not checksum then return nil,'fingerprint_failed'end
  local encoded=call(ctx.json,'encode',{format='inkwrite-sync-1',payload=payload,checksum=checksum})
  if type(encoded)~='string'or #encoded>M.MAX_BYTES then return nil,'metadata_too_large'end
  if not call(ctx.storage,'write',file,encoded)then return nil,'metadata_write_failed'end
  local verified=call(ctx.storage,'read',file)
  if verified~=encoded then return nil,'metadata_verify_failed'end
  return clean,encoded
end
-- Copy-on-write: failed persistence leaves the caller's checkpoint unchanged.
function M.checkpoint(value,name,record,scope)
  local clean,err=M.validate(value,scope);if not clean then return nil,err end
  if not Sync.record_ok(name,record)then return nil,'invalid_record'end
  clean.documents[name]=record
  return M.validate(clean,scope)
end
function M.for_config(config)
  local file=config.profile and ('gh'..config.profile..'-'..M.FILE)or M.FILE
  return {checkpoint=M.checkpoint,
    load=function(c,scope,hash)return M.load(c,scope,hash,file)end,
    save=function(c,v,scope,hash,expected)return M.save(c,v,scope,hash,expected,file)end}
end
return M
