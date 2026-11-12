local Native=require('test_native')
local M={hash=Native.sha256,codec={encode=Native.base64_encode,decode=Native.base64_decode}}
function M.host()
  local h={files={},writes=0,reads=0}
  h.ctx={json={encode=function(_,v)return Native.encode(v)end,decode=function(_,v)return Native.decode(v)end}}
  h.ctx.storage={
    size=function(_,name)if h.fail_read then return nil,'io_error'end;local b=h.files[name];return b and #b or nil,b and nil or 'not_found'end,
    read=function(_,name)h.reads=h.reads+1;if h.throw_read then error('private host message')end;if h.fail_read then return nil,'io_error'end;return h.files[name],h.files[name]and nil or 'not_found'end,
    write=function(_,name,bytes)
      h.writes=h.writes+1
      if h.throw_write then error('private host message')end
      if h.fail_write then return nil,'io_error'end
      h.files[name]=h.corrupt_write and 'broken'or bytes
      if h.fail_after_commit then return nil,'io_error'end
      return true
    end,
  }
  return h
end
function M.transport()
  local t={calls=0,history={}}
  local pending
  function t:request(req,fn)
    if pending then return nil,'busy'end
    self.calls=self.calls+1
    self.history[#self.history+1]={method=req.method,path=req.path}
    if #self.history>8 then table.remove(self.history,1)end
    local job={req=req,fn=fn};pending=job
    function job:cancel()if pending==self then pending=nil end end
    return job
  end
  function t:respond(status,payload)
    assert(pending,'no pending request');local p=pending;pending=nil;p.fn(status,payload);p.req=nil
    return p.fn -- Allows tests to deliberately replay a stale callback.
  end
  return t
end
return M
