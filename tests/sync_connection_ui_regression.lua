local UI=require('domain.sync_ui')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function setup()
 local code,started=nil,0
 local auth={}
 function auth:status()return {state=code and 'authorizing'or 'disconnected',connected=false,busy=false,user_code=code}end
 function auth:restore()return false end
 function auth:start()started=started+1;code='ABCD-EFGH';return true end
 function auth:disconnect()code=nil end
 local c={state={},screen={width=480,height=800},invalidate=function()end}
 local font={line_height=24}
 local u=UI.new({},font,font,{primitives={},auth_factory=function()return auth end})
 u:open(c)
 local function key(code)u:input(c,{type='key',code=code,phase='down'})end
 return u,c,key,function()return started end
end
local u,c,key,calls=setup();key('Enter')
check(u.page=='connect'and u.focus==1 and calls()==0,'Sync before initial connection opens single setup choice, default Cancel')
key('Enter');check(u.page=='main'and not c.state.github_sync_remember and not c.state.github_sync_enabled and calls()==0,'Cancel setup does not enable sync, store credentials or start requests')
key('Enter');key('ArrowDown');key('Enter')
check(c.state.github_sync_remember==true and c.state.github_sync_enabled==true and c.state.github_sync_connection_choice==true and calls()==1,'explicit Remember and connect combines setup with one sign-in')
local labels={};local g=setmetatable({text_box=function(_,x,y,w,h,t)labels[t]=true end},{__index=function()return function()end end})
u:draw(c,g);check(labels['Sign-in code: ABCD-EFGH\nApprove the App in your browser.'],'combined setup reaches normal QR/code approval screen')
u,c,key,calls=setup();key('Enter');key('ArrowDown');key('ArrowDown');key('Enter')
check(c.state.github_sync_enabled==true and not c.state.github_sync_remember and calls()==1,'session-only setup remains available without saved-credential consent')
key('Enter');u.focus=4;key('Enter')
check(calls()==2 and u.page=='main','remembered session-only preference skips repeated setup choice')
-- Remote-only update view always starts with Cancel and keeps copy alternative.
u,c,key,calls=setup();u.session.pending_update={name='ideas.md',sha=string.rep('a',40)};u:tick(c)
check(u.page=='update'and u.focus==1,'remote update requires a deliberate choice with default Cancel')
labels={};u:draw(c,g);check(labels['Update local document']and labels['Download as local copy'],'update offer provides replace-with-backup and copy choices')
key('Enter');check(u.page=='main'and not u.session.pending_update and calls()==0,'Cancel update preserves local state without network')
return n
