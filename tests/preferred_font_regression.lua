local n=0
local function check(x,s)n=n+1;assert(x,s)end
package.loaded['domain.stats']={new=function()return setmetatable({},{__index=function()return function()end end})end}
local function host(public,private)
 local c={state={last='missing.md',cursor=999},time=0,screen={width=480,height=800,occlusion={left=0,right=0,top=0,bottom=0}},clock={},input={listen=function()return true end},budget={extend=function()end},writes=0}
 local f={line_height=24,measure=function(_,s)return (utf8.len(s)or 0)*12 end};c.fonts={medium=f,large=f,small=f}
 c.clock.millis=function()return c.time end;c.clock.now=function()return {valid=true,year=2026,month=11,day=1}end
 c.storage={read=function(_,k)if c.recovery_error then return nil,c.recovery_error end;if private[k]then return private[k]end;return nil,'not_found'end,write=function(_,k,v)private[k]=v;return true end,remove=function(_,k)private[k]=nil;return true end}
 c.files={path='/test',size=function(_,k)if c.size_error and (k=='missing.md' or c.fail_all_sizes)then return nil,c.size_error end;if public[k]then return #public[k]end;return nil,'not_found'end,read=function(_,k,a,z)if c.read_error then return nil,c.read_error end;return public[k]:sub(a+1,a+z)end,write=function(_,k,v)public[k]=v;c.writes=c.writes+1;return true end}
 c.invalidate=function()end;c.set_tick=function()end;c.defer_full_refresh=function()end;c.after=function(_,ms,fn)return {cancel=function()end}end
 return c
end

local App=require('domain.app')
local function state()for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then return v end end end
local c=host({['test.md']='hello ž'},{})
c.state={last='test.md',font_name='retired per-app selection',font_px=32};c.capabilities={ttf=false}
local requested={};local cache={};local chosen='UserSelected.ttf';local drawing=false;local calls=0
c.fonts.size=function(_,px)
 check(not drawing,'font size never opened in draw');calls=calls+1;requested[px]=true
 if not cache[px] then cache[px]={name=chosen,px=px,line_height=px+8,measure=function(_,s)return (utf8.len(s) or 0)*(px//2)end} end
 return cache[px]
end
App.load(c);local a=state()
check(a.font_name==chosen and a.body_font==cache[32],'uses Ink App preference even when ttf capability false')
check(c.state.font_name==nil and c.state.font_px==32,'retires old filename preference, retains size')
check(a.ui_small==cache[20] and a.ui_medium==cache[24],'preferred UI sizes preloaded')
check(requested[20] and requested[24] and requested[30] and requested[32],'body and UI acquired during load')
local drawn={};local used={}
local g=setmetatable({text=function(_,x,y,s,o)drawn[#drawn+1]=s;used[#used+1]=o and o.font end,text_box=function(_,x,y,w,h,s,o)drawn[#drawn+1]=s;used[#used+1]=o and o.font end},{__index=function()return function()end end})
local function draw()drawn={};used={};local before=calls;drawing=true;App.draw(c,g);drawing=false;check(calls==before,'draw reuses font objects')end
local function key(code,mods)App.input(c,{type='key',source='keyboard',phase='down',code=code,mods=mods or {}})end
draw();for _,f in ipairs(used)do if f then check(f.name==chosen,'all editor chrome uses selected TTF')end end
local text=a.buffer:text();local pos=a.buffer.pos;a.anchor=0
a.view='typography';App.tick(c);draw()
check(a.preview_cache.font==cache[32],'preview uses actual selected body font')
for i,px in ipairs({20,24,28,30,32,36})do
 a.type_focus=i+2;key('Enter');check(a.font_px==px and a.body_font==cache[px],'size control uses selected font')
end
local count=0;for _ in pairs(requested)do count=count+1 end;check(count==6,'bounded six unique sizes')
for i=1,40 do a.type_focus=i%6+3;key('Enter')end
local finalcount=0;for _ in pairs(requested)do finalcount=finalcount+1 end;check(finalcount==6,'repeated controls cannot expand font size ladder')
check(a.buffer:text()==text and a.buffer.pos==pos and a.anchor==0 and c.writes==0,'typography keeps document, selection and public files')
a.type_focus=1;key('Enter');check(a.view=='font_help','font button directs to system settings')
a.view='editor';a.virtual=true;App.tick(c);draw()
local dash=false;local dots=false;for _,s in ipairs(drawn)do dash=dash or s=='--';dots=dots or s=='...' end
check(dash and dots,'virtual dash and ellipsis have readable ASCII labels')
a.anchor=nil;a.buffer:seek(a.buffer.size)
App.input(c,{type='pointer',phase='up',gesture='tap',x=150,y=600})
check(a.buffer:text()==text..'—','ASCII dash label still inserts Unicode em dash')
App.input(c,{type='pointer',phase='up',gesture='tap',x=210,y=600})
check(a.buffer:text()==text..'—…','ASCII dots label still inserts Unicode ellipsis')
-- New session follows a changed system selection, retaining size.
local d=host({['test.md']='keep'},{});d.state={last='test.md',font_px=36};d.capabilities={ttf=false}
local other={name='AnotherUserFont',px=36,line_height=44,measure=function(_,s)return (utf8.len(s)or 0)*18 end}
d.fonts.size=function()return other end;App.load(d);a=state()
check(a.font_name=='AnotherUserFont' and a.body_font==other and a.font_px==36,'new session follows updated system preference')
local fallback=d.fonts.medium;d.fonts.size=function()return fallback end;App.load(d);a=state()
check(a.body_font==fallback and a.font_name=='System fallback','explicit fallback shown when host has no usable TTF')
d.fonts.size=nil;App.load(d);a=state();check(a.body_font~=nil,'safe fallback if size API unavailable')
return n
