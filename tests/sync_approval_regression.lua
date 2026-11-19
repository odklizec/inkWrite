local UI=require('domain.sync_ui')
local QR=require('domain.approval_qr')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
check(QR.url=='https://github.com/login/device'and QR.size==37 and #QR.rects<512,'fixed official public URL, quiet zone and bounded drawing data')
for _,d in ipairs({{480,800},{800,480}})do for _,height in ipairs({24,44})do
 local code='ABCD-EFGH';local auth={};local ctx={state={github_sync_enabled=true},screen={width=d[1],height=d[2],occlusion={left=8,right=8,top=8,bottom=8}},invalidate=function()end}
 function auth:status()return {state=code and 'authorizing'or 'disconnected',connected=false,user_code=code}end
 function auth:restore()return false end;function auth:start()return true end;function auth:disconnect()code=nil end
 local font={line_height=height};local u=UI.new({},font,font,{primitives={},auth_factory=function()return auth end})
 u:open(ctx);u.session:connect(ctx);u:resume(ctx)
 local fills,caption,commands=0,false,0
 local g=setmetatable({rect=function(_,x,y,w,h,opts)
   commands=commands+1;check(x>=8 and y>=8 and x+w<=d[1]-8 and y+h<=d[2]-8,'QR and controls remain in visible bounds')
   if opts.fill then fills=fills+1 end
 end,text_box=function(_,x,y,w,h,t)
   commands=commands+1;if t:find('Approve the App in your browser.',1,true)then caption=true end
 end},{__index=function()return function()commands=commands+1 end end})
 u:draw(ctx,g)
 check(fills==#QR.rects+1 and caption and commands<1024,'QR appears below approval message without exceeding command limit')
 u:input(ctx,{type='key',code='Enter',phase='down'});fills=0;u:draw(ctx,g)
 check(code==nil and fills==0,'Cancel sign-in removes QR and code')
end end
return n
