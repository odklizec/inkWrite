local UI=require('domain.sync_ui')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function setup(mode,remember)
 local h={starts=0,restores=0,history=0,lists=0,reads=0,connected=false,busy=false}
 local auth={}
 function auth:status()return {state=h.connected and 'connected'or (h.code and 'authorizing'or (h.busy and 'verifying'or 'disconnected')),connected=h.connected,busy=h.busy,user_code=h.code,reason=h.reason}end
 function auth:restore()h.restores=h.restores+1;if mode=='saved'then h.busy=true;return true end;return false end
 function auth:start()h.starts=h.starts+1;h.code='ABCD-EFGH';return true end
 function auth:disconnect()h.connected=false;h.busy=false;h.code=nil;h.reason=nil end
 function auth:cancel_operation()end
 function auth:poll()end
 function auth:history(c,name,page,anchor,done)h.history=h.history+1;h.name=name;done(c,{rows={},page=page,anchor=string.rep('a',40)});return true end
 function auth:list(c,done)h.lists=h.lists+1;done(c,{});return true end
 local c={state={github_sync_enabled=true,github_sync_remember=remember,github_sync_connection_choice=true},screen={width=480,height=800},invalidate=function()end}
 local small={line_height=24};local ui={line_height=30}
 local u=UI.new({describe=function()return {name='ideas.md'}end},small,ui,{primitives={},auth_factory=function()return auth end})
 function h:approve()self.connected=true;self.busy=false;self.code=nil;self.reason=nil;u:tick(c)end
 function h:key(code)u:input(c,{type='key',code=code,phase='down'})end
 h.u=u;h.c=c;h.small=small;h.ui=ui;u:open(c);return h
end
local h=setup('code',false);local u,c=h.u,h.c;u.focus=3;h:key('Enter')
check(h.starts==1 and u.pending and u.page=='main'and h.history==0,'History starts device approval automatically and waits')
u:tick(c);check(h.starts==1 and h.history==0,'pending approval does not start duplicate authorization or data requests')
h:approve();check(h.history==1 and h.name=='ideas.md'and u.page=='history'and not u.pending,'approved connection automatically continues history once')
u:tick(c);u:tick(c);check(h.history==1,'ticks never replay completed action')
h=setup('saved',true);u,c=h.u,h.c;u.focus=2;h:key('Enter')
check(h.restores==1 and h.starts==0 and u.pending and h.lists==0,'Browse waits for in-progress remembered restore without another Connect click')
h:approve();check(h.lists==1 and u.page=='remote','Browse resumes after saved connection verifies')
h=setup('code',false);u,c=h.u,h.c;u.focus=3;h:key('Enter');h:key('Escape');h:approve()
check(not u.pending and h.history==0,'Back cancels queued action and prevents later approval from continuing it')
h=setup('code',false);u,c=h.u,h.c;u.focus=3;h:key('Enter');h:key('Enter');h:approve()
check(not u.pending and h.history==0,'Cancel sign-in cancels queued action')
h=setup('saved',true);u,c=h.u,h.c;u.focus=3;h:key('Enter');h.busy=false;h.reason='no_network';u:tick(c);u:tick(c)
check(not u.pending and h.restores==1 and h.history==0,'failure clears pending action with no automatic retry loop')
h=setup('code',false);u,c=h.u,h.c;u.focus=5;h:key('Enter');h:approve()
check(h.history==0 and h.lists==0,'manual Connect does not perform an unrequested operation')
h=setup('code',false);u,c=h.u,h.c;u.focus=3;h:key('Enter');h.code=nil;u:tick(c)
check(not u.pending and h.starts==1,'a failed start without a reason cannot retain a latent action')
-- Initial consent remains explicit, but continues the requested action afterwards.
h=setup('code',false);u,c=h.u,h.c;c.state.github_sync_connection_choice=nil;u.focus=3;h:key('Enter')
check(u.page=='connect'and h.starts==0 and u.pending,'first use asks connection choice without losing requested History')
u.focus=3;h:key('Enter');h:approve();check(h.history==1 and not c.state.github_sync_remember,'session-only choice continues History after approval')
h=setup('code',false);u,c=h.u,h.c;c.state.github_sync_connection_choice=nil;u.focus=3;h:key('Enter');h:key('Enter');h:approve()
check(h.history==0 and not u.pending,'Cancel connection choice drops requested History')
-- Existing approval is reused for a selected action.
h=setup('code',false);u,c=h.u,h.c;u.session:connect(c);u:tick(c);u.pending=nil
-- The approval view deliberately exposes only Cancel, so no stale row can fire.
local labels={};local texts={};local lines={}
local g=setmetatable({text_box=function(_,x,y,w,ht,t)labels[t]=true end,text=function(_,x,y,t,o)texts[t]={x=x,y=y,options=o}end,line=function(_,...)lines[#lines+1]={...}end},{__index=function()return function()end end})
u:draw(c,g);check(labels['Cancel sign-in']and not labels['Version history: current document...'],'approval screen owns its input')
h:approve();u.page='remote';for i=1,40 do u.session.rows[i]={name='file-'..i..'.md'}end;u.focus=15;u:tick(c);labels={};texts={};u:draw(c,g)
check(not labels.Back and texts.Back and texts.Prev and texts.Next,'nested list has only the universal footer Back')
check(texts.Back.options.font==h.ui and texts.Prev.options.font==h.ui and texts.Next.options.font==h.ui,'footer uses normal app UI font for every control')
check(texts.Prev.x==240 and texts.Prev.options.align=='center'and texts.Next.x==460 and texts.Next.options.align=='right','Prev centered and Next anchored to right content edge')
check(#lines>0 and texts.Back.options.valign=='middle','footer has ordinary pager divider and vertical alignment')
for _,page in ipairs({'main','remote','history','revoke'})do
 u.page=page;u.history_name='ideas.md';u:tick(c);labels={};u:draw(c,g);check(not labels.Back,'no top Back row on '..page)
end
return n
