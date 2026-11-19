local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local Config=require('domain.sync_config')
check(Config.client_id=='Iv23licpwNgrQGcsizGF'and Config.app_id==5735892,'owner public App IDs')
check(Config.scope.repo=='odklizec/inkwrite-docs'and Config.scope.branch=='main'and Config.repository_id==1455886532,'verified private repository binding')
local starts,pauses,disconnects=0,0,0
local status={state='disconnected',busy=false}
package.loaded['domain.sync_auth']={new=function(config)
 check(config==Config,'real public setup passed to session')
 return {status=function()return status end,start=function()starts=starts+1;status={state='requesting_code',busy=true};return true end,
   disconnect=function()disconnects=disconnects+1;status={state='disconnected',busy=false}end,
   pause=function()pauses=pauses+1;status={state='disconnected',busy=false}end,
   poll=function()check(false,'poll should not be called outside authorizing')end}
end}
package.loaded['domain.sync_primitives']={new=function()return {}end}
local drawing=false;local fontopens=0;local invalidates=0;local quits=0
local font={line_height=28}
local ctx={screen={width=480,height=800},fonts={size=function()check(not drawing,'no font work during draw');fontopens=fontopens+1;return font end},
 budget={extend=function()check(not drawing,'no preparation during draw')end},set_tick=function(_,ms)check(ms==1000,'bounded polling tick')end,
 invalidate=function()invalidates=invalidates+1 end,quit=function()quits=quits+1 end}
local Check=require('auth_check');Check.load(ctx)
check(starts==0 and fontopens==2,'no automatic network sign-in on load')
local labels={};local g={clear=function()end,rect=function()end,text=function(_,x,y,s)labels[#labels+1]=s end,
 text_box=function(_,x,y,w,h,s)labels[#labels+1]=s;check(h>=font.line_height,'text accommodates font line height')end}
drawing=true;Check.draw(ctx,g);drawing=false
check(fontopens==2 and starts==0,'draw only presents prepared state')
check(Check.input(ctx,{type='key',phase='down',key='ok'})==false and starts==0,'ignore key-down')
Check.input(ctx,{type='key',phase='up',key='ok'});check(starts==1,'Classic OK starts explicit sign-in')
Check.input(ctx,{type='key',phase='up',key='ok'});check(disconnects==1,'OK cancels pending sign-in')
local before=invalidates;Check.tick(ctx);check(invalidates==before,'idle tick does not redraw unchanged state')
Check.pause(ctx);Check.resume(ctx);check(pauses==1,'pause clears session before resume')
Check.input(ctx,{type='pointer',phase='up',gesture='tap',x=40,y=750});check(starts==2,'Pro touch starts sign-in')
Check.input(ctx,{type='pointer',phase='up',gesture='tap',x=300,y=750});check(quits==1,'reachable touch exit')
Check.input(ctx,{type='key',phase='up',key='back'});check(quits==2,'Classic Back exits')
Check.leave(ctx);check(disconnects==4,'exit/leave discard session')
return n
