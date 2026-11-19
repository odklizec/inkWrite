-- Scoped transfers. Scheduling is separate; drawing and local saving never send requests.
local Sync=require('domain.sync')
local Store=require('domain.sync_metadata')
local Docs=require('domain.documents')
local Primitives=require('domain.sync_primitives')
local Auth=require('domain.sync_auth')
local Config=require('domain.sync_config')
local M={}
function M.new(hooks,dependencies)
  local d=dependencies or {};local config=d.config or Config
  local Store=Store.for_config(config)
  local auth,p,serial=d.auth,d.primitives,0
  local reconnect_allowed=true
  local s={notice='Manual sync. Local saves stay on the SD card.',rows={},busy=false,file_status='Saved locally'}
  local function notify(ctx,text)s.notice=text;ctx:invalidate()end
  local function wifi(ctx,ms)if ctx.net and ctx.net.keep_wifi then pcall(ctx.net.keep_wifi,ctx.net,ms)end end
  local function ready(ctx)
    p=p or d.primitives or Primitives.new(ctx)
    if not auth then
      p=d.primitives or Primitives.new(ctx)
      if p then auth=(d.auth_factory or Auth.new)(config,p)end
    end
    if not auth then notify(ctx,'GitHub setup or runtime unavailable.');return false end
    return true
  end
  function s:status(ctx)
    local status=auth and auth:status(ctx)or {state='disconnected',connected=false}
    if status.connected and (self.notice=='Reconnecting with saved connection...'
      or self.notice=='Open github.com/login/device and enter the code.')then self.notice='Connected. Ready for manual sync.'end
    return status
  end
  function s:refresh_file_status(ctx)
    self.file_status='Saved locally'
    if ctx.state.github_sync_enabled~=true then return end
    p=p or d.primitives or Primitives.new(ctx)
    if not p or type(hooks.snapshot)~='function'then return end
    if ctx.budget then ctx.budget:extend()end
    local file=hooks.snapshot(ctx,false)
    if not file then
      local info=hooks.describe and hooks.describe()
      if info and info.dirty then self.file_status='Unsaved local changes'end
      return
    end
    local fp=Sync.digest(p.hash,file.bytes)
    local metadata=Store.load(ctx,config.scope,p.hash)
    if not metadata then self.file_status='Saved locally; sync record unavailable';return end
    local record=metadata.documents[file.name]
    local known=self.remote_change
    if known and known.identity==file.identity and known.name==file.name and known.fingerprint==fp then
      self.file_status='Remote changes found'
    elseif record and record.last_synced_local_fingerprint==fp then self.file_status='Up to date at last sync'
    else self.file_status='Changes waiting to upload'end
  end
  function s:open(ctx)
    self:refresh_file_status(ctx)
    if reconnect_allowed and ctx.state.github_sync_enabled==true and ctx.state.github_sync_remember==true and ready(ctx)then
      local status=auth:status(ctx)
      if not status.connected and not status.busy and not status.user_code then self:connect(ctx)end
    end
  end
  function s:remember(ctx)
    reconnect_allowed=true
    ctx.state.github_sync_remember=true
    if ready(ctx)and auth:status(ctx).connected and auth:remember(ctx)then notify(ctx,'Connection remembered on this device.')
    else notify(ctx,'Remember enabled. Connect once to save the connection.')end
  end
  function s:forget(ctx)
    serial=serial+1;self.busy=false;self.conflict=nil;self.pending_update=nil;self.review=nil;self.rows={};self.history=nil
    local ok=ready(ctx)and auth:forget(ctx)
    if ok then ctx.state.github_sync_remember=false end
    wifi(ctx,0);notify(ctx,ok and 'Connection forgotten. Sign in again to connect.'or 'Could not remove saved connection. Retry Forget before using sync.')
  end
  function s:disconnect(ctx)
    reconnect_allowed=false
    serial=serial+1;self.busy=false;self.conflict=nil;self.pending_update=nil;self.review=nil;self.rows={};self.history=nil
    if auth then auth:disconnect()end;wifi(ctx,0);notify(ctx,'Disconnected. Session cleared.')
  end
  function s:connect(ctx)
    reconnect_allowed=true
    if ctx.state.github_sync_enabled~=true then notify(ctx,'Enable GitHub sync first.');return end
    if not ready(ctx)then return end
    wifi(ctx,30000)
    local restored,why=auth:restore(ctx)
    if restored then notify(ctx,'Reconnecting with saved connection...');return end
    if restored==nil then notify(ctx,why=='clock_unavailable'and 'Set the device time, then retry connecting.'or 'Saved connection unavailable. Retry or Forget and sign in again.');return end
    local ok=auth:start(ctx)
    notify(ctx,ok and 'Open github.com/login/device and enter the code.'or 'Connection unavailable. Disconnect and retry.')
  end
  function s:poll(ctx)if auth then auth:poll(ctx)end end
  function s:toggle(ctx)
    ctx.state.github_sync_enabled=ctx.state.github_sync_enabled~=true
    if not ctx.state.github_sync_enabled then self:disconnect(ctx)end
    self:refresh_file_status(ctx)
  end
  local function begin(ctx)
    if s.busy then return nil end
    if ctx.state.github_sync_enabled~=true or not ready(ctx)or not auth:status(ctx).connected then
      notify(ctx,'Connect to GitHub first.');return nil
    end
    serial=serial+1;s.busy=true;wifi(ctx,30000);notify(ctx,'Checking GitHub...');return serial
  end
  local function failed(ctx,id,why)
    if id~=serial then return end
    s.busy=false
    local labels={remote_changed='Remote file changed. Refresh and try again.',remote_race='GitHub changed during upload. Recheck before retrying.',
      authorization_required='Authorization required. Reconnect to GitHub.',timeout='Request timed out. Recheck before retrying.',
      no_network='No network. Local document preserved.',directory_too_large='Remote folder exceeds the supported listing limit.'}
    notify(ctx,labels[why]or 'Sync did not finish. Local document preserved; recheck before retrying.')
  end
  local function unchanged(ctx,snapshot)
    local current=hooks.snapshot(ctx,false)
    return current and current.identity==snapshot.identity and current.name==snapshot.name
      and current.revision==snapshot.revision and current.bytes==snapshot.bytes and current.saved==true and current.exists==true,current
  end
  local function checkpoint(ctx,metadata,revision,name,record)
    local next_value=Store.checkpoint(metadata,name,record,config.scope)
    local ok=next_value and Store.save(ctx,next_value,config.scope,p.hash,revision)
    if ok and s.needs_review==name then s.needs_review=nil end
    if ok and s.on_checkpoint then s.on_checkpoint(ctx,name,record.last_synced_local_fingerprint)end
    return ok
  end
  function s:sync(ctx)return self:upload(ctx,false,true)end
  function s:upload(ctx,as_new,combined)
    if ctx.budget then ctx.budget:extend()end
    local snapshot=hooks.snapshot(ctx,true)
    if not snapshot then notify(ctx,'Save the current document successfully before uploading.');return end
    local id=begin(ctx);if not id then return end
    local metadata,revision=Store.load(ctx,config.scope,p.hash)
    if not metadata then failed(ctx,id,'metadata');return end
    local name=snapshot.name
    if as_new then
      local uuid=ctx.random and Docs.call(ctx.random,'uuid')
      if type(uuid)~='string'or not uuid:match('^[%x-]+$')or #uuid<32 or #uuid>36 then failed(ctx,id,'random');return end
      name='local-'..uuid..(snapshot.name:lower():sub(-4)=='.txt'and '.txt'or '.md')
    end
    self.conflict=nil;self.pending_update=nil
    local outcome
    local core=Sync.new(p.hash);core:configure(true,true)
    local op=core:begin('upload',snapshot)
    local function complete(c,receipt)
      if id~=serial then return end
      local same,current=unchanged(c,snapshot)
      if not same then failed(c,id,'local_changed');return end
      s.busy=false
      if as_new then notify(c,'Uploaded new remote copy: '..name);return end
      local result=core:finish(op,receipt,current)
      if not result then failed(c,id,'receipt');return end
      local saved=checkpoint(c,metadata,revision,result.name,result.record)
      if saved then s.file_status='Up to date at last sync';s.remote_change=nil end
      local success=combined and (outcome=='mark_synced'and 'Up to date: 'or 'Synced: ')or 'Uploaded and verified: '
      notify(c,saved and success..name or 'Upload complete; sync record not saved. Recheck next sync.')
    end
    local started,err=auth:read(ctx,name,function(c,remote,why)
      if id~=serial then return end
      if not remote then failed(c,id,why);return end
      if not unchanged(c,snapshot)then failed(c,id,'local_changed');return end
      local plan
      if as_new then
        if remote.exists then failed(c,id,'remote_race');return end
        plan={action='create'}
      else
        if combined then plan,why=Sync.reconcile(snapshot,remote,metadata.documents[name],p.hash)end
        if plan and plan.action=='update_local'then
          core:cancel();s.busy=false;s.conflict=nil
          s.pending_update={name=name,sha=remote.sha,identity=snapshot.identity,revision=snapshot.revision,
            fingerprint=plan.fingerprint,base_sha=metadata.documents[name].remote_blob_sha}
          s.remote_change={name=name,identity=snapshot.identity,fingerprint=Sync.digest(p.hash,snapshot.bytes)}
          s.file_status='Remote changes found'
          notify(c,'Only GitHub changed. Update the local document or keep a copy.');return
        end
        plan,why=core:checked(op,remote,metadata.documents[name])
      end
      if not plan then failed(c,id,why);return end
      outcome=plan.action
      if plan.action=='conflict'then
        if remote.exists then
          s.remote_change={name=name,identity=snapshot.identity,fingerprint=Sync.digest(p.hash,snapshot.bytes)}
          s.file_status='Remote changes found'
        end
        s.busy=false;s.needs_review=name;s.conflict={name=name,sha=remote.sha,reason=plan.reason}
        notify(c,'Conflict: originals kept. Choose a copy or cancel.');return
      end
      if plan.action=='mark_synced'then complete(c,{ok=true,sha=remote.sha});return end
      if plan.action~='create'and plan.action~='update'then failed(c,id,'plan');return end
      local ok,e=auth:write(c,name,snapshot.bytes,plan.sha,function(c2,receipt,e2)
        if id~=serial then return end
        if not receipt then failed(c2,id,e2);return end
        complete(c2,receipt)
      end,function(c2)return id==serial and unchanged(c2,snapshot)==true end)
      if not ok then failed(c,id,e)end
    end)
    if not started then failed(ctx,id,err)end
  end
  function s:update_local(ctx)
    local pending=self.pending_update
    if not pending or type(hooks.apply_remote)~='function'then return end
    if ctx.budget then ctx.budget:extend()end
    local file=hooks.snapshot(ctx,false)
    if not file or file.identity~=pending.identity or file.name~=pending.name or file.revision~=pending.revision
      or Sync.digest(p.hash,file.bytes)~=pending.fingerprint then
      self.pending_update=nil;notify(ctx,'Local document changed. Press Sync to check again.');return
    end
    local id=begin(ctx);if not id then return end
    self.pending_update=nil
    local metadata,revision=Store.load(ctx,config.scope,p.hash)
    local record=metadata and metadata.documents[file.name]
    if not record or record.remote_blob_sha~=pending.base_sha or record.last_synced_local_fingerprint~=pending.fingerprint then failed(ctx,id,'metadata_changed');return end
    local ok,e=auth:read(ctx,file.name,function(c,remote,why)
      if id~=serial then return end
      if not remote or not unchanged(c,file)then failed(c,id,why or 'local_changed');return end
      local plan=Sync.reconcile(file,remote,record,p.hash)
      if not plan or plan.action~='update_local'then failed(c,id,'remote_changed');return end
      local applied,backup=hooks.apply_remote(c,file,remote.bytes)
      if not applied then failed(c,id,'local_update_failed');return end
      local current=hooks.snapshot(c,false)
      if not current or current.name~=file.name or current.bytes~=remote.bytes then failed(c,id,'unverified_update');return end
      s.busy=false;s.remote_change=nil
      if s.on_checkpoint then s.on_checkpoint(c,file.name,nil)end
      local fp=Sync.digest(p.hash,remote.bytes)
      local saved=fp and checkpoint(c,metadata,revision,file.name,{remote_path='documents/'..file.name,
        remote_blob_sha=remote.sha,last_synced_local_fingerprint=fp})
      s.file_status=saved and 'Up to date at last sync'or 'Saved locally'
      notify(c,'Local document updated. Backup: '..backup..(saved and ''or ' (sync record not saved)'))
    end,pending.sha)
    if not ok then failed(ctx,id,e)end
  end
  local function review_same(c,file)
    local current=hooks.snapshot(c,false,file.name)
    return current and current.name==file.name and current.identity==file.identity
      and current.revision==file.revision and current.bytes==file.bytes and current.saved and current.exists
  end
  function s:review_document(ctx,name)
    if ctx.budget then ctx.budget:extend()end
    local file=hooks.snapshot(ctx,true,name)
    if not file then notify(ctx,'Save the local document successfully before review.');return end
    local id=begin(ctx);if not id then return end
    self.review=nil;self.conflict=nil;self.pending_update=nil
    local ok,e=auth:read(ctx,file.name,function(c,remote,why)
      if id~=serial then return end
      if not remote or not review_same(c,file)then failed(c,id,why or 'local_changed');return end
      s.busy=false;s.review={name=file.name,file=file,remote=remote}
      notify(c,'Read both versions, then choose which one to keep.')
    end)
    if not ok then failed(ctx,id,e)end
  end
  function s:resolve_review(ctx,direction)
    local review=self.review
    if not review or (direction~='local'and direction~='github')then return end
    if direction=='local'and (not review.remote.exists or type(hooks.apply_remote)~='function')then return end
    if ctx.budget then ctx.budget:extend()end
    if not review_same(ctx,review.file)then self.review=nil;notify(ctx,'Local file changed. Review both versions again.');return end
    local id=begin(ctx);if not id then return end
    local metadata,revision=Store.load(ctx,config.scope,p.hash)
    if not metadata then failed(ctx,id,'metadata');return end
    local function complete(c,sha,bytes,backup,local_update,identical)
      if id~=serial then return end
      local current=hooks.snapshot(c,false,review.name)
      if not current or current.bytes~=bytes then failed(c,id,'local_changed');return end
      local fp=Sync.digest(p.hash,bytes)
      local saved=fp and checkpoint(c,metadata,revision,review.name,{remote_path='documents/'..review.name,
        remote_blob_sha=sha,last_synced_local_fingerprint=fp})
      s.busy=false;s.review=nil;s.conflict=nil;s.pending_update=nil;s.remote_change=nil
      s.file_status=saved and 'Up to date at last sync'or 'Saved locally'
      if local_update and s.on_checkpoint then s.on_checkpoint(c,review.name,nil)end
      if (local_update or saved)and s.needs_review==review.name then s.needs_review=nil end
      notify(c,(identical and 'Both versions already match.'or (local_update and 'Local version replaced.'or 'GitHub version replaced.'))
        ..(backup and ' Backup: '..backup or '')..(saved and ''or ' Sync record not saved; recheck.'))
    end
    local ok,e=auth:read(ctx,review.name,function(c,remote,why)
      if id~=serial then return end
      if not remote then failed(c,id,why);return end
      if not review_same(c,review.file)then s.review=nil;failed(c,id,'local_changed');return end
      if remote.exists~=review.remote.exists or remote.sha~=review.remote.sha or remote.bytes~=review.remote.bytes then
        s.review=nil;failed(c,id,'remote_changed');return
      end
      if remote.exists and remote.bytes==review.file.bytes then complete(c,remote.sha,remote.bytes,nil,false,true);return end
      if direction=='local'then
        local applied,backup=hooks.apply_remote(c,review.file,remote.bytes)
        if not applied then failed(c,id,'local_update_failed');return end
        complete(c,remote.sha,remote.bytes,backup,true)
      else
        local backup
        if remote.exists then
          local target=Docs.fresh_name(c,'github-before',review.name:lower():sub(-4)=='.txt'and '.txt'or '.md',hooks.reserved_name())
          backup=target and Docs.import_copy(c,target,remote.bytes,hooks.reserved_name())
          if not backup then failed(c,id,'backup_failed');return end
        end
        local sent,error=auth:write(c,review.name,review.file.bytes,remote.exists and remote.sha or nil,function(c2,receipt,err)
          if id~=serial then return end
          if not receipt then failed(c2,id,err);return end
          complete(c2,receipt.sha,review.file.bytes,backup,false)
        end,function(c2)return review_same(c2,review.file)and (not backup or Docs.read(c2,backup)==remote.bytes)end)
        if not sent then failed(c,id,error)end
      end
    end,review.remote.sha)
    if not ok then failed(ctx,id,e)end
  end
  -- Automatic uploads use only a captured successful-save fingerprint, never an editor buffer.
  function s:restore_auto(ctx)
    if not reconnect_allowed or not ready(ctx)then return nil,'connection_required'end
    local st=auth:status(ctx)
    if st.connected then return true end
    if st.busy then return true end
    local ok,e=auth:restore(ctx);self.auto_active=ok==true;return ok,e -- Never initiates device approval.
  end
  function s:cancel_auto(ctx)
    if not self.auto_active then return end
    serial=serial+1;self.busy=false;self.auto_active=false
    if auth then auth:cancel_operation()end
    wifi(ctx,0)
  end
  function s:auto_upload(ctx,item,guard,done)
    if self.busy or not ready(ctx)then return nil,'busy'end
    if not auth:status(ctx).connected then return nil,'connection_required'end
    if ctx.budget then ctx.budget:extend()end
    local bytes=Docs.read(ctx,item.name)
    if not bytes or Sync.digest(p.hash,bytes)~=item.fingerprint then return nil,'saved_file_changed'end
    if not guard(ctx)then return nil,'interrupted'end
    local metadata,revision=Store.load(ctx,config.scope,p.hash)
    if not metadata then return nil,'metadata_invalid'end
    serial=serial+1;local id=serial;self.busy=true;self.auto_active=true;wifi(ctx,30000)
    local function same(c)
      return guard(c)and Docs.read(c,item.name)==bytes
    end
    local function finish(c,result,why)
      if id~=serial then return end
      s.busy=false;s.auto_active=false;wifi(c,0)
      done(c,result,why)
    end
    local function checkpoint_auto(c,sha)
      if not same(c)then finish(c,nil,'saved_file_changed');return end
      local ok=checkpoint(c,metadata,revision,item.name,{remote_path='documents/'..item.name,
        remote_blob_sha=sha,last_synced_local_fingerprint=item.fingerprint})
      finish(c,ok and true or nil,ok and nil or 'checkpoint_failed')
    end
    local ok,e=auth:read(ctx,item.name,function(c,remote,why)
      if id~=serial then return end
      if not remote then finish(c,nil,why);return end
      if not same(c)then finish(c,nil,'saved_file_changed');return end
      local file={name=item.name,bytes=bytes,saved=true,exists=true,revision=0,identity=item}
      local plan=Sync.decide('upload',file,remote,metadata.documents[item.name],p.hash)
      if not plan then finish(c,nil,'invalid_plan');return end
      if plan.action=='conflict'then finish(c,nil,'conflict');return end
      if plan.action=='mark_synced'then checkpoint_auto(c,remote.sha);return end
      if plan.action~='create'and plan.action~='update'then finish(c,nil,'invalid_plan');return end
      local sent,err=auth:write(c,item.name,bytes,remote.exists and remote.sha or nil,function(c2,receipt,error)
        if id~=serial then return end
        if not receipt then finish(c2,nil,error);return end
        checkpoint_auto(c2,receipt.sha)
      end,same)
      if not sent then finish(c,nil,err)end
    end)
    if not ok then finish(ctx,nil,e)end
    return true
  end
  function s:history_page(ctx,name,page,anchor)
    local id=begin(ctx);if not id then return end
    self.conflict=nil;self.pending_update=nil
    local ok,e=auth:history(ctx,name,page,anchor,function(c,result,why)
      if id~=serial then return end
      if not result then failed(c,id,why);return end
      s.busy=false;s.history={name=name,rows=result.rows,page=result.page,anchor=result.anchor,
        more=result.more,limited=result.limited}
      notify(c,result.limited and 'History limit reached (100 versions).'
        or (#result.rows==0 and 'No versions on this page.'or 'Select a version. Restores are separate local copies.'))
    end)
    if not ok then failed(ctx,id,e)end
  end
  function s:current_history(ctx)
    local info=hooks.describe and hooks.describe()
    if not info or not Sync.name_ok(info.name)then notify(ctx,'Open a document to view its history.');return end
    return self:history_page(ctx,info.name,1)
  end
  function s:restore_revision(ctx,row)
    if hooks.can_import and not hooks.can_import()then notify(ctx,'Existing files and recovery are protected.');return end
    local history=self.history
    if not history or type(row)~='table'or not Sync.hex_ok(row.sha,40)then return end
    local found=false;for _,item in ipairs(history.rows)do if item==row then found=true;break end end
    if not found then return end
    local name,commit=history.name,row.sha
    local id=begin(ctx);if not id then return end
    local ok,e=auth:read_revision(ctx,name,commit,function(c,remote,why)
      if id~=serial then return end
      if not remote or not remote.exists then failed(c,id,why or 'revision_unavailable');return end
      if hooks.can_import and not hooks.can_import()then failed(c,id,'import');return end
      local target=Docs.fresh_name(c,'restore',name:lower():sub(-4)=='.txt'and '.txt'or '.md',hooks.reserved_name())
      local imported=target and Docs.import_copy(c,target,remote.bytes,hooks.reserved_name())
      if not imported then failed(c,id,'import');return end
      s.busy=false
      -- Historical copies never establish the current branch's sync checkpoint.
      notify(c,'Restored as local copy: '..imported)
    end)
    if not ok then failed(ctx,id,e)end
  end
  function s:browse(ctx)
    local id=begin(ctx);if not id then return end
    self.conflict=nil;self.pending_update=nil;self.review=nil;self.rows={};self.history=nil
    local ok,e=auth:list(ctx,function(c,rows,why)
      if id~=serial then return end
      if not rows then failed(c,id,why);return end
      s.busy=false;s.rows=rows;notify(c,#rows==0 and 'No supported documents in documents/.'or 'Select a file to download as a local copy.')
    end)
    if not ok then failed(ctx,id,e)end
  end
  function s:download(ctx,row)
    if hooks.can_import and not hooks.can_import()then notify(ctx,'Existing files and recovery are protected.');return end
    if type(row)~='table'or not Sync.name_ok(row.name)or not Sync.hex_ok(row.sha,40)then return end
    local id=begin(ctx);if not id then return end
    self.conflict=nil;self.pending_update=nil
    local ok,e=auth:read(ctx,row.name,function(c,remote,why)
      if id~=serial then return end
      if not remote or not remote.exists then failed(c,id,why);return end
      local name=Docs.import_copy(c,row.name,remote.bytes,hooks.reserved_name())
      if not name then failed(c,id,'import');return end
      s.busy=false
      -- Only the original basename can own its remote-path checkpoint.
      local metadata,revision=Store.load(c,config.scope,p.hash)
      local recorded=true
      if name==row.name then
        recorded=metadata and checkpoint(c,metadata,revision,name,{remote_path='documents/'..name,
          remote_blob_sha=remote.sha,last_synced_local_fingerprint=p.hash(remote.bytes)})
      end
      notify(c,'Downloaded copy: '..name..(recorded and ''or ' (sync record not saved)'))
    end,row.sha)
    if not ok then failed(ctx,id,e)end
  end
  function s:close(ctx)
    self:pause(ctx)
    self.rows={};self.conflict=nil;self.pending_update=nil;self.history=nil;self.review=nil;wifi(ctx,0)
  end
  function s:pause(ctx)
    if self.busy then
      serial=serial+1;self.busy=false;self.conflict=nil;self.pending_update=nil
      if auth then auth:cancel_operation()end
      notify(ctx,'Transfer interrupted. Recheck before retrying.')
    end
    wifi(ctx,0)
  end
  function s:leave(ctx)
    serial=serial+1;self.busy=false;self.review=nil
    if auth then auth:disconnect()end;wifi(ctx,0)
  end
  return s
end
return M
