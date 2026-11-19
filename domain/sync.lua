-- Phase 1: pure decisions and operation guards. Not imported by the editor.
local Buffer=require('domain.buffer')
local Docs=require('domain.documents')
local M={MAX_DOCUMENT=32768,MAX_RECORDS=64}
local function fields(t,allowed)
  if type(t)~='table' then return false end
  local n=0
  for k in pairs(t)do n=n+1;if n>16 or not allowed[k]then return false end end
  return true
end
M.fields=fields
function M.name_ok(name)
  return Docs.name_ok(name) and not name:find('..',1,true)
end
function M.path_ok(path)
  return type(path)=='string' and path:sub(1,10)=='documents/' and M.name_ok(path:sub(11))
end
function M.text_ok(text)return type(text)=='string' and #text<=M.MAX_DOCUMENT and Buffer.valid(text)end
function M.hex_ok(s,n)return type(s)=='string' and #s==n and not s:find('[^0-9a-f]')end
function M.scope_ok(scope)
  if not fields(scope,{repo=true,branch=true})then return false end
  local owner,repo
  if type(scope.repo)=='string'then owner,repo=scope.repo:match('^([%w-]+)/([%w_.-]+)$')end
  local branch=scope.branch
  return owner~=nil and #owner<=39 and #repo<=100 and repo~='.' and repo~='..'
    and type(branch)=='string' and #branch>0 and #branch<=128
    and not branch:find('[^%w_./-]') and not branch:find('..',1,true)
    and not branch:find('//',1,true) and not branch:find('/%.')
    and branch:sub(1,1)~='/' and branch:sub(1,1)~='.' and branch:sub(1,1)~='-'
    and branch:sub(-1)~='/' and branch:sub(-1)~='.' and branch:sub(-5)~='.lock'
end
function M.record_ok(name,r)
  return M.name_ok(name) and fields(r,{remote_path=true,remote_blob_sha=true,last_synced_local_fingerprint=true})
    and r.remote_path=='documents/'..name and M.hex_ok(r.remote_blob_sha,40)
    and M.hex_ok(r.last_synced_local_fingerprint,64)
end
local function snapshot_ok(s)
  if type(s)~='table' or not M.name_ok(s.name) or type(s.revision)~='number'
    or s.revision%1~=0 or s.revision<0 or s.revision>2147483647 then return false end
  return (s.exists==false and s.bytes==nil) or (s.exists==true and s.saved==true and M.text_ok(s.bytes))
end
local function digest(hash,bytes)
  if type(hash)~='function'then return nil end
  local ok,value=pcall(hash,bytes)
  if ok and M.hex_ok(value,64)then return value end
end
M.digest=digest
function M.remote_ok(r)
  return type(r)=='table' and ((r.exists==false and r.sha==nil and r.bytes==nil)
    or (r.exists==true and M.hex_ok(r.sha,40) and M.text_ok(r.bytes)))
end
function M.decide(direction,local_file,remote,record,hash)
  if direction~='upload' and direction~='download'then return nil,'invalid_direction'end
  if not snapshot_ok(local_file)then return nil,'unsaved_or_invalid_local'end
  if not M.remote_ok(remote)then return nil,'invalid_remote'end
  if record~=nil and not M.record_ok(local_file.name,record)then return nil,'invalid_metadata'end
  local path='documents/'..local_file.name
  local function plan(action,reason,fp)
    return {action=action,reason=reason,path=path,sha=remote.sha,fingerprint=fp}
  end
  local fp=local_file.exists and digest(hash,local_file.bytes)or nil
  if local_file.exists and not fp then return nil,'fingerprint_failed'end
  if local_file.exists and remote.exists and local_file.bytes==remote.bytes then return plan('mark_synced',nil,fp)end
  if direction=='upload'then
    if not local_file.exists then return plan('local_missing')end
    if not remote.exists then
      if record then return plan('conflict','remote_deleted')end
      return plan('create',nil,fp)
    end
    if not record then return plan('conflict','untracked_remote')end
    local lc=fp~=record.last_synced_local_fingerprint
    local rc=remote.sha~=record.remote_blob_sha
    if rc then return plan('conflict',lc and 'both_changed' or 'remote_changed')end
    if not lc then return plan('conflict','metadata_inconsistent')end
    return plan('update',nil,fp)
  end
  if not remote.exists then return plan('remote_missing')end
  if not local_file.exists then return plan('download_copy')end
  if not record then return plan('conflict','untracked_local')end
  if fp~=record.last_synced_local_fingerprint then
    return plan('conflict',remote.sha~=record.remote_blob_sha and 'both_changed' or 'local_changed')
  end
  if remote.sha==record.remote_blob_sha then return plan('conflict','metadata_inconsistent')end
  return plan('download_copy') -- Never a replace/delete instruction.
end
-- A single manual Sync may offer a protected remote-only local update.
function M.reconcile(file,remote,record,hash)
  local plan,err=M.decide('upload',file,remote,record,hash)
  if plan and plan.action=='conflict'and plan.reason=='remote_changed'then
    plan.action='update_local';plan.reason=nil;plan.fingerprint=record.last_synced_local_fingerprint
  end
  return plan,err
