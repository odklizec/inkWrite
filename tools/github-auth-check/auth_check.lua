local Auth=require('domain.sync_auth')
local Primitives=require('domain.sync_primitives')
local Config=require('domain.sync_config')
local M={}
local session,font,title,lines,button,label,key,first,exit
local statuses={disconnected='Ready to connect',requesting_code='Requesting sign-in code...',
  authorizing='Waiting for your authorization',verifying='Checking account and repository...',
  connected='Connected: '..Config.login,offline='Connection unavailable',
  auth_required='Please connect again',error='Connection check failed'}
local function geometry(ctx)
  local w,h=ctx.screen.width,ctx.screen.height
  return {x=16,y=h-68,w=(w-40)//2,h=50},{x=24+(w-40)//2,y=h-68,w=(w-40)//2,h=50}
end
local function prepare(ctx)
  local status=session and session:status(ctx)or {state='error',reason='setup_required'}
  local next_key=table.concat({status.state,status.reason or '',status.user_code or '',tostring(status.busy),tostring(status.http_status)},'|')
  first,exit=geometry(ctx)
  if next_key==key then return end
  key=next_key
  lines={Config.scope.repo..' / '..Config.scope.branch,statuses[status.state]or 'Connection check',
    'Token stays in memory only.'}
  if status.user_code then
    lines[#lines+1]='Open github.com/login/device'
    lines[#lines+1]='Code: '..status.user_code
    lines[#lines+1]='Approve the App in your browser.'
  elseif status.reason then
    lines[#lines+1]=(status.http_status and 'HTTP '..status.http_status..': 'or 'Reason: ')..status.reason:gsub('_',' ')
    lines[#lines+1]='Check setup and connect again.'
  elseif status.connected then
    lines[#lines+1]='Selected private repository verified.'
    lines[#lines+1]='No document uploads performed.'
  else
    lines[#lines+1]='OK / Connect starts sign-in.'
    lines[#lines+1]='No document uploads performed.'
  end
  button=status.busy or status.user_code~=nil or status.connected
  label=button and 'Disconnect'or 'Connect'
  ctx:invalidate()
end
local function action(ctx)
  if not session then return end
  if button then session:disconnect()else session:start(ctx)end
  key=nil;prepare(ctx)
end
local function quit(ctx)if session then session:disconnect()end;ctx:quit()end
function M.load(ctx)
  ctx.budget:extend()
  font=ctx.fonts:size(20)or ctx.fonts.medium
  title=ctx.fonts:size(24)or ctx.fonts.medium
  local primitives=Primitives.new(ctx)
  session=primitives and Auth.new(Config,primitives)or nil
  key=nil;ctx:set_tick(1000);prepare(ctx)
end
function M.tick(ctx)
  if session and session:status(ctx).state=='authorizing'then session:poll(ctx)end
  prepare(ctx)
end
function M.draw(ctx,g)
  g:clear(0)
  g:text(16,16,'GitHub sign-in check',{font=title,color=15})
  local y=20+title.line_height+12
  for _,line in ipairs(lines)do
    g:text_box(16,y,ctx.screen.width-32,font.line_height+2,line,{font=font,color=15})
    y=y+font.line_height+8
  end
  for _,r in ipairs({first,exit})do g:rect(r.x,r.y,r.w,r.h,{color=15})end
  g:text(first.x+12,first.y+10,label,{font=font,color=15})
  g:text(exit.x+12,exit.y+10,'Exit',{font=font,color=15})
end
local function inside(r,x,y)return x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h end
function M.input(ctx,ev)
  if ev.type=='key'and ev.phase=='up'and ev.key=='back'then quit(ctx);return true end
  if ev.type=='key'and ev.phase=='up'and ev.key=='ok'then action(ctx);return true end
  if ev.type=='pointer'and ev.phase=='up'and ev.gesture=='tap'then
    if inside(exit,ev.x,ev.y)then quit(ctx);return true end
    if inside(first,ev.x,ev.y)then action(ctx);return true end
  end
  return false
end
function M.pause(ctx)if session then session:pause()end;key=nil;prepare(ctx)end
function M.resume(ctx)key=nil;prepare(ctx)end
function M.leave()if session then session:disconnect()end end
return M
