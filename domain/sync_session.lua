-- Manual synchronization only. No timers, drawing, credentials or editor mutations.
local Sync=require('domain.sync')
local Store=require('domain.sync_metadata')
local Docs=require('domain.documents')
local Primitives=require('domain.sync_primitives')
local Auth=require('domain.sync_auth')
local Config=require('domain.sync_config')
local M={}
function M.new(hooks,dependencies)
  local d=dependencies or {};local config=d.config or Config
  local auth,p,serial=nil,nil,0
  local s={notice='Manual sync. Local saves stay on the SD card.',rows={},busy=false}
  local function notify(ctx,text)s.notice=text;ctx:invalidate()end
  local function wifi(ctx,ms)if ctx.net and ctx.net.keep_wifi then pcall(ctx.net.keep_wifi,ctx.net,ms)end end
  local function ready(ctx)
    if not auth then
      p=d.primitives or Primitives.new(ctx)
      if p then auth=(d.auth_factory or Auth.new)(config,p)end
    end
    if not auth then notify(ctx,'GitHub setup or runtime unavailable.');return false end
    return true
  end
  function s:status(ctx)
    return auth and auth:status(ctx)or {state='disconnected',connected=false}
  end
  function s:disconnect(ctx)
    serial=serial+1;self.busy=false;self.conflict=nil;self.rows={}
    if auth then auth:disconnect()end;wifi(ctx,0);notify(ctx,'Disconnected. Session cleared.')
  end
  function s:connect(ctx)
    if ctx.state.github_sync_enabled~=true then notify(ctx,'Enable GitHub sync first.');return end
    if not ready(ctx)then return end
    wifi(ctx,30000);local ok=auth:start(ctx)
    notify(ctx,ok and 'Open github.com/login/device and enter the code.'or 'Connection unavailable. Disconnect and retry.')
  end
  function s:poll(ctx)if auth then auth:poll(ctx)end end
  function s:toggle(ctx)
    ctx.state.github_sync_enabled=ctx.state.github_sync_enabled~=true
    if not ctx.state.github_sync_enabled then self:disconnect(ctx)end
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
    return next_value and Store.save(ctx,next_value,config.scope,p.hash,revision)
  end
  function s:upload(ctx,as_new)
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
    self.conflict=nil
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
      notify(c,saved and 'Uploaded and verified: '..name or 'Upload complete; sync record not saved. Recheck next upload.')
    end
    local started,err=auth:read(ctx,name,function(c,remote,why)
      if id~=serial then return end
      if not remote then failed(c,id,why);return end
      if not unchanged(c,snapshot)then failed(c,id,'local_changed');return end
      local plan
      if as_new then
        if remote.exists then failed(c,id,'remote_race');return end
        plan={action='create'}
      else plan,why=core:checked(op,remote,metadata.documents[name])end
      if not plan then failed(c,id,why);return end
      if plan.action=='conflict'then
        s.busy=false;s.conflict={name=name,sha=remote.sha,reason=plan.reason}
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
  function s:browse(ctx)
    local id=begin(ctx);if not id then return end
    self.conflict=nil;self.rows={}
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
    self.conflict=nil
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
    local status=self:status(ctx)
    if self.busy or status.busy or not status.connected then self:disconnect(ctx)end
    self.rows={};self.conflict=nil;wifi(ctx,0)
  end
  return s
end
return M
