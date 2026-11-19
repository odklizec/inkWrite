local Auth=require('domain.sync_auth')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local Native=require('test_native')
local F=require('tests.fixtures.github_contents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local primitives={hash=Mock.hash,codec=Mock.codec}
local function start()
 local h=Host.new();local s=assert(Auth.new(Host.config(),primitives))
 assert(s:start(h.ctx));h:respond(Host.code());h.time=5000;assert(s:poll(h.ctx));return s,h
end
local function connect()
 local s,h=start();h:respond(Host.token());h:verify(s);assert(s:status(h.ctx).connected);return s,h
end
check(Native.decode('{"x":null}').x==Native.null and Native.encode({x=Native.null})=='{"x":null}','host JSON null modeled as sentinel')
check(Auth.new({},primitives)==nil,'missing public setup refused')
check(Auth.new(Host.config(),{})==nil,'missing host primitives refused')
local cfg=Host.config();local s=assert(Auth.new(cfg,primitives));local h=Host.new()
cfg.scope.repo='other/repo';cfg.client_id='changed'
check(s:read(h.ctx,'ideas.md',function()end)==nil and h.calls==0,'no API operation before authorization')
check(s:start(h.ctx)==true,'explicit start')
check(h.options.url=='https://github.com/login/device/code'and h.options.body=='client_id=Iv1.TESTONLY','fixed OAuth origin and copied setup')
check(h.options.headers.Authorization==nil and not h.options.url:find('client_id',1,true),'no bearer/query secret in code request')
check(s:start(h.ctx)==nil and s:poll(h.ctx)==nil,'one pending request')
local replay=h:respond(Host.code())
local status=s:status(h.ctx)
check(status.state=='authorizing'and status.user_code=='ABCD-EFGH'and status.device_code==nil,'only user-facing pairing info exposed')
status.repo='other/repo';check(s:status(h.ctx).repo=='example/docs','status copy cannot retarget session')
check(s:poll(h.ctx)==nil and h.calls==1,'no immediate poll')
h.time=4999;check(s:poll(h.ctx)==nil,'respect minimum polling interval')
h.time=5000;check(s:poll(h.ctx)==true,'poll at interval')
check(h.options.body:find('repository_id=77',1,true)and h.options.body:find('grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Adevice_code',1,true),'repository narrowing and form encoding')
h:respond({error='authorization_pending'});h.time=9999;check(s:poll(h.ctx)==nil,'pending does not cause tight retry')
h.time=10000;s:poll(h.ctx);h:respond({error='slow_down',interval=10})
h.time=19999;check(s:poll(h.ctx)==nil,'slow_down adds five seconds')
h.time=20000;s:poll(h.ctx);h:respond(Host.token())
check(s:status(h.ctx).state=='verifying'and h.options.url=='https://api.github.com/user','token alone is not connected')
check(h.options.headers.Authorization=='Bearer ghu_TESTONLY'and h.options.headers['X-GitHub-Api-Version']==Auth.API_VERSION,'App token and versioned API headers')
h:verify(s);check(s:status(h.ctx).connected and not s:status(h.ctx).busy,'verified account/private repo/branch connects')
status=s:status(h.ctx)
check(status.access_token==nil and status.refresh_token==nil and status.user_code==nil and next(h.ctx.state)==nil,'no credentials in status or persistent state')
check(s:start(h.ctx)==nil,'connected session cannot silently restart')
replay();check(s:status(h.ctx).connected,'stale code callback ignored')
local got,why
s:read(h.ctx,'čaj #1.md',function(_,v,e)got=v;why=e end);h:verify(s)
check(h.options.url=='https://api.github.com/repos/example/docs/contents/documents/%C4%8Daj%20%231.md?ref=main','UTF-8 basename URL-encoded once')
h:respond(F.file('čaj #1.md','Čaj\r\n'));check(got.bytes=='Čaj\r\n'and why==nil,'read exact saved bytes')
local before=h.calls
check(s:read(h.ctx,'../outside.md',function()end)==nil and h.calls==before,'traversal refused before network')
check(s:write(h.ctx,'ideas.md','\255',nil,function()end)==nil,'invalid upload bytes refused')
s:write(h.ctx,'ideas.md','Čaj\r\n',F.OLD,function(_,v,e)got=v;why=e end);h:verify(s)
local body=Native.decode(h.options.body)
check(h.options.method=='PUT'and body.sha==F.OLD and body.branch=='main'and Native.base64_decode(body.content)=='Čaj\r\n','bounded upload with blob SHA and exact content')
h:respond(F.written('documents/ideas.md'))
check(got.sha==F.NEW and got.fingerprint==Mock.hash('Čaj\r\n'),'only validated write receipt returned')
s:write(h.ctx,'ideas.md','new',F.NEW,function(_,v,e)got=v;why=e end);h:verify(s);h:respond({message='private error'},409)
check(got==nil and why=='remote_race'and s:status(h.ctx).connected,'409 never certifies sync or retries')
s:read(h.ctx,'ideas.md',function(_,v,e)got=v;why=e end);h:verify(s);h:respond({},404)
check(got.exists==false,'404 read is absent observation')
s:read(h.ctx,'ideas.md',function(_,v,e)got=v;why=e end);h:verify(s);h:respond({message='private'},429,{headers={['retry-after']='60'}})
check(got==nil and why=='rate_limited'and s:status(h.ctx).connected,'rate limit not mistaken for expired grant')
s:read(h.ctx,'ideas.md',function(_,v,e)got=v;why=e end);h:verify(s);h:respond({message='revoked secret'},401)
check(got==nil and why=='authorization_required'and not s:status(h.ctx).connected,'revoked token discarded')
before=h.calls;check(s:read(h.ctx,'ideas.md',function()end)==nil and h.calls==before,'revoked token cannot be reused')
-- Reject unexpected identities, broad grants, suspended installs and unsafe repos.
local cases={
 {1,function(v)v.login='another'end,'account_mismatch'},
 {2,function(v)v.total_count=2 end,'installation_scope_mismatch'},
 {2,function(v)v.installations[2]=v.installations[1]end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].app_id=99 end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].repository_selection='all'end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].suspended_at='2026-01-01'end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].suspended_at=nil end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].permissions.contents='read'end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].permissions.issues='write'end,'installation_scope_mismatch'},
 {2,function(v)v.installations[1].account.login='another'end,'installation_scope_mismatch'},
 {3,function(v)v.total_count=2 end,'repository_scope_mismatch'},
 {3,function(v)v.repositories[1].id=78 end,'repository_scope_mismatch'},
 {3,function(v)v.repositories[1].full_name='example/other'end,'repository_scope_mismatch'},
 {3,function(v)v.repositories[1].private=false end,'repository_scope_mismatch'},
 {4,function(v)v.visibility='internal'end,'repository_scope_mismatch'},
 {4,function(v)v.archived=true end,'repository_scope_mismatch'},
 {4,function(v)v.disabled=true end,'repository_scope_mismatch'},
 {4,function(v)v.id=78 end,'repository_scope_mismatch'},
 {4,function(v)v.full_name='another/repo'end,'repository_scope_mismatch'},
 {3,function(v)v.repositories[1].permissions.push=false end,'repository_scope_mismatch'},
 {5,function(v)v.name='other'end,'branch_mismatch'},
 {5,function(v)v.commit.sha='invalid'end,'branch_mismatch'},
}
for _,case in ipairs(cases)do
 local a,b=start();b:respond(Host.token());b:verify(a,{[case[1]]=case[2]})
 check(not a:status(b.ctx).connected and a:status(b.ctx).reason==case[3],'scope check '..case[3])
 local calls=b.calls;check(a:read(b.ctx,'ideas.md',function()end)==nil and b.calls==calls,'failed verification leaves no usable token')
