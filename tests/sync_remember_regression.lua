local Auth=require('domain.sync_auth')
local Credentials=require('domain.sync_credentials')
local Session=require('domain.sync_session')
local UI=require('domain.sync_ui')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local Native=require('test_native')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local primitives={hash=Mock.hash,codec=Mock.codec}
local function setup(remember)
 local h=Host.new();local private=Mock.host();h.ctx.storage=private.ctx.storage
 h.ctx.state.github_sync_enabled=true;h.ctx.state.github_sync_remember=remember;h.ctx.invalidate=function()h.invalidated=(h.invalidated or 0)+1 end
 h.private=private;local auth=assert(Auth.new(Host.config(),primitives))
 auth:start(h.ctx);h:respond(Host.code());h.time=5000;auth:poll(h.ctx);h:respond(Host.token());h:verify(auth)
 assert(auth:status(h.ctx).connected);return auth,h
end
local a,h=setup(false)
check(h.private.writes==0 and next(h.private.files)==nil,'RAM-only option never writes credentials')
h.ctx.state.github_sync_remember=true;check(a:remember(h.ctx),'enable Remember after current sign-in')
local raw=h.private.files[Credentials.FILE];local record=Native.decode(raw)
check(record.refresh_token=='ghr_TESTONLY'and record.access_token=='ghu_TESTONLY','explicit remember saves bounded synthetic access and refresh credentials')
check(not Native.encode(h.ctx.state):find('TESTONLY',1,true)and h.ctx.state.access_token==nil and h.ctx.state.refresh_token==nil,'secrets never enter state')
local public=a:status(h.ctx)
check(public.access_token==nil and public.refresh_token==nil and public.remembered,'public status contains no reusable credentials')
a:disconnect();check(h.private.files[Credentials.FILE]==raw,'session teardown keeps consented private record')
-- A completely new Auth instance models a destroyed VM and fresh application.
a=assert(Auth.new(Host.config(),primitives));local count=h.calls
check(a:restore(h.ctx)==true and h.options.url=='https://api.github.com/user','new app reuses saved access token; no device-code endpoint')
h:verify(a);check(a:status(h.ctx).connected and h.calls==count+5,'restored session rechecks all account/App/private-repo/branch grants')
check(h.private.files[Credentials.FILE]==raw,'valid access token reused without a rotation/write')
a:disconnect();h.epoch=h.epoch+28800;h.time=0;a=assert(Auth.new(Host.config(),primitives))
check(a:restore(h.ctx)==true and a:status(h.ctx).state=='refreshing','expired access token starts automatic refresh')
check(h.options.url=='https://github.com/login/oauth/access_token'and not h.options.body:find('client_secret',1,true)
 and h.options.body:find('grant_type=refresh_token',1,true)and h.options.body:find('refresh_token=ghr_TESTONLY',1,true),'device-flow refresh requires no app secret or external web page')
