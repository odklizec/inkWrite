local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local drawing=false
local Layout=require('domain.layout');local rows=Layout.rows
Layout.rows=function(...)assert(not drawing,'layout during draw');return rows(...)end
package.loaded['domain.stats']={new=function()return setmetatable({saved=0},{__index=function()return function()end end})end}
local ctx={state={last='test.md'},time=0,screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}},fonts={},input={listen=function()return true end},clock={},budget={extend=function()assert(not drawing)end}}
local files={['test.md']='hello ž world\nsecond line'};local private={};local writes=0;local timers={}
ctx.clock.millis=function()return ctx.time end;ctx.clock.now=function()return {valid=false}end
local font={line_height=24,measure=function(_,s)check(utf8.len(s)~=nil,'valid UTF8 measurement');return utf8.len(s)*12 end}
ctx.fonts={medium=font,large=font,small=font}
ctx.storage={read=function(_,k)if private[k]then return private[k]end;return nil,'not_found'end,write=function(_,k,v)private[k]=v;return true end,remove=function(_,k)private[k]=nil;return true end}
ctx.files={path='/test',size=function(_,k)if files[k]then return #files[k]end;return nil,'not_found'end,read=function(_,k,a,z)if files[k]then return files[k]:sub(a+1,a+z)end;return nil,'not_found'end,write=function(_,k,v)if ctx.fail_write then return nil,'io_error'end;files[k]=v;writes=writes+1;return true end}
ctx.invalidate=function()end;ctx.set_tick=function()end;ctx.defer_full_refresh=function()end
ctx.after=function(_,ms,fn)if ctx.fail_timer then return nil,'limit_exceeded'end;local t={due=ctx.time+ms,fn=fn,cancel=function(self)self.cancelled=true end};timers[#timers+1]=t;return t end
local function advance(t)ctx.time=t;local todo=timers;timers={};for _,v in ipairs(todo)do if not v.cancelled then if v.due<=t then v.fn(ctx)else timers[#timers+1]=v end end end end
local App=require('domain.app');App.load(ctx)
local A;for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then A=v;break end end
local drawn={};local g=setmetatable({text=function(_,x,y,s)drawn[#drawn+1]=s end,text_box=function(_,x,y,w,h,s)drawn[#drawn+1]=s end},{__index=function()return function()end end})
local function draw()drawn={};drawing=true;App.draw(ctx,g);drawing=false;for _,s in ipairs(drawn)do check(not s:find('Preparing text',1,true),'typing must retain editor')end end
local function key(code,text,mods)App.input(ctx,{type='key',source='keyboard',phase='down',code=code,text=text,mods=mods or {}})end
local function find(s)for _,v in ipairs(drawn)do if v==s then return true end end end
draw();check(find('hello ž world'),'initial text')
key('KeyA',nil,{ctrl=true});draw();local old=A.prepared
check(A.anchor==0 and A.buffer.pos==A.buffer.size,'full document selected')
key('KeyQ','q');check(A.buffer:text()=='q','replacement live')
draw();check(A.prepared==old and find('hello ž world'),'old snapshot survives replacement');check(A.touch_revision~=A.buffer.revision,'stale touch tagged honestly')
check(A.prepare_timer==nil,'typing adds no preparation fallback')
advance(160);local prepared=A.prepared;check(prepared.revision==A.buffer.revision,'burst publishes latest revision')
key('KeyX','x');draw();check(A.prepared==prepared and find('q'),'edit after prepare before draw retains q');check(not find('qx'),'no mixed new text')
advance(240);draw();check(find('qx'),'next deadline publishes new text')
for i=1,200 do ctx.time=240+i*40;key('KeyA','a');if i%2==0 then advance(ctx.time)end;draw()end
advance(ctx.time+80);draw();check(A.prepared.revision==A.buffer.revision,'continuous typing eventually current')
key('KeyA','a');draw();key('KeyA','a');draw();local p=A.buffer.pos
App.input(ctx,{type='pointer',phase='up',gesture='tap',x=40,y=90});check(A.buffer.pos==p,'stale tap cannot move caret')
key('KeyA','a');draw();check(A.prepare_timer==nil,'notice geometry prepares before drawing even during burst')
-- Current cloud policy: 5 idle seconds; continuously dirty at most 120 s.
ctx.time=10000;key('KeyS',nil,{ctrl=true});local base=writes
ctx.time=11000;key('KeyZ','z');advance(11080)
ctx.time=15999;App.tick(ctx);check(writes==base,'no save before 5 idle seconds')
ctx.time=16000;App.tick(ctx);check(writes==base+1 and not A.dirty,'save at 5 seconds')
ctx.time=20000;key('KeyA','a');local start=writes
for t=21000,139000,1000 do ctx.time=t;key('KeyA','a');App.tick(ctx);check(writes==start,'no early continuous save')end
ctx.time=139999;key('KeyA','a');App.tick(ctx);check(writes==start,'no forced save before 120 seconds')
ctx.time=140000;key('KeyA','a');App.tick(ctx);check(writes==start+1,'continuous save at 120 seconds')
ctx.time=141000;key('KeyA','a');ctx.fail_write=true;ctx.time=146000;App.tick(ctx);check(A.dirty and A.save_failed,'failure keeps dirty state')
ctx.fail_write=false;ctx.time=147000;App.tick(ctx);check(A.dirty,'failed autosave does not retry by itself')
key('KeyS',nil,{ctrl=true});check(not A.dirty and files['test.md']==A.buffer:text(),'explicit save immediate and exact')
ctx.time=148000;key('KeyA','a');App.pause(ctx);check(private['recovery.txt']:sub(-#A.buffer:text())==A.buffer:text(),'pause keeps newest recovery')
App.resume(ctx);draw()
-- Geometry recovery remains separate from pending edits.
ctx.screen.width=800;ctx.screen.height=480;drawing=true;App.draw(ctx,g);drawing=false
check(A.prepare_timer~=nil and A.touch_geometry==nil,'rotation schedules recovery and blocks stale touch')
advance(ctx.time+1);draw();check(A.prepared.key==A.touch_geometry,'rotation publishes matching geometry')
ctx.fail_timer=true;key('KeyA','a');draw();check(A.prepared.revision==A.buffer.revision,'timer exhaustion prepares synchronously outside draw')
return n





