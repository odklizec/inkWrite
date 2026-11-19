-- Bounded asynchronous HTTPS adapter. No retries, file writes or diagnostics log.
local M={MAX_REQUEST=65536,MAX_RESPONSE=49152}
local allowed_errors={no_network=true,timeout=true,io_error=true,busy=true,
  out_of_memory=true,limit_exceeded=true,invalid_argument=true}
local function integer(n,lo,hi)return type(n)=='number'and n%1==0 and n>=lo and n<=hi end
local function call(obj,key,...)
  if obj==nil then return nil,'unavailable'end
  local found,fn=pcall(function()return obj[key]end)
  if not found or type(fn)~='function'then return nil,'unavailable'end
  local ok,a,b=pcall(fn,obj,...)
  if ok then return a,b end
  return nil,'host_exception'
end
M.call=call;M.integer=integer
local function safe_error(err)return allowed_errors[err]and err or 'transport_failed'end
local function options(origin,request)
  if type(request)~='table'or type(request.path)~='string'or #request.path>768
    or request.path:sub(1,1)~='/'or request.path:sub(1,2)=='//'
    or request.path:find('[%z\1-\32\127-\255\\#]')then return nil,'invalid_request'end
  if request.method~='GET'and request.method~='POST'and request.method~='PUT'then return nil,'invalid_request'end
  local limit=request.response_limit
  if not integer(limit,1,M.MAX_RESPONSE)then return nil,'invalid_request'end
  if request.body~=nil and (request.method=='GET'or type(request.body)~='string'or #request.body>M.MAX_REQUEST)then return nil,'invalid_request'end
  local headers={};local n=0;local names={}
  if type(request.headers)~='table'then return nil,'invalid_request'end
  for k,v in pairs(request.headers)do
    n=n+1
    if n>16 or type(k)~='string'or #k==0 or #k>64 or k:find('[^%w-]')
      or type(v)~='string'or #v>1024 or v:find('[%z\1-\31\127]')or names[k:lower()]then return nil,'invalid_request'end
    names[k:lower()]=true;headers[k]=v
  end
  return {url=origin..request.path,method=request.method,headers=headers,body=request.body,timeout_ms=15000},limit
end
function M.new(origin)
  -- Bind one trusted origin; a request cannot change hosts or disable HTTPS.
  if type(origin)~='string'or #origin>128 or not origin:match('^https://[%w][%w.-]*[%w]$')then return nil,'invalid_origin'end
  local serial,active=0,nil
  local t={}
  function t:cancel()
    serial=serial+1;local old=active;active=nil
    if old and old.job then call(old.job,'cancel')end
  end
  function t:busy()return active~=nil end
  function t:request(ctx,request,done)
    if active then return nil,'busy'end
    if type(done)~='function'then return nil,'invalid_callback'end
    local opts,limit=options(origin,request);if not opts then return nil,limit end
    serial=serial+1;local id=serial
    local a={id=id};active=a
    local job,err=call(ctx.net,'request',opts,function(c,res)
      if active~=a or serial~=id then return end
      active=nil;a.job=nil
      local result={}
      if type(res)~='table'then result.err='invalid_response'
      elseif res.ok~=true or res.err~=nil then result.err=safe_error(res.err)
      elseif not integer(res.status,100,599)or type(res.body)~='string'
        or not integer(res.bytes,0,131072)or res.bytes~=#res.body then result.err='incomplete_response'
      elseif #res.body>limit then result.err='response_too_large'
      else
        result.status=res.status
        if res.status>=300 and res.status<400 then result.err='redirect_refused'
        elseif res.status>=500 then result.err='server_error'
        elseif res.status==429 or (res.status==403 and type(res.headers)=='table'
          and (res.headers['x-ratelimit-remaining']=='0'or res.headers['retry-after']~=nil))then
          result.err='rate_limited'
          local after=type(res.headers)=='table'and res.headers['retry-after']
          if type(after)=='string'and #after<=4 and after:match('^%d+$')and integer(tonumber(after),1,3600)then result.retry_after=tonumber(after)end
        elseif res.status>=200 and res.status<300 then
          call(c.budget,'extend')
          local data=call(c.json,'decode',res.body)
          if type(data)~='table'then result.err='invalid_json'else result.data=data end
        end -- Error response bodies and headers never escape this boundary.
      end
      done(c,result)
    end)
    -- Handle a synchronous test callback without retaining a completed job.
    if active==a then
      if not job then active=nil;return nil,safe_error(err)end
      a.job=job
    end
    return true
  end
  return t
end
return M
