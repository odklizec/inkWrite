-- Public setup only. Bounded profiles own separate grants, records and queues.
local Auth=require('domain.sync_auth')
local Host=require('domain.sync_transport')
local Sync=require('domain.sync')
local Primitives=require('domain.sync_primitives')
local Legacy=require('domain.sync_config')
local M={FILE='github-setup.json',MAX_BYTES=8192,MAX_PROFILES=5}
local function copy(v)
  return {client_id=v.client_id,app_id=v.app_id,login=v.login,repository_id=v.repository_id,
    selectable=v.selectable,profile=v.profile,scope={repo=v.scope.repo,branch=v.scope.branch}}
end
local function same(a,b)
  return a.client_id==b.client_id and a.app_id==b.app_id and a.login:lower()==b.login:lower()
    and a.scope.repo:lower()==b.scope.repo:lower()and a.scope.branch==b.scope.branch
    and a.repository_id==b.repository_id
end
local function valid(v)
  if not Sync.fields(v,{schema=true,revision=true,active=true,profiles=true})or v.schema~=1
    or not Host.integer(v.revision,1,1000000000)or not Host.integer(v.active,1,M.MAX_PROFILES)
    or type(v.profiles)~='table'then return false end
  local n,slots=0,{}
  for k,c in pairs(v.profiles)do
    n=n+1
    if not Host.integer(k,1,M.MAX_PROFILES)or not Auth.config_ok(c)then return false end
    local slot=c.profile or 0;if slots[slot]then return false end;slots[slot]=true
    if slot==0 and not same(c,Legacy)then return false end
  end
  for i=1,n do if not v.profiles[i]then return false end end
  return n<=M.MAX_PROFILES and v.profiles[v.active]~=nil
end
function M.new(ctx,dependencies)
  local d=dependencies or {};local p=d.primitives
  local raw=false;local value={schema=1,revision=1,active=1,profiles={}}
  local m={profiles=value.profiles}
  local size,e=Host.call(ctx.storage,'size',M.FILE)
  if size~=nil then
    if not Host.integer(size,1,M.MAX_BYTES)then m.error='Saved setup is unreadable.'
    else
      raw=Host.call(ctx.storage,'read',M.FILE)
      p=p or Primitives.new(ctx)
      local env=type(raw)=='string'and #raw==size and Host.call(ctx.json,'decode',raw)
      local v=type(env)=='table'and type(env.payload)=='string'and Host.call(ctx.json,'decode',env.payload)
      if not p or not Sync.fields(env,{payload=true,checksum=true})or not Sync.hex_ok(env.checksum,64)
        or Sync.digest(p.hash,env.payload)~=env.checksum or not valid(v)then m.error='Saved setup is unreadable.'
      else value=v;m.profiles=value.profiles;m.config=copy(value.profiles[value.active])end
    end
  elseif e~='not_found'and e~='unavailable'then m.error='Cannot read setup from SD.'
  else
    local legacy=ctx.state.github_sync_enabled==true or ctx.state.github_sync_remember==true
    for _,name in ipairs({'github-connection.json','github-sync.json','github-auto-queue.json'})do
      local bytes=Host.call(ctx.storage,'size',name);if type(bytes)=='number'and bytes>0 then legacy=true end
    end
    if legacy then value.profiles[1]=copy(Legacy);m.config=copy(Legacy)end
  end
  if m.error or not m.config or (raw~=false and ctx.state.github_setup_revision~=value.revision)then
    ctx.state.github_sync_auto=false;ctx.state.github_sync_remember=false;ctx.state.github_sync_enabled=false
    ctx.state.github_sync_connection_choice=false
  end
  if m.config and not m.error then ctx.state.github_setup_revision=value.revision end
  function m:save(c,selected)
    if self.error or not Auth.config_ok(c)then return nil,self.error or 'Invalid setup.'end
    if ctx.budget then ctx.budget:extend()end
    p=p or Primitives.new(ctx);if not p then return nil,'Setup storage unavailable.'end
    local next_value={schema=1,revision=value.revision+1,active=selected or 0,profiles={}}
    for i,v in ipairs(value.profiles)do next_value.profiles[i]=copy(v);if same(v,c)then next_value.active=i end end
    local final=copy(c)
    if next_value.active==0 then
      local slots={};for _,v in ipairs(value.profiles)do slots[v.profile or 0]=true end
      for i=1,4 do if not slots[i]then final.profile=i;break end end
      if not final.profile or #next_value.profiles>=M.MAX_PROFILES then return nil,'Four additional setups are saved. Choose an existing setup.'end
      next_value.active=#next_value.profiles+1
    else final.profile=next_value.profiles[next_value.active].profile end
    next_value.profiles[next_value.active]=final
    if not valid(next_value)then return nil,'Invalid setup.'end
    local payload=Host.call(ctx.json,'encode',next_value)
    local checksum=type(payload)=='string'and Sync.digest(p.hash,payload)
    local encoded=checksum and Host.call(ctx.json,'encode',{payload=payload,checksum=checksum})
    local current,err=Host.call(ctx.storage,'read',M.FILE);if current==nil and err=='not_found'then current=false end
    if current~=raw or type(encoded)~='string'or #encoded>M.MAX_BYTES then return nil,'Setup changed or SD unavailable. Reopen inkWrite.'end
    -- Freeze the old session before this call. An ambiguous commit must never
    -- resume it; reopening reads either complete old or complete new setup.
    if not Host.call(ctx.storage,'write',M.FILE,encoded)or Host.call(ctx.storage,'read',M.FILE)~=encoded then
      self.error='Could not verify setup save. Reopen inkWrite before syncing.';return nil,self.error
    end
    raw=encoded;value=next_value;self.profiles=value.profiles;self.config=copy(final)
    ctx.state.github_setup_revision=value.revision
    ctx.state.github_sync_auto=false;ctx.state.github_sync_remember=false;ctx.state.github_sync_enabled=true
    ctx.state.github_sync_connection_choice=false
    return copy(final)
  end
  return m
end
return M
