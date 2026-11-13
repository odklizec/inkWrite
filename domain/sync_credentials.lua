-- Optional app-private SD storage, NOT an encrypted vault. Never expose records.
local Host=require('domain.sync_transport')
local Sync=require('domain.sync')
local M={FILE='github-connection.json',MAX_BYTES=2048}
function M.new(config)
  local binding={client_id=config.client_id,app_id=config.app_id,login=config.login,
    repo=config.scope.repo,branch=config.scope.branch,repository_id=config.repository_id}
  local function valid(v)
    if not Sync.fields(v,{schema=true,client_id=true,app_id=true,login=true,repo=true,branch=true,
      repository_id=true,account_id=true,verified_repository_id=true,access_token=true,refresh_token=true,
      issued_at=true,access_expires_at=true,refresh_expires_at=true})or v.schema~=1 then return false end
    for k,x in pairs(binding)do if v[k]~=x then return false end end
    if not Host.integer(v.account_id,1,2147483647)or not Host.integer(v.verified_repository_id,1,2147483647)
      or (binding.repository_id and v.verified_repository_id~=binding.repository_id)then return false end
    for k,prefix in pairs({access_token='ghu_',refresh_token='ghr_'})do
      local t=v[k];if type(t)~='string'or #t<8 or #t>255 or not t:match('^'..prefix..'[A-Za-z0-9]+$')then return false end
    end
    if not Host.integer(v.issued_at,1,2147483647)or not Host.integer(v.access_expires_at,1,2147483647)
      or not Host.integer(v.refresh_expires_at,1,2147483647)then return false end
    return v.access_expires_at>v.issued_at and v.access_expires_at-v.issued_at<=28800
      and v.refresh_expires_at>v.issued_at and v.refresh_expires_at-v.issued_at<=15897600
  end
  local c={}
  function c:record(values)
    local v={schema=1};for k,x in pairs(binding)do v[k]=x end
    for k,x in pairs(values)do v[k]=x end
    return valid(v)and v or nil
  end
  function c:load(ctx)
    local size,err=Host.call(ctx.storage,'size',M.FILE)
    if size==nil then if err=='not_found'then return false end;return nil,'connection_read_failed'end
    if not Host.integer(size,1,M.MAX_BYTES)then return nil,'invalid_saved_connection'end
    local raw=Host.call(ctx.storage,'read',M.FILE)
    if type(raw)~='string'or #raw~=size then return nil,'connection_read_failed'end
    local value=Host.call(ctx.json,'decode',raw)
    if not valid(value)then return nil,'invalid_saved_connection'end
    return value
  end
  function c:save(ctx,v)
    if not valid(v)then return nil,'invalid_saved_connection'end
    local raw=Host.call(ctx.json,'encode',v)
    if type(raw)~='string'or #raw>M.MAX_BYTES then return nil,'connection_write_failed'end
    if not Host.call(ctx.storage,'write',M.FILE,raw)or Host.call(ctx.storage,'read',M.FILE)~=raw then return nil,'connection_write_failed'end
    return true
  end
  function c:forget(ctx)
    if not Host.call(ctx.storage,'remove',M.FILE)then return nil,'connection_remove_failed'end
    local size,err=Host.call(ctx.storage,'size',M.FILE)
    if size~=nil or err~='not_found'then return nil,'connection_remove_failed'end
    return true
  end
  return c
end
return M
