local Native=require('test_native')
local App=require('domain.app')
local M={}
function M.new(options)
  options=options or {}
  local h={files=options.files or {['alpha.md']='Alpha original.\r\n',['bravo.md']='Bravo original.\r\n'},private=options.private or {},timers={},public_writes=0,private_writes=0,drawing=false}
  local c={state=options.state or {last='alpha.md'},time=0,screen={width=options.width or 480,height=options.height or 800,orientation='portrait',occlusion={left=0,right=0,top=0,bottom=0}},clock={},input={},budget={}}
  h.ctx=c
  local function outside()assert(not h.drawing,'IO or layout preparation during draw')end
  local f={line_height=options.line or 24,measure=function(_,t)return (utf8.len(t)or 0)*10 end};h.font=f
  c.fonts={medium=f,large=f,size=function()outside();return f end}
  c.clock={millis=function()return c.time end,now=function()return {valid=false}end}
  c.budget.extend=outside;c.input.listen=function()return true end
  c.invalidate=function()h.invalidated=true end;c.set_tick=function()end;c.defer_full_refresh=function()end
  c.save_state=function()outside();if h.fail_state then return nil,'io_error'end;h.saved_state=Native.decode(Native.encode(c.state));return true end
  c.json={encode=function(_,v)return Native.encode(v)end,decode=function(_,v)return Native.decode(v)end}
  c.after=function(_,ms,fn)local t={fn=fn,due=c.time+ms,cancel=function(self)self.cancelled=true end};h.timers[#h.timers+1]=t;return t end
  c.storage={
    size=function(_,k)outside();local v=h.private[k];return v and #v or nil,v and nil or 'not_found'end,
    read=function(_,k)outside();if h.fail_read==k then return nil,'io_error'end;local v=h.private[k];return v,v and nil or 'not_found'end,
    write=function(_,k,v)outside();if h.fail_private==k then return nil,'io_error'end;h.private[k]=v;h.private_writes=h.private_writes+1;return true end,
    remove=function(_,k)outside();if h.fail_remove==k then return nil,'io_error'end;h.private[k]=nil;return true end}
  c.files={path='/test',
    size=function(_,k)outside();local v=h.files[k];return v and #v or nil,v and nil or 'not_found'end,
    read=function(_,k,a,z)outside();local v=h.files[k];return v and v:sub(a+1,a+z)or nil,v and nil or 'not_found'end,
    write=function(_,k,v)outside();if h.fail_public==true or h.fail_public==k then return nil,'io_error'end;h.files[k]=v;h.public_writes=h.public_writes+1;return true end,
    list=function()outside();local rows={};for k,v in pairs(h.files)do rows[#rows+1]={name=k,size=#v}end;table.sort(rows,function(a,b)return a.name<b.name end);return rows end}
  c.screen.set_orientation=function(_,direction)outside();c.screen.width,c.screen.height=c.screen.height,c.screen.width;c.screen.orientation=direction;return true end
  c.quit=function()h.quit=true;App.leave(c)end
  function h:state()for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then return v end end end
  function h:key(code,text,mods)App.input(c,{type='key',source='keyboard',phase='down',code=code,text=text,mods=mods or {}})end
  function h:draw()
    self.texts={};self.boxes={};self.lines={}
    local g=setmetatable({
      text=function(_,x,y,t,o)self.texts[#self.texts+1]={x=x,y=y,text=t,opts=o}end,
      text_box=function(_,x,y,w,z,t,o)self.boxes[#self.boxes+1]={x=x,y=y,w=w,h=z,text=t,opts=o}end,
      line=function(_,x,y,z,t,o)self.lines[#self.lines+1]={x=x,y=y,z=z,t=t,opts=o}end}, {__index=function()return function()end end})
    self.drawing=true;App.draw(c,g);self.drawing=false
    return self.texts,self.boxes
  end
  function h:advance(ms)
    c.time=c.time+ms
    local timers=self.timers;self.timers={}
    for _,t in ipairs(timers)do if not t.cancelled then if t.due<=c.time then t.fn(c)else self.timers[#self.timers+1]=t end end end
  end
  function h:split(row)
    self:key('KeyP',nil,{ctrl=true,shift=true});assert(self:state().view=='split','split settings open')
    for i=2,row do self:key('ArrowDown')end
    self:key('Enter');self:draw()
  end
  function h:switch()self:key('Tab',nil,{ctrl=true});self:draw()end
  function h:save()self:key('KeyS',nil,{ctrl=true})end
  function h:edit(t)self:key('KeyQ',t);self:advance(31);self:draw()end
  function h:open(name)
    self:key('KeyO',nil,{ctrl=true});local a=self:state();assert(a.view=='library','file library opens')
    local index;for i,v in ipairs(a.files)do if v.name==name then index=i end end;assert(index,'fixture file exists')
    for i=2,index do self:key('ArrowDown')end
    self:key('Enter');self:draw()
  end
  function h:touch(x,y,gesture,phase,dx,dy)
    App.input(c,{type='pointer',phase=phase or 'up',gesture=gesture or 'tap',x=x,y=y,down_x=dx,down_y=dy,time_ms=c.time})
  end
  function h:pause()App.pause(c)end
  function h:tick()App.tick(c)end
  function h:restart()
    self:pause();App.leave(c);self.timers={};c.time=0;App.load(c);self:draw();return self:state()
  end
  App.load(c);h:draw();return h
end
return M
