local n=0
local function check(x,msg)n=n+1;assert(x,msg)end
local drawing=false;local layouts=0;local extended=0;local leaving=false
local Layout=require('domain.layout');local rows=Layout.rows
Layout.rows=function(...)assert(not drawing,'wrapping inside draw');layouts=layouts+1;return rows(...)end
package.loaded['domain.stats']={new=function()return setmetatable({},{__index=function()return function()end end})end,duration=tostring}
local text=string.rep('ž',16384)
local ctx={state={last='long.md',cursor=#text},screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}},clock={millis=function()return 0 end,now=function()return {valid=false}end},input={listen=function()return true end},capabilities={ttf=true}}
local stored={};local queue={};local invalidations=0;local quits=0
ctx.storage={read=function(_,k)if stored[k]then return stored[k]end;return nil,'not_found'end,write=function(_,k,v)stored[k]=v;return true end,remove=function(_,k)stored[k]=nil;return true end}
ctx.files={path='/test',size=function(_,k)if k=='long.md'then return #text end;return nil,'not_found'end,read=function()return text end,write=function(_,k,v)text=v;return true end}
ctx.budget={extend=function()assert(not drawing and not leaving);extended=extended+1;return true end}
ctx.invalidate=function()invalidations=invalidations+1 end;ctx.set_tick=function()end;ctx.defer_full_refresh=function()end;ctx.quit=function()quits=quits+1 end
ctx.after=function(_,ms,fn)local t={fn=fn,cancel=function(self)self.cancelled=true end};queue[#queue+1]=t;return t end
local function drain()local todo=queue;queue={};for _,t in ipairs(todo)do if not t.cancelled then t.fn(ctx)end end end
local f={line_height=36,measure=function(_,s)return (utf8.len(s) or 0)*18 end}
ctx.fonts={medium=f,large=f,small=f}
local App=require('domain.app');App.load(ctx)
local A;for i=1,50 do local name,value=debug.getupvalue(App.draw,i);if not name then break end;if name=='A'then A=value;break end end
check(A and A.editor.layout_revision==A.editor.buffer.revision,'initial prepared')
check(A.editor.buffer.size==32768,'maximum document loaded');check(extended>0,'budget requested')
local drawn={};local g=setmetatable({text=function(_,x,y,s)drawn[#drawn+1]=s end},{__index=function()return function()end end})
local function draw()drawing=true;App.draw(ctx,g);drawing=false end
local count=layouts;draw();draw();check(layouts==count,'cached draw')
for _,r in ipairs(A.editor.rows)do check(utf8.len(r.text)~=nil,'UTF8 row');check(A.editor.buffer:is_boundary(r.a) and A.editor.buffer:is_boundary(r.z),'UTF8 bounds')end
App.input(ctx,{type='key',source='keyboard',phase='down',code='KeyA',mods={ctrl=true}})
App.input(ctx,{type='key',source='keyboard',phase='down',code='KeyX',text='abc ž',mods={}})
check(A.editor.buffer:text()=='abc ž','selected replacement');check(A.editor.redraw_timer~=nil,'coalesced frame retained')
count=layouts;drain();check(layouts>count,'timer prepared edit');count=layouts;draw();check(layouts==count,'edited draw read only')
for _,view in ipairs({'typography','help','files_help','font_help'})do
  A.view=view;App.input(ctx,{type='noop'});count=layouts;draw();draw();check(layouts==count,view..' prepared')
end
A.view='editor';App.input(ctx,{type='noop'});draw()
ctx.screen.width=800;ctx.screen.height=480;count=layouts;draw();check(layouts==count,'rotation draw queues work');check(A.editor.touch_geometry==nil,'stale touch disabled')
check(A.prepare_timer~=nil,'one prepare queued');local queued=#queue;draw();check(#queue==queued,'no duplicate timer');drain();draw();check(A.editor.touch_geometry~=nil,'rotation published')
A.body_font={line_height=64,measure=function(_,s)return (utf8.len(s) or 0)*32 end};A.spacing=14;A.margin=56
App.resume(ctx);count=layouts;draw();check(layouts==count,'largest font prepared on resume')
App.input(ctx,{type='key',key='back',phase='up'});check(A.close_modal and A.close_modal.choice==1,'safe dirty close')
App.input(ctx,{type='key',key='back',phase='up'});check(A.close_modal==nil and quits==0,'cancel stays open')
App.pause(ctx);check(stored['recovery.txt']~=nil,'pause recovery')
leaving=true;App.leave(ctx);leaving=false;check(quits==0,'lifecycle no forced close')
return n
