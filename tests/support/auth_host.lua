-- Synthetic GitHub responses. No credentials, HTTP or document storage.
local Native=require('test_native')
local M={}
function M.config()return {client_id='Iv1.TESTONLY',app_id=42,login='example',scope={repo='example/docs',branch='main'},repository_id=77}end
function M.code()return {device_code=string.rep('a',40),user_code='ABCD-EFGH',verification_uri='https://github.com/login/device',expires_in=900,interval=5}end
function M.token()return {access_token='ghu_TESTONLY',token_type='bearer',scope='',expires_in=28800,refresh_token='ghr_TESTONLY'}end
function M.user()return {login='example',id=12}end
function M.installation()return {total_count=1,installations={{id=7,app_id=42,account={login='example'},repository_selection='selected',suspended_at=Native.null,permissions={contents='write',metadata='read'}}}}end
function M.repositories()return {total_count=1,repositories={{id=77,full_name='example/docs',private=true,visibility='private',archived=false,disabled=false,permissions={push=true}}}}end
function M.repository()return M.repositories().repositories[1]end
function M.branch()return {name='main',commit={sha=string.rep('b',40)}}end
function M.new()
 local h={time=0,calls=0,cancelled=0,extended=0};local pending
 h.ctx={state={},json={null=Native.null,encode=function(_,v)return Native.encode(v)end,decode=function(_,v)return Native.decode(v)end},clock={},net={},budget={}}
 h.ctx.clock.millis=function()return h.time end
 h.ctx.budget.extend=function()h.extended=h.extended+1;return true end
 h.ctx.net.request=function(_,opts,fn)
   if pending then return nil,'busy'end
   h.calls=h.calls+1;h.options=opts
   pending={fn=fn};local job=pending
   function job:cancel()h.cancelled=h.cancelled+1;if pending==self then pending=nil end end
   return job
 end
 function h:respond(value,status,patch)
   assert(pending,'no request');local fn=pending.fn;pending=nil
   local body=type(value)=='string'and value or Native.encode(value)
   local result={ok=true,status=status or 200,body=body,bytes=#body,headers={}}
   for k,v in pairs(patch or {})do result[k]=v end
   fn(self.ctx,result);return function()fn(self.ctx,result)end
 end
 function h:verify(s,patches)
   local fixtures={M.user(),M.installation(),M.repositories(),M.repository(),M.branch()}
   for i,v in ipairs(fixtures)do if patches and patches[i]then patches[i](v)end;self:respond(v);if s:status(self.ctx).state~='verifying'then break end end
 end
 return h
end
return M