end
function M.error_state(status,err)
  if status==401 or status==403 then return 'auth_required','authorization_required'end
  if status==409 or status==422 then return 'conflict','remote_race'end
  if err=='no_network' or err=='timeout' or err=='io_error'then return 'offline',err end
  if status==429 then return 'error','rate_limited'end
  return 'error','request_failed' -- Never echo body, headers or exception text.
end
function M.new(hash)
  local s={state='disabled'}
  local enabled,authenticated=false,false
  local serial,active=0,nil
  function s:configure(on,auth)
    serial=serial+1;active=nil;enabled=on==true;authenticated=auth==true
    self.reason=nil;self.state=not enabled and 'disabled' or not authenticated and 'disconnected' or 'idle'
  end
  function s:cancel()
    serial=serial+1;active=nil
    self.reason=nil;self.state=not enabled and 'disabled' or not authenticated and 'disconnected' or 'idle'
  end
  function s:begin(direction,file)
    if not enabled then return nil,'disabled'end
    if not authenticated then return nil,'disconnected'end
    if active then return nil,'busy'end
    if (direction~='upload'and direction~='download')or not snapshot_ok(file)then return nil,'invalid_snapshot'end
    if direction=='upload'and not file.exists then return nil,'local_missing'end
    serial=serial+1
    active={id=serial,direction=direction,file={name=file.name,revision=file.revision,exists=file.exists,saved=file.saved,bytes=file.bytes}}
    self.reason=nil;self.state='checking'
    return serial,{action='fetch',path='documents/'..file.name}
  end
  function s:failed(id,status,err)
    if not active or active.id~=id then return nil,'stale'end
    active=nil;self.state,self.reason=M.error_state(status,err)
    return false,self.reason
  end
  function s:checked(id,remote,record)
    if not active or active.id~=id then return nil,'stale'end
    if active.plan then return nil,'already_checked'end
    local p,err=M.decide(active.direction,active.file,remote,record,hash)
    if not p then active=nil;self.state='error';return nil,err end
    if p.action=='conflict'then active=nil;self.state='conflict';return p end
    if p.action=='local_missing'or p.action=='remote_missing'then active=nil;self.state='idle';return p end
    active.plan=p
    active.remote={sha=remote.sha,bytes=remote.bytes}
    self.state=(p.action=='create'or p.action=='update')and 'uploading' or p.action=='download_copy'and 'downloading'or 'checking'
    -- Return a copy; caller mutations cannot alter the internal authorization.
    return {action=p.action,path=p.path,sha=p.sha,fingerprint=p.fingerprint}
  end
  function s:finish(id,receipt,current)
    if not active or active.id~=id then return nil,'stale'end
    if not active.plan then return nil,'not_checked'end
    local a=active;active=nil;self.state='idle'
    local p=a.plan
    -- A first import changes an absent target into the verified remote bytes.
    -- Other actions must leave the captured source exactly unchanged.
    local imported_target=p.action=='download_copy' and not a.file.exists
      and type(receipt)=='table' and receipt.name==a.file.name
    local expected_exists=a.file.exists;local expected_bytes=a.file.bytes
    if imported_target then expected_exists=true;expected_bytes=a.remote.bytes end
    if not snapshot_ok(current)or current.name~=a.file.name or current.revision~=a.file.revision
      or current.exists~=expected_exists or current.bytes~=expected_bytes then return nil,'local_changed'end
    if type(receipt)~='table' or receipt.ok~=true then
      self.state,self.reason=M.error_state(type(receipt)=='table'and receipt.status or nil,type(receipt)=='table'and receipt.err or nil)
      return nil,self.reason
    end
    local sha,fp
    if p.action=='download_copy'then
      if receipt.verified~=true or receipt.new_copy~=true or not M.name_ok(receipt.name)
        or receipt.bytes~=a.remote.bytes or receipt.sha~=a.remote.sha then self.state='error';return nil,'unverified_import'end
      if a.file.exists and receipt.name:lower()==a.file.name:lower()then self.state='error';return nil,'copy_name_collision'end
      if a.file.exists or receipt.name~=a.file.name then return {action='imported_copy',name=receipt.name}end
      sha=a.remote.sha;fp=digest(hash,receipt.bytes)
    elseif p.action=='mark_synced'then
      if receipt.sha~=a.remote.sha then self.state='error';return nil,'invalid_receipt'end
      sha=a.remote.sha;fp=p.fingerprint
    else
      if (receipt.status~=200 and receipt.status~=201)or receipt.path~=p.path
        or receipt.fingerprint~=p.fingerprint or not M.hex_ok(receipt.sha,40)then self.state='error';return nil,'invalid_receipt'end
      sha=receipt.sha;fp=p.fingerprint
    end
    if not fp then self.state='error';return nil,'fingerprint_failed'end
    return {action='checkpoint',name=a.file.name,record={remote_path=p.path,remote_blob_sha=sha,last_synced_local_fingerprint=fp}}
  end
  return s
end
return M
