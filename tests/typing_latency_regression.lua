local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local drawing=false
local Layout=require('domain.layout');local rows=Layout.rows
Layout.rows=function(...)assert(not drawing,'layout during draw');return rows(...)end
package.loaded['domain.stats']={new=function()return setmetatable({},{__index=function()return function()end end})end}
local ctx={state={last='test.md'},time=0,screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}},fonts={},input={listen=function()return true end},clock={},budget={extend=function()assert(not drawing)end}}
local files={['test.md']='hello ž world\nsecond line'};local private={};local writes=0;local timers={}
ctx.clock.millis=function()return ctx.time end;ctx.clock.now=function()return {valid=false}end
local font={line_height=24,measure=function(_,s)check(utf8.len(s)~=nil,'valid UTF8 measurement');return utf8.len(s)*12 end}
ctx.fonts={medium=font,large=font,small=font}
ctx.storage={read=function(_,k)if private[k]then return private[k]end;return nil,'not_found'end,write=function(_,k,v)private[k]=v;return true end,remove=function(_,k)private[k]=nil;return true end}
ctx.files={path='/test',size=function(_,k)if files[k]then return #files[k]end;return nil,'not_found'end,read=function(_,k,a,z)if files[k]then return files[k]:sub(a+1,a+z)end;return nil,'not_found'end,write=function(_,k,v)if ctx.fail_write then return nil,'io_error'end;files[k]=v;writes=writes+1;return true end}
ctx.frames=0;ctx.invalidate=function()ctx.frames=ctx.frames+1 end;ctx.set_tick=function()end;ctx.defer_full_refresh=function()end
ctx.after=function(_,ms,fn)if ctx.fail_timer then return nil,'limit_exceeded'end;local t={due=ctx.time+ms,fn=fn,cancel=function(self)self.cancelled=true end};timers[#timers+1]=t;return t end
local function advance(t)ctx.time=t;local todo=timers;timers={};for _,v in ipairs(todo)do if not v.cancelled then if v.due<=t then v.fn(ctx)else timers[#timers+1]=v end end end end
local App=require('domain.app');App.load(ctx)
local A;for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then A=v;break end end
local drawn={};local g=setmetatable({text=function(_,x,y,s)drawn[#drawn+1]=s end,text_box=function(_,x,y,w,h,s)drawn[#drawn+1]=s end},{__index=function()return function()end end})
local function draw()drawn={};drawing=true;App.draw(ctx,g);drawing=false;for _,s in ipairs(drawn)do check(not s:find('Preparing text',1,true),'typing must retain editor')end end
local function key(code,text,mods)App.input(ctx,{type='key',source='keyboard',phase='down',code=code,text=text,mods=mods or {}})end
local function find(s)for _,v in ipairs(drawn)do if v==s then return true end end end
-- Controlled times verify the requested deadline, not physical-device speed.
ctx.time=100;local old=A.prepared;key('KeyX','x');local timer=A.redraw_timer
check(timer.due==130,'first key starts a 30 ms cooldown')
check(A.prepared~=old and A.prepared.revision==A.buffer.revision,'first key prepares immediately without waiting for timer')
local first=A.prepared
ctx.time=120;key('KeyY','y');check(A.redraw_timer==timer and timer.due==130,'later key cannot postpone deadline')
advance(129);check(A.prepared==first,'later key stays batched before deadline')
advance(130);check(A.prepared.revision==A.buffer.revision,'latest revision prepared at first deadline')
check(A.timing.queue.last==10,'queue records actual batched-input wait')
local text=g.text;g.text=function(...)ctx.time=ctx.time+3;return text(...)end
local at=ctx.time;draw();local elapsed=ctx.time-at
check(elapsed>0 and A.timing.draw.last==elapsed,'draw duration measured')
check(A.timing.compose.last==10+elapsed,'input-to-composed-frame includes queue and drawing')
local composed=A.timing.compose.last;ctx.time=ctx.time+1000;draw()
check(A.timing.compose.last==composed,'redrawing same snapshot does not inflate input latency')
local measure=font.measure;font.measure=function(...)ctx.time=ctx.time+2;return measure(...)end
key('KeyZ','z');local due=A.redraw_timer.due;advance(due)
check(A.timing.layout.last>0,'layout cost measured using active clock')
local write=ctx.files.write;ctx.files.write=function(...)ctx.time=ctx.time+120;return write(...)end
key('KeyS',nil,{ctrl=true})
check(A.timing.save.last==120 and A.timing.input.last>=120,'save pause separated from input work')
check(writes==1,'timing instrumentation adds no disk writes')
check(ctx.state.timing==nil and ctx.state.pending_frame_since==nil,'timing stays transient')
font.measure=measure;g.text=text;advance(ctx.time+1000);advance(ctx.time+1000)
local frames=ctx.frames;key('KeyA','a');check(ctx.frames==frames+1,'idle key requests exactly one immediate frame')
advance(ctx.time+30);check(ctx.frames==frames+1 and A.redraw_timer==nil,'unchanged cooldown adds no frame')
key('KeyA','a');local pos=A.buffer.pos;key('KeyA',nil,{ctrl=true});check(A.buffer.pos==pos,'select all can change anchor without moving caret')
advance(ctx.time+30);check(A.prepared.anchor==0,'batched selection-only change publishes')
advance(ctx.time+30)
ctx.time=0x7ffffffe;key('KeyA','a');check(A.timing.queue.last==0,'idle key has no timer wait')
ctx.time=0x7fffffff;key('KeyB','b')
local wrapped=A.redraw_timer;ctx.time=28;wrapped.fn(ctx)
check(A.timing.queue.last==29,'batched queue timing handles clock wrap')
App.pause(ctx);check(A.pending_frame_since==nil and A.redraw_timer==nil,'pause cancels pending measurement')
App.resume(ctx);draw();App.load(ctx)
check(A.timing~=nil,'old controller reference remains valid')
local fresh;for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then fresh=v;break end end
check(fresh.timing.save.max==0 and fresh.timing.queue.max==0,'new session resets old timing')
return n


