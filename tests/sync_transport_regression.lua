local Transport=require('domain.sync_transport')
local Native=require('test_native')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function host()
 local h={calls=0,extended=0,cancelled=0};local callback
 h.ctx={budget={extend=function()h.extended=h.extended+1;return true end},json={decode=function(_,raw)return Native.decode(raw)end}}
 h.ctx.net={request=function(_,opts,fn)
   h.calls=h.calls+1;h.options=opts
   if h.throws then error('secret exception')end
   if h.error then return nil,h.error end
   callback=fn;return {cancel=function()h.cancelled=h.cancelled+1 end}
 end}
 function h:respond(body,status,patch)
   local res={ok=true,status=status or 200,body=body,bytes=#body,headers={}}
   for k,v in pairs(patch or {})do res[k]=v end
   callback(self.ctx,res);return callback
 end
 return h
end
local function request()return {path='/test',method='GET',headers={Accept='application/json'},response_limit=4096}end
local t=assert(Transport.new('https://api.example.test'));local h=host();local got
local function done(_,res)got=res end
for _,origin in ipairs({'http://example.test','https://example.test/path','https://name:secret@example.test','https://example.test?x','https://example.test:443'})do
 check(Transport.new(origin)==nil,'unsafe origin refused')
end
check(t:request(h.ctx,request(),done)==true and t:busy(),'async request begins')
check(h.options.url=='https://api.example.test/test'and h.options.timeout_ms==15000 and h.options.save==nil,'fixed origin/deadline, no file target')
check(t:request(h.ctx,request(),done)==nil and h.calls==1,'one unfinished request')
local replay=h:respond('{"ok":true}')
check(got.data.ok==true and not t:busy()and h.extended==1,'bounded decode outside draw')
got=nil;replay(h.ctx,{ok=true,status=200,body='{}',bytes=2});check(got==nil,'duplicate completion ignored')
local first=assert(t:request(h.ctx,request(),done));replay=h:respond('{}');t:request(h.ctx,request(),done);got=nil
replay(h.ctx,{ok=true,status=200,body='{}',bytes=2});check(got==nil and t:busy(),'old completion cannot finish new job')
t:cancel();check(h.cancelled==1 and not t:busy(),'cancel releases app slot')
h.error='busy';check(t:request(h.ctx,request(),done)==nil and not t:busy(),'host abort can still report busy without retries')
h.error=nil;h.throws=true;local ok,err=t:request(h.ctx,request(),done)
check(ok==nil and err=='transport_failed'and not t:busy(),'host exception redacted')
h.throws=false
local cases={
 {{ok=false,err='no_network'},'no_network'},{{ok=false,err='timeout'},'timeout'},
 {{ok=false,err='io_error'},'io_error'},{{ok=true,err='limit_exceeded'},'limit_exceeded'},
 {{ok=false,err='out_of_memory'},'out_of_memory'},{{ok=false,err='secret'},'transport_failed'},
 {{bytes=3},'incomplete_response'},{{status=302},'redirect_refused'},{{status=500},'server_error'},
 {{status=429,headers={['retry-after']='60'}},'rate_limited'},
 {{status=403,headers={['x-ratelimit-remaining']='0'}},'rate_limited'},
}
for _,case in ipairs(cases)do
 got=nil;t:request(h.ctx,request(),done);h:respond('{}',200,case[1])
 check(got.err==case[2]and got.data==nil and got.body==nil and got.headers==nil,'safe failure '..case[2])
end
t:request(h.ctx,request(),done);h:respond('{"secret":"not shown"}',401)
check(got.status==401 and got.data==nil and got.body==nil,'401 body removed')
t:request(h.ctx,request(),done);h:respond('bad JSON')
check(got.err=='invalid_json','malformed JSON fails closed')
local small=request();small.response_limit=1;t:request(h.ctx,small,done);local extended=h.extended;h:respond('{}')
check(got.err=='response_too_large'and h.extended==extended,'oversized body not parsed')
for _,patch in ipairs({{path='//evil.test'},{path='/a#fragment'},{path='/a\r\nsecret'},
 {method='DELETE'},{body='GET body'},{response_limit=49153},{headers={Authorization='Bearer\nsecret'}},
 {headers={A='x',a='y'}}})do
 local req=request();for k,v in pairs(patch)do req[k]=v end
 local calls=h.calls;check(t:request(h.ctx,req,done)==nil and h.calls==calls,'unsafe options rejected before request')
end
return n
