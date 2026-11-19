-- Phase 0 only: synthetic traffic, no storage, no editor dependency or secrets.
local M={DUMMY_AUTH="Bearer inkWrite-phase0-NOT-A-SECRET",PAYLOAD="inkWrite probe: žluťoučký\r\n"}
M.cases={
  {method="GET",path="/anything"},
  {method="POST",path="/anything"},
  {method="PUT",path="/anything"},
  {method="DELETE",path="/anything"},
  {method="GET",path="/bytes/49152",size=49152},
  {method="GET",path="/bytes/131073",size=131073},
  {method="GET",path="/status/401",status=401},
}
local errors={no_network=true,timeout=true,io_error=true,limit_exceeded=true,out_of_memory=true,busy=true,invalid_argument=true}
local function safe_error(e) return errors[e] and e or "host_error" end
function M.new(origin)
  -- Explicit HTTPS origin only. No path, userinfo, query, fragment or credentials.
  if type(origin)~="string" or #origin>256 or not origin:match("^https://[%w%.%-]+$") then
    return nil,"invalid_origin"
  end
  local p={generation=0}
  function p:cancel()
    self.generation=self.generation+1
    local job=self.job;self.job=nil;self.busy=false
    if job then pcall(job.cancel,job) end
  end
  function p:start(ctx,index,done)
    local case=M.cases[index]
    if not case or type(done)~="function" then return nil,"invalid_argument" end
    if self.busy then return nil,"busy" end
    if not ctx.net or type(ctx.net.request)~="function" then return nil,"net_unavailable" end
    self.generation=self.generation+1
    local generation=self.generation
    local req={url=origin..case.path,method=case.method,timeout_ms=10000,
      headers={Authorization=M.DUMMY_AUTH,["content-type"]="text/plain; charset=utf-8"}}
    if case.method~="GET" then req.body=M.PAYLOAD end
    self.busy=true
    local ok,job,err=pcall(ctx.net.request,ctx.net,req,function(c,res)
      if generation~=self.generation or not self.busy then return end
      self.busy=false;self.job=nil
      -- No response text/headers/error messages escape into results or logs.
      local body=type(res.body)=="string" and res.body or ""
      local bytes=type(res.bytes)=="number" and res.bytes or 0
      local result={method=case.method,status=type(res.status)=="number" and res.status or 0,
        bytes=bytes,retained=#body,pass=false}
      if res.err then result.err=safe_error(res.err) end
      if case.size==131073 then
        result.pass=res.ok==true and res.err=="limit_exceeded" and bytes>131072 and #body<=131072
      elseif not res.ok or res.err then
        result.err=result.err or "incomplete_response"
      elseif bytes~=#body or #body>131072 then
        result.err="invalid_response"
      elseif case.size then
        result.pass=res.status==200 and bytes==case.size
      elseif case.status then
        result.pass=res.status==case.status
      elseif res.status~=200 or #body>4096 then
        result.err="unexpected_response"
      else
        -- Parse only tiny echo responses; never parse the large limit samples.
        if c.budget then c.budget:extend() end
        local decoded,value=pcall(c.json.decode,c.json,body)
        if decoded and type(value)=="table" and type(value.headers)=="table" then
          local auth,content_type
          for k,v in pairs(value.headers) do
            if type(k)=="string" then
              if k:lower()=="authorization" then auth=v end
              if k:lower()=="content-type" then content_type=v end
            end
          end
          result.method_echo=value.method==case.method
          result.auth_echo=auth==M.DUMMY_AUTH
          result.type_echo=content_type==req.headers["content-type"]
          result.body_echo=case.method=="GET" or value.data==M.PAYLOAD
          result.pass=result.method_echo and result.auth_echo and result.type_echo and result.body_echo
        else result.err="invalid_echo" end
      end
      done(c,result)
    end)
    if not ok or not job then
      self.busy=false
      return nil,ok and safe_error(err) or "host_exception"
    end
    self.job=job
    return true
  end
  return p
end
return M
