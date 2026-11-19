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
local function load(pub,priv,setup)local c=host(pub,priv);if setup then setup(c)end;App.load(c);return c,state()end
local function save(c)App.input(c,{type='key',source='keyboard',phase='down',code='KeyS',mods={ctrl=true}})end
local function type_text(c,s)App.input(c,{type='key',source='keyboard',phase='down',code='KeyA',text=s,mods={}})end
local pub={['2026-11-01-001.md']='keep me',['other.md']='existing writing'}
local c,a=load(pub,{})
check(not a.blocked and a.view=='editor','missing last file opens writable editor')
check(c.state.last==nil and c.state.cursor==nil,'stale preference and cursor cleared')
check(a.editor.doc.name=='2026-11-01-002.md','fresh name avoids collision')
check(c.writes==0 and pub['missing.md']==nil,'load neither writes nor resurrects missing file')
type_text(c,'ž new writing');save(c)
check(pub[a.editor.doc.name]=='ž new writing','new page saves exact text')
check(pub['other.md']=='existing writing' and pub['2026-11-01-001.md']=='keep me','other files unchanged')
check(pub['missing.md']==nil,'save never recreates stale name')
check(c.state.last==a.editor.doc.name and c.state.cursor==#'ž new writing','save adopts new filename and cursor')
-- Existing files still load, cursor validation remains bounded.
c,a=load({['missing.md']='real text'},{})
check(not a.blocked and a.editor.buffer:text()=='real text','existing last file preserved')
check(a.editor.buffer.pos==#'real text','out of range cursor ignored')
-- Only absence is recoverable automatically; actual read failures stay protected.
for _,err in ipairs({'io_error','out_of_memory','invalid_argument'})do
 c,a=load({},{},function(v)v.size_error=err end)
 check(a.blocked and a.view=='files_help','size failure remains protected: '..err)
 check(c.state.last=='missing.md' and c.writes==0,'failure retains original association and performs no writes')
end
c,a=load({['missing.md']='real'},{},function(v)v.read_error='io_error'end)
check(a.blocked and c.writes==0,'failed read protected')
c,a=load({['missing.md']=string.rep('x',32769)},{})
check(a.blocked and c.writes==0,'oversized file protected')
c,a=load({['missing.md']='bad\255'},{})
check(a.blocked and c.writes==0,'invalid UTF8 file protected')
c,a=load({}, {['recovery.txt']='broken'})
check(a.blocked and c.writes==0,'malformed recovery still protected')
c,a=load({}, {},function(v)v.recovery_error='io_error'end)
check(a.blocked and c.writes==0,'unreadable recovery still protected')
local priv={['recovery.txt']='INKWRITE1\nmissing.md\nunsaved ž'}
c,a=load({},priv)
check(not a.blocked and a.editor.buffer:text()=='unsaved ž' and a.editor.doc.name~='missing.md','valid recovery takes priority over missing last')
check(priv['recovery.txt']=='INKWRITE1\nmissing.md\nunsaved ž','recovery unchanged on load')
-- If the SD card cannot allocate/check a fresh name, do not expose an unsafe placeholder.
c,a=load({}, {},function(v)v.size_error='io_error';v.fail_all_sizes=true;local size=v.files.size;v.files.size=function(self,k)if k=='missing.md'then return nil,'not_found'end;return size(self,k)end end)
check(a.blocked and c.writes==0 and c.state.last==nil,'failed fresh-name allocation remains protected')
return n