end
for _,patch in ipairs({{access_token='ghp_TESTONLY'},{expires_in=0},{expires_in=28801},{token_type='other'},{scope='repo'},{access_token='ghu_bad\nheader'}})do
 local a,b=start();local token=Host.token();for k,v in pairs(patch)do token[k]=v end;b:respond(token)
 check(a:status(b.ctx).reason=='invalid_token_response'and b.calls==2,'bad or broad token rejected before API')
end
local a,b=start();local token=Host.token();token.expires_in=nil;b:respond(token)
check(a:status(b.ctx).reason=='invalid_token_response','non-expiring token refused')
for _,patch in ipairs({{verification_uri='https://attacker.test/device'},{user_code='bad code'},
 {device_code='short'},{expires_in=901},{interval=0}})do
 local x=Host.new();local auth=assert(Auth.new(Host.config(),primitives));auth:start(x.ctx)
 local d=Host.code();for k,v in pairs(patch)do d[k]=v end;x:respond(d)
 check(auth:status(x.ctx).reason=='invalid_device_response'and x.calls==1,'malformed or off-origin device response refused')
end
-- Optional fields omitted by the installation-list representation are fetched
-- from full repository metadata, not confused with a scope failure.
a,b=start();b:respond(Host.token());b:verify(a,{[3]=function(v)local r=v.repositories[1];r.visibility=nil;r.archived=nil;r.disabled=nil end})
check(a:status(b.ctx).connected,'smaller repository list representation supported')
for _,err in ipairs({'access_denied','expired_token','device_flow_disabled','incorrect_client_credentials','arbitrary private response'})do
 a,b=start();b:respond({error=err});check(not a:status(b.ctx).connected and a:status(b.ctx).reason~='arbitrary private response','OAuth error safely redacted')