local token=Host.token();token.access_token='ghu_ROTATED';token.refresh_token='ghr_ROTATED';h:respond(token)
record=Native.decode(h.private.files[Credentials.FILE]);check(record.refresh_token=='ghr_ROTATED','rotated credentials committed before grant-validation requests')
h:verify(a);check(a:status(h.ctx).connected and a:status(h.ctx).remembered,'renewed session verified')
-- Offline refresh preserves the last complete record and performs no retry.
a:disconnect();h.epoch=h.epoch+28800;a=assert(Auth.new(Host.config(),primitives));a:restore(h.ctx)
raw=h.private.files[Credentials.FILE];count=h.calls;h:respond('{}',200,{ok=false,err='no_network'})
check(a:status(h.ctx).state=='offline'and h.private.files[Credentials.FILE]==raw and h.calls==count,'offline refresh preserves credential without a retry loop')
check(a:restore(h.ctx)==true,'manual retry can use saved refresh credential')
h:respond({error='bad_refresh_token'})
check(not a:status(h.ctx).connected and h.private.files[Credentials.FILE]==nil,'revoked refresh grant is removed and fails closed')
check(a:restore(h.ctx)==false,'removed grant does not repeatedly try invalid credentials')
a,h=setup(true);a:disconnect();a=assert(Auth.new(Host.config(),primitives));a:restore(h.ctx)
h:verify(a,{[1]=function(v)v.login='another'end})
check(not a:status(h.ctx).connected and h.private.files[Credentials.FILE]==nil,'wrong account on restore clears saved grant')
a,h=setup(true);a:disconnect();a=assert(Auth.new(Host.config(),primitives));a:restore(h.ctx);h:respond({},401)
check(a:status(h.ctx).state=='refreshing'and h.private.files[Credentials.FILE]~=nil,'401 tries refresh before discarding a saved grant')
h:respond(Host.token());h:verify(a);check(a:status(h.ctx).connected,'401 renewal restores access without browser approval')
a,h=setup(true);raw=h.private.files[Credentials.FILE];h.epoch=h.epoch-1;a:disconnect();a=assert(Auth.new(Host.config(),primitives));count=h.calls
check(a:restore(h.ctx)==nil and h.calls==count and h.private.files[Credentials.FILE]==raw,'backward/invalid clock does not extend credentials or delete them')
h.ctx.clock.now=function()return {valid=false}end
check(a:restore(h.ctx)==nil and h.calls==count,'invalid clock blocks restore without network')
a,h=setup(true);h.epoch=h.epoch+15897601;a:disconnect();a=assert(Auth.new(Host.config(),primitives));count=h.calls
check(a:restore(h.ctx)==nil and h.private.files[Credentials.FILE]==nil and h.calls==count,'expired refresh token requires new authorization without network attempts')
a,h=setup(true);h.private.fail_write=true;h.epoch=h.epoch+28800;a:disconnect();a=assert(Auth.new(Host.config(),primitives));a:restore(h.ctx)
token=Host.token();token.access_token='ghu_NEWVALUE';token.refresh_token='ghr_NEWVALUE';h:respond(token);h:verify(a)
check(a:status(h.ctx).connected and not a:status(h.ctx).remembered and a:status(h.ctx).remember_error=='connection_write_failed','failed rotated-token write remains visible; RAM session still usable: '..Native.encode(a:status(h.ctx)))
h.private.fail_write=false;check(a:remember(h.ctx)and Native.decode(h.private.files[Credentials.FILE]).refresh_token=='ghr_NEWVALUE','explicit Remember retries saving current rotated credential')
h.private.fail_remove=true;check(a:forget(h.ctx)==nil and h.private.files[Credentials.FILE]~=nil,'failed Forget cannot claim removal')
h.private.fail_remove=false;check(a:forget(h.ctx)and h.private.files[Credentials.FILE]==nil,'Forget removes and verifies credential absence')
-- Reject malformed, oversized and retargeted records without network or resets.
a,h=setup(true);raw=h.private.files[Credentials.FILE]
for _,bad in ipairs({'broken',string.rep('x',2049),raw:gsub('example/docs','other/docs'),raw:gsub('TESTONLY','bad\\nsecret')})do
 h.private.files[Credentials.FILE]=bad;a=assert(Auth.new(Host.config(),primitives));count=h.calls
 check(a:restore(h.ctx)==nil and h.calls==count and h.private.files[Credentials.FILE]==bad,'invalid/cross-scope record preserved for explicit Forget')
end
-- Actual UI: code is redrawn after a system cover and after a second start.
h=Host.new();h.ctx.state.github_sync_enabled=true;h.ctx.invalidate=function()end
h.ctx.screen={width=480,height=800};local font={line_height=24};local captured
local u=UI.new({},font,font,{config=Host.config(),primitives=primitives,auth_factory=function(c,p)captured=Auth.new(c,p);return captured end})
local function press(code)u:input(h.ctx,{type='key',phase='down',code=code})end
u:open(h.ctx);press('ArrowDown');press('Enter');h:respond(Host.code());u:tick(h.ctx)
local drawn={};local g=setmetatable({text_box=function(_,x,y,w,z,text)drawn[text]=true end},{__index=function()return function()end end})
u:draw(h.ctx,g);check(drawn['Sign-in code: ABCD-EFGH\nApprove the App in your browser.']and drawn['github.com/login/device'],'sign-in code has a dedicated full visible line')
u:pause(h.ctx);u:resume(h.ctx);drawn={};u:draw(h.ctx,g)
check(drawn['Sign-in code: ABCD-EFGH\nApprove the App in your browser.']and captured:status(h.ctx).user_code=='ABCD-EFGH','temporary system cover no longer clears sign-in code')
u:leave(h.ctx);check(captured:status(h.ctx).user_code==nil,'actual exit clears incomplete code flow from RAM')
u=UI.new({},font,font,{config=Host.config(),primitives=primitives});u:open(h.ctx);press('ArrowDown');press('Enter')
local code=Host.code();code.user_code='WXYZ-1234';h:respond(code);u:tick(h.ctx);drawn={};u:draw(h.ctx,g)
check(drawn['Sign-in code: WXYZ-1234\nApprove the App in your browser.']and not drawn['Sign-in code: ABCD-EFGH\nApprove the App in your browser.'],'second app instance displays fresh code rather than cached old header')
-- Session restore is lazy: opening writing remains network-free, opening sync restores.
a,h=setup(true);a:disconnect();count=h.calls
local session=Session.new({}, {config=Host.config(),primitives=primitives})
check(h.calls==count,'new writer session does not access network')
session:open(h.ctx);check(h.calls==count+1 and h.options.url=='https://api.github.com/user','opening sync automatically restores remembered connection')
session:leave(h.ctx)
return n
