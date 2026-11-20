local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
package.loaded['domain.stats']={new=function()return setmetatable({},{__index=function()return function()end end})end}
local App=require('domain.app')
local drawing=false
local Layout=require('domain.layout');local layout=Layout.rows
Layout.rows=function(...)assert(not drawing,'touch fix must not wrap during drawing');return layout(...)end
local function setup(w,h,line)
 local text='Alpha caf'..string.char(0xc3,0xa9)..' one. Bravo two.\nSecond line of text.'
 local c={state={last='sample.md',cursor=0},time=0,screen={width=w,height=h,occlusion={left=0,right=0,top=0,bottom=0}},clock={},input={listen=function()return true end},budget={extend=function()end}}
 local f={line_height=line,measure=function(_,t)return (utf8.len(t)or 0)*10 end}
 c.fonts={medium=f,large=f,size=function()return f end}
 c.clock.millis=function()return c.time end;c.clock.now=function()return {valid=false}end
 local files={['sample.md']=text};local private={};local timers={}
 c.storage={read=function(_,k)return private[k],private[k]and nil or 'not_found'end,write=function(_,k,v)private[k]=v;return true end,remove=function(_,k)private[k]=nil;return true end}
 c.files={size=function(_,k)local v=files[k];return v and #v or nil,v and nil or 'not_found'end,read=function(_,k,a,z)local v=files[k];return v and v:sub(a+1,a+z)or nil,v and nil or 'not_found'end,write=function(_,k,v)files[k]=v;return true end}
 c.invalidate=function()c.invalidations=(c.invalidations or 0)+1 end;c.set_tick=function()end;c.defer_full_refresh=function()end
 c.after=function(_,ms,fn)local t={fn=fn,cancel=function(self)self.cancelled=true end};timers[#timers+1]=t;return t end
 App.load(c)
 local a;for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then a=v;break end end
 local fills,lines
 local g=setmetatable({rect=function(_,x,y,w,h,o)if o and o.fill and o.color==15 then fills=fills+1 end end,
  line=function(_,x,y,z,t)lines[#lines+1]={x,y,z,t}end},{__index=function()return function()end end})
 local function draw()fills=0;lines={};drawing=true;App.draw(c,g);drawing=false;return fills,lines end
 local function tap(x,t,gesture)
  c.time=t;local p=a.editor.prepared
  App.input(c,{type='pointer',phase='up',gesture=gesture or 'tap',x=x,y=(c.screen.occlusion.top or 0)+(a.focus_mode and 48 or 88),time_ms=t})
 end
 draw();return a,c,tap,draw,timers
end
for _,d in ipairs({{480,800},{800,480}})do for _,line in ipairs({24,44})do
 local a,c,tap,draw,timers=setup(d[1],d[2],line)
 local first=a.editor.prepared;tap(150,1000)
 check(a.editor.buffer.pos>0,'single touch moves live caret')
 check(a.editor.prepared.pos==a.editor.buffer.pos and a.editor.prepared~=first,'single touch immediately publishes current caret without Settings/keyboard/timer')
 local _,lines=draw();local p=a.editor.prepared;local x=24+p.caret.x;local y=78+(p.caret.row-1)*(line+8);local found=false
 for _,v in ipairs(lines)do if v[1]==x and v[2]==y and v[3]==x and v[4]==y+line then found=true end end
 check(found,'next draw actually paints caret at the touched location')
 tap(48,3000);draw();tap(48,3200,'double_tap')
 check(a.editor.anchor~=nil and a.editor.buffer:slice(a.editor.anchor,a.editor.buffer.pos)=='Alpha','double tap selects the word')
 check(a.editor.prepared.anchor==a.editor.anchor and a.editor.prepared.pos==a.editor.buffer.pos,'double tap immediately publishes selection endpoints')
 local fill=draw();check(fill>0,'next draw paints word-selection highlight')
 tap(48,3400)
 check(a.editor.anchor~=nil and a.editor.buffer.pos>5 and a.editor.prepared.pos==a.editor.buffer.pos,'triple tap immediately publishes full sentence selection')
 fill=draw();check(fill>0,'next draw paints sentence-selection highlight')
 tap(150,6000);fill=draw()
 check(a.editor.anchor==nil and a.editor.prepared.anchor==nil and fill==0,'later single tap immediately clears old highlight')
 -- Cancel a still-live typing coalescer only after the new text was actually drawn.
 App.input(c,{type='key',source='keyboard',phase='down',code='KeyX',text='x',mods={}});draw()
 check(a.editor.redraw_timer~=nil,'typing coalescer active before touch')
 tap(48,8000);local prepared=a.editor.prepared;check(a.editor.redraw_timer==nil and prepared.pos==a.editor.buffer.pos,'touch cancels typing timer and publishes its own visual state')
 for _,t in ipairs(timers)do if not t.cancelled then t.fn(c)end end
 check(a.editor.prepared.pos==a.editor.buffer.pos,'cancelled timer cannot restore a stale caret')
end end
return n
