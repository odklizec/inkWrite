-- Verified XTApp hash/hex/base64 bridge. Acquire/use outside on_draw.
local Host=require('domain.sync_transport')
local Sync=require('domain.sync')
local M={}
function M.new(ctx)
  if not ctx then return nil,'primitives_unavailable'end
  local function has(obj,key)
    if obj==nil then return false end
    local ok,fn=pcall(function()return obj[key]end)
    return ok and type(fn)=='function'
  end
  if not has(ctx.hash,'sha256')or not has(ctx.hex,'encode')
    or not has(ctx.base64,'encode')or not has(ctx.base64,'decode')then return nil,'primitives_unavailable'end
  local function hash(bytes)
    if type(bytes)~='string'or #bytes>65536 then return nil,'invalid_hash_input'end
    local raw=Host.call(ctx.hash,'sha256',bytes)
    if type(raw)~='string'or #raw~=32 then return nil,'hash_failed'end
    local hex=Host.call(ctx.hex,'encode',raw)
    if not Sync.hex_ok(hex,64)then return nil,'hash_failed'end
    return hex
  end
  local codec={}
  function codec.encode(bytes)
    if type(bytes)~='string'or #bytes>32768 then return nil,'invalid_base64_input'end
    local encoded=Host.call(ctx.base64,'encode',bytes)
    if type(encoded)~='string'or #encoded>43692 then return nil,'base64_failed'end
    return encoded
  end
  function codec.decode(encoded)
    if type(encoded)~='string'or #encoded>43692 then return nil,'invalid_base64_input'end
    local bytes=Host.call(ctx.base64,'decode',encoded)
    if type(bytes)~='string'or #bytes>32768 then return nil,'base64_failed'end
    return bytes
  end
  return {hash=hash,codec=codec}
end
return M
