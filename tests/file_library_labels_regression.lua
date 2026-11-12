-- Filename visibility depends on the returned line height, not requested px.
local App=require('domain.app')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function app_state()
  for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then return v end end
end
local names={'ideas.md','české poznámky.txt',string.rep('long-',20)..'.md'}
local function exercise(width,height,line_height,touch)
  local files={};for i,name in ipairs(names)do files[name]='Document '..i..' ž\r\n'end
  local private={};local writes=0;local drawing=false
  local font={name='TallPreferred.ttf',px=20,line_height=line_height,
    measure=function(_,s)return (utf8.len(s)or 0)*10 end}
  local c={state={last=names[1]},screen={width=width,height=height,occlusion={left=0,right=0,top=0,bottom=0}},clock={},input={},budget={},fonts={small=font,medium=font,large=font}}
  c.clock.millis=function()return 0 end;c.clock.now=function()return {valid=false}end
  c.fonts.size=function()check(not drawing,'no font acquisition in draw');return font end
  c.budget.extend=function()check(not drawing,'no extended work in draw')end
  c.input.listen=function()return true end
  c.storage={read=function(_,k)return private[k],private[k]and nil or 'not_found'end,
    write=function(_,k,v)private[k]=v;return true end,remove=function(_,k)private[k]=nil;return true end}
  c.files={path='/AppFiles/inkwrite',size=function(_,k)return files[k]and #files[k]or nil,files[k]and nil or 'not_found'end,
    read=function(_,k,a,z)return files[k]and files[k]:sub(a+1,a+z)or nil,'not_found'end,
    write=function(_,k,v)writes=writes+1;files[k]=v;return true end,
    list=function()local rows={};for _,name in ipairs(names)do rows[#rows+1]={name=name,size=#files[name]}end;return rows end}
  c.invalidate=function()end;c.set_tick=function()end;c.defer_full_refresh=function()end
  c.after=function()return {cancel=function()end}end
  App.load(c);local a=app_state()
  local function key(code,mods)App.input(c,{type='key',source='keyboard',phase='down',code=code,mods=mods or {}})end
  key('KeyO',{ctrl=true});check(a.view=='library','Ctrl+O opens actual file list')
  local labels={}
  local g=setmetatable({text_box=function(_,x,y,w,h,text,opts)
    if files[text]then
      check(h>=opts.font.line_height,'filename box fits a full preferred-font line')
      check(w>0 and x+w<=width-120,'filename stays before size and management controls')
      check(y>=0 and y+h<height,'filename remains within screen')
      check(opts.overflow=='ellipsis','long filenames remain bounded')
      labels[text]={x=x,y=y,w=w,h=h}
    end
  end},{__index=function()return function()end end})
  drawing=true;App.draw(c,g);drawing=false
  for _,name in ipairs(names)do check(labels[name]~=nil,'draw receives UTF8 filename '..name)end
  if touch then
    local r=labels[names[2]]
    App.input(c,{type='pointer',phase='up',gesture='tap',x=r.x+4,y=r.y+r.h//2})
  else key('ArrowDown');key('Enter')end
  check(a.view=='editor' and a.doc.name==names[2],'touch/button row opens the intended file')
  check(a.buffer:text()==files[names[2]],'opening preserves exact UTF8 and CRLF bytes')
  check(writes==0,'listing/opening does not write public documents')
end
for _,dims in ipairs({{480,800},{800,480}})do
  for _,height in ipairs({24,28,36,44})do
    exercise(dims[1],dims[2],height,true)
    exercise(dims[1],dims[2],height,false)
  end
end
return n