end
a,b=start();b:respond('{}',200,{ok=false,err='io_error'});check(a:status(b.ctx).state=='offline','TLS failure does not authorize')
a,b=start();b:respond({message='private server details'},502)
check(a:status(b.ctx).http_status==502 and a:status(b.ctx).reason=='server_error','bounded HTTP status without response body')
a:disconnect();check(a:status(b.ctx).http_status==nil,'disconnect clears diagnostic status')
a,b=start();local cb=b:respond(Host.token());a:pause();check(b.cancelled==1 and a:status(b.ctx).state=='disconnected','pause cancels verification and clears session')
cb();check(a:status(b.ctx).state=='disconnected','late token callback cannot reconnect')
a,b=connect();a:read(b.ctx,'ideas.md',function()error('cancelled callback')end);a:disconnect()
check(b.cancelled==1 and not a:status(b.ctx).connected,'disconnect cancels operation')
a,b=connect();b.time=5000+(28800-60)*1000
check(a:status(b.ctx).reason=='session_expired'and not a:status(b.ctx).connected,'token expires conservatively before server deadline')
for _,status_code in ipairs({401,403})do
 a,b=connect();a:read(b.ctx,'ideas.md',function(_,v,e)got=v;why=e end);b:verify(a);b:respond({},status_code)
 check(got==nil and why==(status_code==401 and 'authorization_required'or 'access_forbidden')and not a:status(b.ctx).connected,'authorization failure blocks RAM grant '..status_code)
end
a,b=connect();a:read(b.ctx,'ideas.md',function(_,v,e)got=v;why=e end);b:verify(a)
b:respond({},403,{headers={['x-ratelimit-remaining']='0'}})
check(got==nil and why=='rate_limited'and a:status(b.ctx).connected,'403 rate limit preserves unexpired session')
a,b=connect();a:write(b.ctx,'ideas.md','saved',F.OLD,function(_,v,e)got=v;why=e end);b:verify(a)
b:respond('{}',200,{ok=false,err='timeout'})
check(got==nil and why=='timeout'and a:status(b.ctx).connected,'lost remote write response produces no success receipt')
a,b=connect();a:read(b.ctx,'ideas.md',function(_,v,e)got=v;why=e end);b:verify(a)
b.time=5000+(28800-60)*1000;b:respond(F.file('ideas.md','saved'))
check(got==nil and why=='session_expired'and not a:status(b.ctx).connected,'expiry during in-flight request cannot return success')
a,b=start();b.time=900000;b:respond(Host.token())
check(a:status(b.ctx).reason=='code_expired'and b.calls==2,'late token after code deadline refused')
local wrap=Host.new();wrap.time=2147483000;a=assert(Auth.new(Host.config(),primitives));a:start(wrap.ctx);wrap:respond(Host.code())
wrap.time=(2147483000+4999)&0x7fffffff;check(a:poll(wrap.ctx)==nil,'wrap-safe wait interval')
wrap.time=(2147483000+5000)&0x7fffffff;check(a:poll(wrap.ctx)==true,'wrap-safe due poll')
-- Every document operation revalidates privacy/scope before reading or writing.
a,b=connect();a:write(b.ctx,'ideas.md','saved',F.OLD,function(_,v,e)got=v;why=e end)
b:verify(a,{[3]=function(v)v.repositories[1].private=false end})
check(got==nil and why=='repository_scope_mismatch'and b.options.method=='GET','changed privacy prevents PUT')
return n
