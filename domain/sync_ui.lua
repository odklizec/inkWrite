local Session=require('domain.sync_session')
local Config=require('domain.sync_config')
local M={}
function M.new(hooks,small,title,dependencies)
  local s=Session.new(hooks,dependencies)
  local u={active=false,page='main',focus=1,session=s}
  local rows,header,geometry,key,status={},{},{},nil,{}
  local function prepare(ctx)
    status=s:status(ctx)
    if s.conflict and u.page~='conflict'then u.page='conflict';u.focus=1 end
    rows={{label='Back',action='back'}}
    if u.page=='main'then
      rows[#rows+1]={label='GitHub sync: '..(ctx.state.github_sync_enabled==true and 'On'or 'Off'),action='toggle'}
      rows[#rows+1]={label=(status.connected or status.busy or status.user_code)and 'Disconnect'or 'Connect',action='connect'}
      rows[#rows+1]={label='Upload current saved document',action='upload'}
      rows[#rows+1]={label='Browse remote documents',action='browse'}
      rows[#rows+1]={label='How to revoke access',action='revoke'}
    elseif u.page=='remote'then
      rows[#rows+1]={label='Refresh remote folder',action='browse'}
      for _,r in ipairs(s.rows)do rows[#rows+1]={label=r.name,action='select',file=r}end
    elseif u.page=='confirm'then
      rows[1].label='Cancel'
      rows[#rows+1]={label='Download as local copy',action='download',file=u.selected}
    elseif u.page=='conflict'then
      rows[1].label='Cancel'
      rows[#rows+1]={label='Upload local as NEW remote file',action='new'}
      if s.conflict and s.conflict.sha then rows[#rows+1]={label='Download remote as local copy',action='download',file=s.conflict}end
    end
    header={Config.scope.repo..' / '..Config.scope.branch,'Status: '..status.state:gsub('_',' '),s.notice}
    if status.user_code then header[3]='github.com/login/device  Code: '..status.user_code end
    if u.page=='confirm'then header[3]='Download: '..u.selected.name end
    if u.page=='revoke'then header[3]='GitHub Settings > Applications > Authorized GitHub Apps. Revoke inkWrite; then disconnect here.'end
    local o=ctx.screen.occlusion or {};local x,y=(o.left or 0)+16,(o.top or 0)+12
    local w=ctx.screen.width-(o.right or 0)-x-16
    local bottom=ctx.screen.height-(o.bottom or 0)-12
    local line=small.line_height+4;local top=y+title.line_height+8+line*4
    local rh=math.max(44,small.line_height+12)
    local per=math.max(1,(bottom-top-50)//rh)
    u.focus=math.max(1,math.min(#rows,u.focus))
    geometry={x=x,y=y,w=w,bottom=bottom,top=top,row=rh,per=per,first=((u.focus-1)//per)*per+1,line=line}
    local next_key=table.concat({u.page,u.focus,status.state,status.user_code or '',tostring(s.busy),s.notice,#rows,w,bottom},'|')
    if key~=next_key then key=next_key;ctx:invalidate()end
  end
  function u:open(ctx)self.active=true;self.page='main';self.focus=1;key=nil;prepare(ctx)end
  local function back(ctx)
    if s.busy then s:disconnect(ctx)end
    if u.page=='main'then s:close(ctx);u.active=false;ctx:invalidate()
    else s.conflict=nil;u.selected=nil;u.page='main';u.focus=1;prepare(ctx)end
  end
  local function activate(ctx,index)
    local r=rows[index];if not r then return end
    if r.action=='back'then back(ctx);return end
    if s.busy then return end
    if r.action=='toggle'then s:toggle(ctx)
    elseif r.action=='connect'then
      if status.connected or status.busy or status.user_code then s:disconnect(ctx)else s:connect(ctx)end
    elseif r.action=='upload'then s:upload(ctx)
    elseif r.action=='new'then s:upload(ctx,true);u.page='main';u.focus=1
    elseif r.action=='browse'then u.page='remote';u.focus=1;s:browse(ctx)
    elseif r.action=='select'then u.selected=r.file;u.page='confirm';u.focus=1
    elseif r.action=='download'then s:download(ctx,r.file);u.page='main';u.focus=1
    elseif r.action=='revoke'then u.page='revoke';u.focus=1 end
    prepare(ctx)
  end
  function u:input(ctx,ev)
    if ev.type=='key'then
      if ev.key=='back'and ev.phase=='up'then back(ctx)
      elseif ev.phase=='down'or ev.phase=='repeat'then
        local code=ev.code or ev.key
        if code=='Escape'then back(ctx)
        elseif code=='ArrowUp'or code=='up'then self.focus=math.max(1,self.focus-1)
        elseif code=='ArrowDown'or code=='down'then self.focus=math.min(#rows,self.focus+1)
        elseif code=='ArrowLeft'or code=='left'then self.focus=math.max(1,self.focus-geometry.per)
        elseif code=='ArrowRight'or code=='right'then self.focus=math.min(#rows,self.focus+geometry.per)
        elseif (code=='Enter'or code=='ok')and ev.phase=='down'then activate(ctx,self.focus)end
      end
    elseif ev.type=='pointer'and ev.phase=='up'and ev.gesture=='tap'then
      local l=geometry
      if ev.x>=l.x and ev.x<l.x+l.w then
        if ev.y>=l.top and ev.y<math.min(l.bottom-50,l.top+l.per*l.row)then
          local i=l.first+(ev.y-l.top)//l.row
          if rows[i]then self.focus=i;activate(ctx,i)end
        elseif ev.y>=l.bottom-48 and ev.y<l.bottom then
          if ev.x<l.x+l.w//3 then back(ctx)
          elseif ev.x<l.x+l.w*2//3 then self.focus=math.max(1,self.focus-l.per)
          else self.focus=math.min(#rows,self.focus+l.per)end
        end
      end
    end
    if self.active then prepare(ctx)end
    return true
  end
  function u:tick(ctx)
    if status.state=='authorizing'then s:poll(ctx)end
    prepare(ctx)
  end
  function u:pause(ctx)s:disconnect(ctx);key=nil;if self.active then prepare(ctx)end end
  function u:resume(ctx)if self.active then key=nil;prepare(ctx)end end
  function u:draw(ctx,g)
    local l=geometry;g:clear(0)
    g:text(l.x,l.y,'GitHub sync',{font=title,color=15})
    local y=l.y+title.line_height+8
    for i,line in ipairs(header)do
      g:text_box(l.x,y,l.w,l.line*(i==3 and 2 or 1),line,{font=small,color=15,wrap='word',overflow='ellipsis'})
      y=y+l.line
    end
    for i=l.first,math.min(#rows,l.first+l.per-1)do
      local ry=l.top+(i-l.first)*l.row
      if i==self.focus then g:rect(l.x,ry,l.w,l.row-2,{color=15})end
      g:text_box(l.x+10,ry+6,l.w-20,l.row-8,rows[i].label,{font=small,color=15,overflow='ellipsis'})
    end
    g:text(l.x,l.bottom-36,'Back',{font=small,color=15})
    g:text(l.x+l.w//3,l.bottom-36,'Prev',{font=small,color=15})
    g:text(l.x+l.w*2//3,l.bottom-36,'Next',{font=small,color=15})
  end
  return u
end
return M
