local Probe=require('probe')
local count=0
local function check(v,message) count=count+1;assert(v,message) end
for _,origin in ipairs({'http://echo.test','https://user:secret@echo.test','https://echo.test/path','https://echo.test?token=x','https://echo.test/#x',''}) do
  check(Probe.new(origin)==nil,'reject unsafe origin')
end
local p=assert(Probe.new('https://echo.test'))
local callback,request,cancelled,result
local ctx={budget={extend=function()end},json={decode=function(_,s)
  if s=='bad' then return nil,'invalid_argument' end
  return {method=request.method,data=request.body,headers={authorization=Probe.DUMMY_AUTH,['Content-Type']='text/plain; charset=utf-8'}}
end}}
ctx.net={request=function(_,req,fn)
  request=req;callback=fn
  return {cancel=function()cancelled=true end}
end}
local function receive(_,r) result=r end
for i,case in ipairs(Probe.cases) do
  result=nil
  check(p:start(ctx,i,receive),'accept case')
  check(request.url=='https://echo.test'..case.path,'exact endpoint')
  check(request.timeout_ms==10000 and request.headers.Authorization==Probe.DUMMY_AUTH,'bounded dummy request')
  check((case.method=='GET' and request.body==nil) or request.body==Probe.PAYLOAD,'no GET body; exact UTF8 dummy body')
  check(p:start(ctx,i,receive)==nil,'one operation')
  local body=case.size and string.rep('x',math.min(case.size,131072)) or '{}'
  callback(ctx,{ok=true,status=case.status or 200,body=body,bytes=case.size or #body,err=case.size==131073 and 'limit_exceeded' or nil})
  check(result and result.pass,'mock success '..i)
  check(not p.busy and p.job==nil,'release slot')
  check(result.body==nil and result.headers==nil,'no raw response retained')
end
check(p:start(ctx,1,receive),'start cancellation')
local stale=callback
p:cancel();check(cancelled and not p.busy,'cancel host job')
result=nil
stale(ctx,{ok=true,status=200,body='{}',bytes=2})
check(result==nil,'late response ignored')
check(p:start(ctx,1,receive),'new generation')
stale(ctx,{ok=true,status=200,body='{}',bytes=2})
check(p.busy,'old generation cannot complete new operation')
callback(ctx,{ok=false,err='timeout'})
check(result.err=='timeout' and not result.pass,'timeout classified')
for _,err in ipairs({'no_network','io_error','out_of_memory','limit_exceeded','arbitrary sensitive host error'}) do
  check(p:start(ctx,1,receive),'error request accepted')
  callback(ctx,{ok=false,err=err})
  check(not result.pass and result.err==(err=='arbitrary sensitive host error' and 'host_error' or err),'redacted errors')
end
for _,response in ipairs({
  {ok=true,status=200,body='bad',bytes=3},
  {ok=true,status=200,body='{}',bytes=999},
  {ok=true,status=302,body='',bytes=0},
  {ok=true,status=401,body='',bytes=0},
  {ok=true,status=200,body=string.rep('x',4097),bytes=4097},
}) do
  check(p:start(ctx,1,receive),'invalid response request')
  callback(ctx,response);check(not result.pass,'fail closed on invalid echo')
end
ctx.net.request=function()return nil,'busy'end
local ok,err=p:start(ctx,1,receive)
check(not ok and err=='busy' and not p.busy,'host busy unwinds')
ctx.net.request=function()error('secret exception text')end
ok,err=p:start(ctx,1,receive)
check(not ok and err=='host_exception' and not p.busy,'exception redacted')
check(p:start({},1,receive)==nil,'no net permission fails closed')
check(p:start(ctx,99,receive)==nil,'bad case rejected')
check(p:start(ctx,1,nil)==nil,'bad completion rejected')
return count
