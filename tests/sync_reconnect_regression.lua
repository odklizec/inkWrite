local Auth=require('domain.sync_auth')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local Credentials=require('domain.sync_credentials')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local primitives={hash=Mock.hash,codec=Mock.codec}
local function saved()
 local h=Host.new();h.private=Mock.host();h.ctx.storage=h.private.ctx.storage
 h.ctx.state.github_sync_remember=true;h.ctx.invalidate=function()end
 local a=Auth.new(Host.config(),primitives);a:start(h.ctx);h:respond(Host.code());h.time=5000;a:poll(h.ctx);h:respond(Host.token());h:verify(a)
 assert(a:status(h.ctx).connected and a:status(h.ctx).remembered);a:disconnect();return h
end
for _,days in ipairs({1,2,3,100})do
 local h=saved();h.epoch=h.epoch+days*86400;h.time=0
 local a=Auth.new(Host.config(),primitives);local count=h.calls
 check(a:restore(h.ctx)==true and h.options.body:find('grant_type=refresh_token',1,true),'fresh VM renews after '..days..' days')
 h:respond(Host.token());h:verify(a)
 check(a:status(h.ctx).connected and a:status(h.ctx).remembered and h.calls==count+6,'multi-day reentry never requests browser code')
end
-- Local expiry can disagree with server expiry: retain refresh and renew once.
local h=saved();local a=Auth.new(Host.config(),primitives);a:restore(h.ctx);h:respond({},401)
check(a:status(h.ctx).state=='refreshing'and h.private.files[Credentials.FILE]~=nil,'rejected access token retains refresh grant')
local token=Host.token();token.access_token='ghu_RECOVERED';token.refresh_token='ghr_RECOVERED';h:respond(token);h:verify(a)
check(a:status(h.ctx).connected,'one renewal recovers rejected access')
-- A second 401 after renewal must not cause an unbounded refresh loop.
a:disconnect();a=Auth.new(Host.config(),primitives);a:restore(h.ctx);h:respond({},401);h:respond(Host.token());local count=h.calls;h:respond({},401)
check(not a:status(h.ctx).connected and h.calls==count and h.private.files[Credentials.FILE]~=nil,'repeated rejection blocks access without refresh loop or destructive reset')
-- Forbidden/secondary-limit/configuration errors do not prove refresh revocation.
h=saved();local raw=h.private.files[Credentials.FILE];a=Auth.new(Host.config(),primitives);a:restore(h.ctx);h:respond({},403)
check(a:status(h.ctx).reason=='access_forbidden'and h.private.files[Credentials.FILE]==raw,'403 preserves saved authorization for retry')
h=saved();raw=h.private.files[Credentials.FILE];h.epoch=h.epoch+86400;a=Auth.new(Host.config(),primitives);a:restore(h.ctx);count=h.calls
h:respond({error='incorrect_client_credentials'})
check(a:status(h.ctx).reason=='refresh_failed'and h.private.files[Credentials.FILE]==raw and h.calls==count,'refresh configuration failure preserves record without browser fallback or retries')
a:restore(h.ctx);h:respond({error='bad_refresh_token'})
check(h.private.files[Credentials.FILE]==nil and not a:status(h.ctx).connected,'explicitly revoked refresh token is still forgotten')
return n
