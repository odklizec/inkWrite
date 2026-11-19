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

local Keyboard=require('keyboard')
check(#Keyboard.ids==24,'24 alphabetically sorted layouts')
for i=2,#Keyboard.names do check(Keyboard.names[i-1]<Keyboard.names[i],'sorted') end
check(A.keyboard.id=='us' and #A.enabled_ids==1,'English default')
-- Open settings with device routes and enter its Keyboard page.
key('Escape');check(A.view=='menu','menu');key('Escape')
A.panel='settings';A.action_focus=8;key('Enter');check(A.view=='layouts','separate page')
local before=A.editor.buffer:text();local caret=A.editor.buffer.pos;A.editor.anchor=0
local function index(id)for i,v in ipairs(Keyboard.ids)do if id==v then return i end end end
A.focus=index('ro')+1;key('Enter');check(ctx.state.keyboard_enabled.ro and A.view=='layouts','checkbox stays in settings')
A.focus=index('ru')+1;key('Enter');check(#A.enabled_ids==3,'multi select')
check(A.editor.buffer:text()==before and A.editor.buffer.pos==caret and A.editor.anchor==0,'selection retained')
A.focus=index('us')+1;key('Enter');check(A.keyboard.id~='us' and #A.enabled_ids==2,'active removed selects enabled')
A.focus=index('ro')+1;key('Enter');A.focus=index('ru')+1;key('Enter');check(#A.enabled_ids==1,'last selected cannot be removed')
check(A.message=='Keep at least one keyboard selected','last language notice')
A.focus=index('us')+1;key('Enter');key('Escape')
local active=A.keyboard.id
key('AltLeft',nil,{alt=true});key('ShiftLeft',nil,{alt=true,shift=true});check(A.keyboard.id~=active,'Alt Shift cycles')
local switched=A.keyboard.id
App.input(ctx,{type='key',source='keyboard',phase='repeat',code='ShiftLeft',mods={alt=true,shift=true}})
check(A.keyboard.id==switched,'held chord no repeat')
App.input(ctx,{type='key',source='keyboard',phase='up',code='ShiftLeft',mods={alt=true}})
App.input(ctx,{type='key',source='keyboard',phase='up',code='AltLeft',mods={}})
key('AltRight',nil,{alt=true});key('ShiftLeft',nil,{alt=true,shift=true});check(A.keyboard.id==switched,'AltGr Shift is not cycling')
-- Popup draws selected languages only, in both orientations.
for _,size in ipairs({{480,800},{800,480}})do
 ctx.screen.width=size[1];ctx.screen.height=size[2];A.languages=true;A.language_focus=1;App.tick(ctx);draw()
 check(not find('Romanian (Standard)'),'unselected absent in popup')
 check(find('English (US)') and find('Russian'),'enabled popup entries')
end
A.languages=nil;A.editor.anchor=nil
local calls=0
ctx.screen.orientation='portrait'
ctx.screen.set_orientation=function(_,target)calls=calls+1;ctx.pending=target;if ctx.rotation_fail then return nil,'busy' end;return true end
key('KeyS',nil,{ctrl=true,shift=true});check(ctx.pending=='landscape' and ctx.state.screen_orientation=='landscape','orientation request saved')
check(ctx.screen.orientation=='portrait','rotation asynchronous')
ctx.screen.orientation='landscape';ctx.screen.width=800;ctx.screen.height=480;App.tick(ctx);draw()
check(A.editor.touch_geometry==A.editor.prepared.key,'rotated snapshot coherent')
local saved=ctx.state.screen_orientation;ctx.rotation_fail=true
key('KeyS',nil,{ctrl=true,shift=true});check(ctx.state.screen_orientation==saved and A.message:find('busy'),'failed rotation retains saved choice')
check(writes==0 and A.editor.buffer:text()==before,'preferences do not write document')
ctx.rotation_fail=nil;A.panel='settings';A.action_focus=6;key('Enter');check(ctx.pending=='portrait','Screen shelf toggles')
-- Physical mappings and six valid layers for every new profile.
for _,id in ipairs({'ro','ru','uk','hu','vi','pl','tr','nl','sv','da','no','fi','el'})do
 local k=Keyboard.new(id);local count=0
 for code,fields in pairs(k.map)do
  count=count+1;check(#fields==6,'six layers '..id..code)
  for _,v in ipairs(fields)do check(utf8.len(v)~=nil and (v:sub(1,1)=='t' or v:sub(1,1)=='d'),'valid mapping')end
 end
 check(count==49,'49 physical positions '..id)
end
local cases={{'ru','KeyQ','й'},{'uk','KeyS','і'},{'hu','Semicolon','é'},{'ro','BracketLeft','ă'},{'vi','Digit1','ă'},{'pl','KeyA','a'},{'el','KeyA','α'}}
for _,v in ipairs(cases)do local text,handled=Keyboard.new(v[1]):feed({code=v[2],phase='down',mods={}},false);check(handled and text==v[3],'national mapping '..v[1]..':'..tostring(text))end
check(Keyboard.accent('ơ','̉')=='ở' and Keyboard.accent('â','̣')=='ậ','Vietnamese tone composition')

-- Missing Alt down must not prevent Shift's modifier snapshot from cycling.
local function release(code,mods)App.input(ctx,{type='key',source='keyboard',phase='up',code=code,mods=mods or {}})end
release('AltRight');release('ShiftLeft');A.languages=nil;A.view='editor'
local previous=A.keyboard.id
key('ShiftLeft',nil,{alt=true,shift=true});check(A.keyboard.id~=previous,'Alt snapshot works without Alt down')
local switched=A.keyboard.id
App.input(ctx,{type='key',source='keyboard',phase='repeat',code='ShiftLeft',mods={alt=true,shift=true}})
check(A.keyboard.id==switched,'missing Alt route never repeats')
release('ShiftLeft',{alt=true});release('AltLeft')
key('ShiftRight',nil,{shift=true});key('AltLeft',nil,{alt=true,shift=true})
check(A.keyboard.id~=switched,'Shift first then Alt works')
release('AltLeft',{shift=true});release('ShiftRight')
previous=A.keyboard.id;key('ShiftLeft',nil,{shift=true});check(A.keyboard.id==previous,'plain Shift never switches');release('ShiftLeft')
key('AltRight',nil,{alt=true});key('ShiftRight',nil,{alt=true,shift=true});check(A.keyboard.id==previous,'AltGr Shift remains protected')
release('ShiftRight',{alt=true});release('AltRight')
local saved_text=A.editor.buffer:text();local saved_pos=A.editor.buffer.pos;A.editor.anchor=0
key('Space',nil,{ctrl=true});check(A.keyboard.id~=previous,'Ctrl Space fallback cycles')
switched=A.keyboard.id
App.input(ctx,{type='key',source='keyboard',phase='repeat',code='Space',mods={ctrl=true}})
check(A.keyboard.id==switched,'Ctrl Space hold never repeats');release('Space',{ctrl=true})
check(A.editor.buffer:text()==saved_text and A.editor.buffer.pos==saved_pos and A.editor.anchor==0,'switching keeps document and selection')
A.close_modal={choice=1,dirty=false};previous=A.keyboard.id;key('Space',nil,{ctrl=true})
check(A.keyboard.id==previous and A.close_modal~=nil,'modal owns shortcut');key('Escape')
-- Add more is reachable using keyboard, device keys and touch on every page.
for _,virtual in ipairs({false,true})do
 for _,size in ipairs({{480,800},{800,480}})do
  ctx.screen.width=size[1];ctx.screen.height=size[2];A.virtual=virtual
  A.view='editor';A.languages=true;A.language_focus=#A.enabled_ids+1;App.tick(ctx);draw()
  check(find('Add more...'),'action rendered above virtual keyboard')
  key('Enter');check(A.view=='layouts' and not A.languages,'keyboard Add more opens settings')
  check(A.editor.buffer:text()==saved_text and A.editor.anchor==0,'settings preserves content and selection')
  A.view='editor';A.languages=true;A.language_focus=#A.enabled_ids+1
  local top=70;local bottom=ctx.screen.height-(A.virtual and 264 or 20)
  local per=math.max(1,(bottom-top-48)//48);local first=((A.language_focus-1)//per)*per+1
  App.input(ctx,{type='pointer',phase='up',gesture='tap',x=100,y=top+(A.language_focus-first)*48+24})
  check(A.view=='layouts' and not A.languages,'touch Add more opens settings')
  A.view='editor';A.languages=true;A.language_focus=1
  for i=1,#A.enabled_ids do App.input(ctx,{type='key',key='down',phase='down'})end
  check(A.language_focus==#A.enabled_ids+1,'device down reaches settings action')
  App.input(ctx,{type='key',key='ok',phase='down'});check(A.view=='layouts','Classic OK opens settings')
 end
end
A.view='editor';A.virtual=nil;A.languages=true;A.language_focus=1
key('Space',nil,{ctrl=true});check(not A.languages and A.view=='editor','fallback closes popup without opening settings')
check(writes==0,'shortcuts and popup never write public document')

local state=ctx.state;App.load(ctx);check(ctx.state==state and ctx.pending==state.screen_orientation,'orientation restore on load')

return n
