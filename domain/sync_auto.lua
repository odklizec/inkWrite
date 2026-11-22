-- Foreground-only, bounded automatic upload queue. No document bytes or credentials retained.
local Sync=require('domain.sync')
local Docs=require('domain.documents')
local Host=require('domain.sync_transport')
local Primitives=require('domain.sync_primitives')
local Config=require('domain.sync_config')
local M={FILE='github-auto-queue.json',MAX=16,MAX_BYTES=16384}
local function now(c)local t=Host.call(c.clock,'millis');return Host.integer(t,0,2147483647)and t or 0 end
local function age(t,old)return (t-old)&0x7fffffff end
local reasons={conflict=true,saved_file_changed=true,metadata_invalid=true,checkpoint_failed=true,
 connection_required=true,authorization_required=true,interrupted=true,no_network=true,timeout=true,
 io_error=true,busy=true,server_error=true,rate_limited=true,remote_race=true,other=true}
local retry={interrupted=true,no_network=true,timeout=true,io_error=true,busy=true,server_error=true,remote_race=true,checkpoint_failed=true}
local connection_hold={no_network=true,timeout=true,io_error=true,connection_required=true,authorization_required=true}
function M.new(session,hooks,dependencies)
 local d=dependencies or {};local config=d.config or Config;local file=config.profile and ('gh'..config.profile..'-'..M.FILE)or M.FILE;local source=config.scope;local scope={repo=source.repo,branch=source.branch}
 local q={items={},notice='Off',loaded=false,dirty=false,paused=false};local p,raw,active,last_input
 local function enabled(c)return c.state.github_sync_auto==true and c.state.github_sync_enabled==true end
 local function delay(c)local v=c.state.github_sync_delay;return (v==15 or v==60)and v*1000 or 30000 end
 local function digest(t)return p and Sync.digest(p.hash,t)end
 local function blocked(c)
  if hooks.auto_blocked then return hooks.auto_blocked(c)==true end
  local v=hooks.describe and hooks.describe()or {}
  return v.dirty==true or v.blocked==true
 end
 function q:load(c,force)
  if self.loaded or (not force and not enabled(c))then return end
  if c.budget then c.budget:extend()end
  self.loaded=true;last_input=now(c);p=d.primitives or Primitives.new(c)
  if not p then self.bad=true;self.notice='Automatic upload unavailable';return end
  local size,e=Host.call(c.storage,'size',file)
  if size==nil and e=='not_found'then raw=false;self.notice='No pending uploads';return end
  local bytes=type(size)=='number'and size<=M.MAX_BYTES and size>=0 and Host.call(c.storage,'read',file)
  local env=type(bytes)=='string'and #bytes==size and Host.call(c.json,'decode',bytes)
  local value=type(env)=='table'and type(env.payload)=='string'and Host.call(c.json,'decode',env.payload)
  local valid=Sync.fields(env,{format=true,payload=true,checksum=true})and env.format=='inkwrite-auto-1'
   and Sync.hex_ok(env.checksum,64)and digest(env.payload)==env.checksum
   and Sync.fields(value,{schema=true,repo=true,branch=true,items=true})and value.schema==1
   and value.repo==scope.repo and value.branch==scope.branch and type(value.items)=='table'
  local clean,names={},{}
  if valid then
   local n=0
   for k,v in pairs(value.items)do
    n=n+1
    if n>M.MAX or not Host.integer(k,1,M.MAX)or not Sync.fields(v,{name=true,fingerprint=true,attempts=true,reason=true,held=true})
     or not Sync.name_ok(v.name)or names[v.name:lower()]or not Sync.hex_ok(v.fingerprint,64)
     or not Host.integer(v.attempts,0,3)or type(v.held)~='boolean'or (v.reason~=nil and not reasons[v.reason])then valid=false;break end
    names[v.name:lower()]=true
   end
   if valid then for i=1,n do
    local v=value.items[i];if not v then valid=false;break end
    clean[i]={name=v.name,fingerprint=v.fingerprint,attempts=v.attempts,held=v.held or v.attempts>=3,reason=v.reason,last=now(c)}
   end end
  end
  if not valid then self.bad=true;self.notice='Upload queue unreadable; clear it to reset';return end
  raw=bytes;self.items=clean;self.notice=#clean>0 and 'Pending saved documents'or 'No pending uploads'
 end
 function q:flush(c,leaving)
  if not self.dirty or self.bad then return not self.bad end
  if not leaving and c.budget then c.budget:extend()end
  local items={}
  for i,v in ipairs(self.items)do items[i]={name=v.name,fingerprint=v.fingerprint,attempts=v.attempts,held=v.held,reason=v.reason}end
  local payload=Host.call(c.json,'encode',{schema=1,repo=scope.repo,branch=scope.branch,items=items})
  local checksum=type(payload)=='string'and digest(payload)
  local encoded=Sync.hex_ok(checksum,64)and Host.call(c.json,'encode',{format='inkwrite-auto-1',payload=payload,checksum=checksum})
  local current,e=Host.call(c.storage,'read',file)
  if current==nil and e=='not_found'then current=false end
  if current~=raw or type(encoded)~='string'or #encoded>M.MAX_BYTES
   or not Host.call(c.storage,'write',file,encoded)or Host.call(c.storage,'read',file)~=encoded then
   self.bad=true;self.notice='Upload queue could not be saved; review settings';return false
  end
  raw=encoded;self.dirty=false;return true
 end
 function q:saved(c,name,bytes)
  if not enabled(c)then return end
  self:load(c);if self.bad or not Sync.name_ok(name)then return end
  local fp=digest(bytes);if not fp then self.notice='Saved file not queued';return end
  for _,v in ipairs(self.items)do if v.name:lower()==name:lower()then
   v.name=name;v.fingerprint=fp;v.last=now(c)
   if v.reason~='conflict'then v.attempts=0;v.held=false;v.reason=nil end
   self.dirty=true;self.notice='Saved document queued';return
  end end
  if #self.items>=M.MAX then self.notice='Upload queue full (16); save again after clearing space';return end
  self.items[#self.items+1]={name=name,fingerprint=fp,attempts=0,held=false,last=now(c)}
  self.dirty=true;self.notice='Saved document queued'
 end
 local function finish(c,item,ok,why)
  active=nil
  if not ok then session:cancel_auto(c)end
  if ok then
   for i,v in ipairs(q.items)do if v==item then table.remove(q.items,i);break end end
   q.notice='Uploaded: '..item.name
  else
   why=reasons[why]and why or 'other';item.reason=why;item.last=now(c)
   item.held=not (retry[why]or why=='rate_limited')or item.attempts>=3
   q.notice=item.held and ('Needs review: '..item.name)or ('Upload deferred: '..item.name)
  end
  q.dirty=true;if c.invalidate then c:invalidate()end
 end
 function q:interrupt(c)
  if not enabled(c)and not active then return end
  last_input=now(c)
  if active then local item=active.item;session:cancel_auto(c);finish(c,item,nil,'interrupted')end
 end
 function q:pause(c,leaving)
  self:interrupt(c);self.paused=true;self:flush(c,leaving)
 end
 function q:resume(c)self.paused=false;last_input=now(c)end
 function q:clear(c)
  self:interrupt(c);self.loaded=false;self.bad=nil;self.items={};p=d.primitives or Primitives.new(c)
  if not p then self.bad=true;self.notice='Automatic upload unavailable';return end
  local v,e=Host.call(c.storage,'read',file)
  if v==nil and e~='not_found'then self.bad=true;self.notice='Upload queue could not be read';return end
  raw=v or false
  self.loaded=true;self.dirty=true;self:flush(c);self.notice=self.bad and self.notice or 'Upload queue cleared'
 end
 local function queue_removed()
  q.dirty=true
  if not q.bad then q.notice=#q.items>0 and 'Pending saved documents'or 'No pending uploads'end
 end
 function q:ack(c,name,fingerprint)
  if not self.loaded then self:load(c,true)end
  for i=#self.items,1,-1 do local v=self.items[i]
   if v.name==name and (fingerprint==nil or v.fingerprint==fingerprint)then
    table.remove(self.items,i);queue_removed()
    return
   end
  end
 end
 function q:prune_missing(c)
  if self.bad or #self.items==0 then return end
  if c.budget then c.budget:extend()end
  local count=#self.items
  for i=count,1,-1 do
   local item=self.items[i]
   if item.held and Docs.missing(c,item.name)then table.remove(self.items,i)end
  end
  if #self.items~=count then queue_removed()end
 end
 function q:connection_verified(c)
  if self.bad then return end
  local resumed=false
  for _,item in ipairs(self.items)do
   if item.held and connection_hold[item.reason]then
    item.held=false;item.attempts=0;item.reason=nil;item.last=now(c)
    resumed=true
   end
  end
  if resumed then
   self.dirty=true;self.notice='Pending saved documents'
   if c.invalidate then c:invalidate()end
  end
 end
 function q:retry(c)
  self:load(c);if self.bad then return end
  if not self.loaded then self.notice='Enable automatic uploads before retrying';return end
  for _,v in ipairs(self.items)do v.held=false;v.attempts=0;v.reason=nil;v.last=now(c)end
  self.dirty=true;self.notice='Pending uploads will be checked again'
 end
 function q:tick(c)
  if not enabled(c)or self.paused then return end
  self:load(c);if self.bad or blocked(c)then return end
  local t=now(c);if age(t,last_input or t)<10000 then return end
  if not self:flush(c)then return end
  if active then
   if active.phase=='restore'then
    local st=session:status(c)
    if st.busy then return end
    if st.connected then active.phase='ready'else finish(c,active.item,nil,st.reason or 'connection_required');return end
   else return end
  end
  local item=active and active.item
  if not item then
   if session.busy then return end
   for _,v in ipairs(self.items)do if not v.held then
    local wait=v.reason=='rate_limited'and 3600000 or (v.attempts==0 and delay(c)or (v.attempts==1 and 30000 or 120000))
    if age(t,v.last)>=wait then item=v;break end
   end end
   if not item then return end
   local st=session:status(c)
   if st.busy or st.user_code then self.notice='Waiting for connection';return end
   if not st.connected and c.state.github_sync_remember~=true then self.notice='Connect to upload saved documents';return end
   item.attempts=math.min(3,item.attempts+1);self.dirty=true
   if not self:flush(c)then return end
   active={item=item,phase=st.connected and 'ready'or 'restore'}
   if not st.connected then
    local ok,e=session:restore_auto(c)
    if not ok then finish(c,item,nil,e or 'connection_required')end
    return
   end
  end
  active.phase='upload';self.notice='Uploading: '..item.name
  local ok,e=session:auto_upload(c,item,function(ctx)
   return enabled(ctx)and not q.paused and not blocked(ctx)and active and active.item==item
    and age(now(ctx),last_input or now(ctx))>=10000
  end,function(ctx,result,why)finish(ctx,item,result,why)end)
  if not ok then finish(c,item,nil,e)end
 end
 return q
end
return M
