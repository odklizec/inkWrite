local Session=require('domain.sync_session')
local Config=require('domain.sync_config')
local Automatic=require('domain.sync_auto')
local ApprovalQR=require('domain.approval_qr')
local M={}
function M.new(hooks,small,title,dependencies)
  local s=Session.new(hooks,dependencies)
  local auto=Automatic.new(s,hooks,dependencies)
  s.on_checkpoint=function(ctx,name,fingerprint)auto:ack(ctx,name,fingerprint)end
  local u={active=false,page='main',focus=1,session=s,auto=auto}
  local rows,header,geometry,key,status={},{},{},nil,{}
  local function prepare(ctx)
    status=s:status(ctx)
    if not u.pending and s.conflict and u.page~='conflict'then u.page='conflict';u.focus=1 end
    if not u.pending and s.pending_update and u.page~='update'then u.page='update';u.focus=1 end
    rows={}
    if u.page=='main'then
      rows={{label='Sync this document',action='sync',primary=true},
        {label='Browse remote documents',action='browse'}}
      rows[#rows+1]={label='GitHub sync: '..(ctx.state.github_sync_enabled==true and 'On'or 'Off'),action='toggle'}
      rows[#rows+1]={label=(status.connected or status.busy or status.user_code)and (ctx.state.github_sync_remember==true and 'Disconnect for now'or 'Disconnect')or 'Connect',action='connect'}
      rows[#rows+1]={label='How to revoke access',action='revoke'}
      rows[#rows+1]={label=ctx.state.github_sync_remember==true and 'Forget saved connection'or 'Remember connection on this device',action='remember'}
      if ctx.state.github_sync_remember==true and status.connected and status.remember_error=='connection_write_failed'then
        rows[#rows+1]={label='Retry saving connection',action='retry_remember'}
      end
      rows[#rows+1]={label='Version history: current document',action='current_history'}
      rows[#rows+1]={label='Automatic uploads: '..(ctx.state.github_sync_auto==true and 'On'or 'Off'),action='auto_settings'}
    elseif u.page=='auto'then
      rows={{label=ctx.state.github_sync_auto==true and 'Turn automatic uploads Off'or 'Enable automatic uploads',action='auto_toggle'},
        {label='Upload delay: '..((ctx.state.github_sync_delay==15 or ctx.state.github_sync_delay==60)and ctx.state.github_sync_delay or 30)..' seconds',action='auto_delay'},
        {label='Retry pending uploads',action='auto_retry'},
        {label='Clear upload queue',action='auto_clear'}}
      for _,v in ipairs(auto.items)do rows[#rows+1]={label=(v.held and 'Review: 'or 'Pending: ')..v.name,action='auto_info',file=v}end
    elseif u.page=='remote'then
      rows[#rows+1]={label='Refresh remote folder',action='browse'}
      for _,r in ipairs(s.rows)do rows[#rows+1]={label=r.name,action='select',file=r}end
    elseif u.page=='confirm'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Download as local copy',action='download',file=u.selected}
      rows[#rows+1]={label='Version history',action='file_history',file=u.selected}
    elseif u.page=='history'then
      rows[#rows+1]={label='Refresh latest history',action='history_refresh'}
      local h=s.history
      if h then
        if h.page>1 then rows[#rows+1]={label='Newer versions',action='history_prev'}end
        if h.more then rows[#rows+1]={label='Older versions',action='history_next'}end
        for _,r in ipairs(h.rows)do
          rows[#rows+1]={label=r.date..' '..r.sha:sub(1,7)..' '..r.summary,action='version',file=r}
        end
      end
    elseif u.page=='version'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Restore as new local copy',action='restore_version',file=u.version}
    elseif u.page=='conflict'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Upload local as NEW remote file',action='new'}
      if s.conflict and s.conflict.sha then rows[#rows+1]={label='Download remote as local copy',action='download',file=s.conflict}end
    elseif u.page=='update'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Update local document',action='update_local'}
      rows[#rows+1]={label='Download as local copy',action='update_copy'}
    elseif u.page=='connect'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Remember and connect',action='connect_remember'}
      rows[#rows+1]={label='Connect for this session only',action='connect_once'}
    elseif u.page=='remember'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Remember on this device',action='consent'}
    end
    local approving=status.user_code~=nil and u.page=='main'
    if approving then rows={{label='Cancel sign-in',action='cancel_auth'}}end
    header={Config.scope.repo..' / '..Config.scope.branch,'Status: '..status.state:gsub('_',' '),s.notice}
    local status_lines=1
    if u.page=='main'and not status.user_code then
      header[2]=header[2]..'\n'..s.file_status;status_lines=2
    end
    if status.user_code then
      header[2]='github.com/login/device'
      header[3]='Sign-in code: '..status.user_code..'\nApprove the App in your browser.'
    elseif status.state=='requesting_code'then header[3]='Requesting a new sign-in code...'
    elseif status.state=='refreshing'then header[3]='Renewing saved connection...'
    elseif status.remember_error then
      local errors={clock_unavailable='Set device time; connection was not saved.',connection_write_failed='Could not save connection. Retry Remember.',remember_requires_signin='Connect once again to save the connection.'}
      header[3]=errors[status.remember_error]or 'Saved connection unavailable. Retry or Forget.'
    elseif status.reason then
      local errors={code_expired='Code expired. Select Connect for a new code.',no_network='No network. Retry Connect.',server_error='GitHub request failed. Retry Connect.',expired_token='Saved authorization expired. Connect again.',
        bad_refresh_token='Saved authorization expired or revoked. Connect again.',authorization_required='Saved access rejected. Connect to renew it.',access_forbidden='GitHub refused access. Retry; saved login kept.',refresh_failed='Renewal failed. Retry Connect; saved login kept.',clock_unavailable='Set device time, then retry Connect.'}
      header[3]=errors[status.reason]or 'Connection failed. Retry Connect; check App setup.'
    end
    if u.page=='auto'then
      header[1]='Automatic uploads: '..#auto.items..' pending'
      header[2]=auto.notice
      header[3]='Uploads documents you save after enabling. Remote changes require review. No automatic downloads.'
    end
    if u.page=='confirm'then header[3]='Download: '..u.selected.name end
    if u.page=='history'then
      header[1]='History: '..(u.history_name or '')
      header[2]='Page '..(s.history and s.history.page or 1)..' / '..status.state:gsub('_',' ')
    end
    if u.page=='version'then header[3]=u.version.date..' '..u.version.sha:sub(1,7)..'\nOriginals kept; restore creates a copy.'end
    if u.page=='revoke'then header[3]='GitHub Settings > Applications > Authorized GitHub Apps. Revoke inkWrite; then disconnect here.'end
    if u.page=='update'then header[3]='Only GitHub changed. A local backup is kept before updating.'end
    if u.page=='connect'then header[3]='Save GitHub login unencrypted on SD.\nAnyone with the card can recover it.'end
    if u.page=='remember'then header[3]='Save GitHub login unencrypted on SD.\nAnyone with the card can recover it.'end
    local o=ctx.screen.occlusion or {};local x,y=(o.left or 0)+16,(o.top or 0)+12
    local w=ctx.screen.width-(o.right or 0)-x-16
    local bottom=ctx.screen.height-(o.bottom or 0)-18
    local notice_lines=(u.page=='remember'or u.page=='connect'or u.page=='auto')and (w>=640 and 3 or 4)or 2
    local line=small.line_height+4;local top=y+title.line_height+8+line*(1+status_lines+notice_lines)
    local rh=math.max(44,small.line_height+12)
    local qr
    if approving then
      local available=math.min(w,bottom-top-48-rh-10,222)
      local scale=math.floor(available/ApprovalQR.size)
      if scale>=2 then
        local size=ApprovalQR.size*scale
        qr={x=x+(w-size)//2,y=top+2,size=size,scale=scale}
        top=qr.y+size+8
      end
    end
    local footer_y=bottom-48
    local per=math.max(1,(footer_y-top)//rh)
    u.focus=math.max(1,math.min(#rows,u.focus))
    local page=((u.focus-1)//per)+1;local pages=math.max(1,(#rows+per-1)//per)
    geometry={x=x,y=y,w=w,bottom=bottom,page=page,pages=pages,touch_left=o.left or 0,touch_right=ctx.screen.width-(o.right or 0),touch_bottom=ctx.screen.height-(o.bottom or 0),footer_y=footer_y,footer_left=(o.left or 0)+20,footer_right=ctx.screen.width-(o.right or 0)-20,top=top,row=rh,per=per,first=((u.focus-1)//per)*per+1,line=line,notice_lines=notice_lines,status_lines=status_lines,qr=qr}
    local next_key=table.concat({u.page,u.focus,status.state,status.user_code or '',tostring(status.busy),status.reason or '',status.remember_error or '',tostring(s.busy),s.file_status,tostring(ctx.state.github_sync_enabled),tostring(ctx.state.github_sync_remember),s.notice,auto.notice,tostring(ctx.state.github_sync_auto),tostring(ctx.state.github_sync_delay),#auto.items,#rows,s.history and s.history.page or 0,s.history and s.history.anchor or '',w,bottom},'|')
    if key~=next_key then key=next_key;ctx:invalidate()end
  end
  function u:open(ctx)auto:interrupt(ctx);auto:load(ctx);self.active=true;self.page='main';self.focus=1;key=nil;s:open(ctx);prepare(ctx)end
  local function back(ctx)
    if u.pending then u.pending=nil;s:disconnect(ctx)end
    if s.busy then s:disconnect(ctx)end
    if u.page=='main'then s:close(ctx);u.active=false;ctx:invalidate()
    else
      local page=u.page
      s.conflict=nil;s.pending_update=nil;u.version=nil;u.selected=nil
      u.page=page=='version'and 'history'or (page=='history'and u.history_origin or 'main');u.focus=1;prepare(ctx)
    end
  end
  local function connect(ctx)
    local current=s:status(ctx)
    if current.busy or current.user_code then u.page='main';u.focus=1;return end
    if ctx.state.github_sync_remember==true or ctx.state.github_sync_connection_choice==true then
      ctx.state.github_sync_enabled=true;u.page='main';u.focus=1;s:connect(ctx)
    else u.page='connect';u.focus=1 end
  end
  local function perform(ctx,r)
    if r.action=='cancel_auth'then u.pending=nil;s:disconnect(ctx);u.focus=1
    elseif r.action=='sync'then
      s:sync(ctx)
    elseif r.action=='auto_settings'then auto:load(ctx);u.page='auto';u.focus=1
    elseif r.action=='auto_toggle'then
      auto:interrupt(ctx);ctx.state.github_sync_auto=ctx.state.github_sync_auto~=true
      if ctx.state.github_sync_auto then ctx.state.github_sync_enabled=true;auto:load(ctx);auto:resume(ctx)else auto.notice='Off; pending queue kept'end
    elseif r.action=='auto_delay'then
      local value=ctx.state.github_sync_delay or 30;ctx.state.github_sync_delay=value==15 and 30 or (value==30 and 60 or 15)
    elseif r.action=='auto_retry'then auto:retry(ctx)
    elseif r.action=='auto_clear'then auto:clear(ctx)
    elseif r.action=='auto_info'then
      local messages={conflict='GitHub differs. Use manual Sync.',saved_file_changed='File changed. Save it again.',
        connection_required='Connect, then retry pending uploads.',authorization_required='Reconnect, then retry pending uploads.',
        rate_limited='GitHub rate limit. Waiting one hour.',metadata_invalid='Sync record needs attention. Use manual Sync.'}
      auto.notice=r.file.name..': '..(messages[r.file.reason]or (r.file.held and 'Use manual Sync or retry.'or 'Waiting for idle or retry delay.'))
    elseif r.action=='toggle'then s:toggle(ctx)
    elseif r.action=='connect'then
      if status.connected or status.busy or status.user_code then u.pending=nil;s:disconnect(ctx)else connect(ctx)end
    elseif r.action=='update_local'then s:update_local(ctx);u.page='main';u.focus=1
    elseif r.action=='update_copy'then s:download(ctx,s.pending_update);u.page='main';u.focus=1
    elseif r.action=='connect_remember'or r.action=='connect_once'then
      ctx.state.github_sync_enabled=true;ctx.state.github_sync_connection_choice=true
      if r.action=='connect_remember'then s:remember(ctx)end
      s:connect(ctx);u.page='main';u.focus=1
    elseif r.action=='current_history'then
      do
        local info=hooks.describe and hooks.describe()
        if info and info.name then u.history_name=info.name;u.history_origin='main';u.page='history';u.focus=1;s.history=nil;s:current_history(ctx)
        else s.notice='Open a document to view its history.'end
      end
    elseif r.action=='file_history'then
      u.history_origin='remote';u.history_name=r.file.name;u.page='history';u.focus=1;s.history=nil;s:history_page(ctx,r.file.name,1)
    elseif r.action=='history_refresh'then s:history_page(ctx,u.history_name,1);u.focus=1
    elseif r.action=='history_prev'or r.action=='history_next'then
      local h=s.history;if h then s:history_page(ctx,h.name,h.page+(r.action=='history_next'and 1 or -1),h.anchor);u.focus=1 end
    elseif r.action=='version'then u.version=r.file;u.page='version';u.focus=1
    elseif r.action=='restore_version'then s:restore_revision(ctx,r.file);u.version=nil;u.page='history';u.focus=1
    elseif r.action=='new'then s:upload(ctx,true);u.page='main';u.focus=1
    elseif r.action=='browse'then u.page='remote';u.focus=1;s:browse(ctx)
    elseif r.action=='select'then u.selected=r.file;u.page='confirm';u.focus=1
    elseif r.action=='download'then s:download(ctx,r.file);u.page='main';u.focus=1
    elseif r.action=='revoke'then u.page='revoke';u.focus=1 end
    if r.action=='remember'then
      if ctx.state.github_sync_remember==true then s:forget(ctx)
      else u.page='remember';u.focus=1 end
    elseif r.action=='consent'then s:remember(ctx);u.page='main';u.focus=1
    elseif r.action=='retry_remember'then s:remember(ctx)end
    prepare(ctx)
  end
  local network_actions={sync=true,browse=true,current_history=true,file_history=true,
    history_refresh=true,history_prev=true,history_next=true,download=true,new=true,
    update_local=true,update_copy=true,restore_version=true}
  local function continue_pending(ctx)
    local pending=u.pending;if not pending then return end
    status=s:status(ctx)
    if status.connected and not status.busy then
      u.pending=nil;perform(ctx,pending)
    elseif not status.busy and not status.user_code and u.page~='connect'then
      u.pending=nil -- One attempt only. Another deliberate action may try again.
    end
  end
  local function activate(ctx,index)
    local r=rows[index];if not r then return end
    if r.action=='back'then back(ctx);return end
    if s.busy then return end
    status=s:status(ctx)
    if network_actions[r.action]and (not status.connected or status.busy)then
      if not u.pending then u.pending=r end
      connect(ctx);prepare(ctx);continue_pending(ctx);return
    end
    if not network_actions[r.action]and r.action~='connect_remember'and r.action~='connect_once'then u.pending=nil end
    perform(ctx,r);continue_pending(ctx)
  end
  local function turn_page(delta)
    local target=geometry.page+delta
    if target>=1 and target<=geometry.pages then u.focus=(target-1)*geometry.per+1 end
  end
  function u:sync_document(ctx)self:open(ctx);activate(ctx,1);prepare(ctx)end
  function u:input(ctx,ev)
    if ev.type=='key'then
      if ev.key=='back'and ev.phase=='up'then back(ctx)
      elseif ev.phase=='down'or ev.phase=='repeat'then
        local code=ev.code or ev.key
        if code=='Escape'then back(ctx)
        elseif code=='ArrowUp'or code=='up'then self.focus=math.max(1,self.focus-1)
        elseif code=='ArrowDown'or code=='down'then self.focus=math.min(#rows,self.focus+1)
        elseif code=='ArrowLeft'or code=='left'then turn_page(-1)
        elseif code=='ArrowRight'or code=='right'then turn_page(1)
        elseif (code=='Enter'or code=='ok')and ev.phase=='down'then activate(ctx,self.focus)end
      end
    elseif ev.type=='pointer'and ev.phase=='up'then
      local l=geometry
      local tap=ev.gesture=='tap'or ev.gesture=='double_tap'
      if tap and ev.x>=l.touch_left and ev.x<l.touch_right and ev.y>=l.footer_y and ev.y<l.touch_bottom then
        local third=(l.touch_right-l.touch_left)/3
        if ev.x<l.touch_left+third then back(ctx)
        elseif ev.x<l.touch_left+2*third then turn_page(-1)
        else turn_page(1)end
      elseif ev.gesture=='tap'and ev.x>=l.x and ev.x<l.x+l.w
        and ev.y>=l.top and ev.y<math.min(l.footer_y,l.top+l.per*l.row)then
        local i=l.first+(ev.y-l.top)//l.row
        if rows[i]then self.focus=i;activate(ctx,i)end
      end
    end
    if self.active then prepare(ctx)end
    return true
  end
  function u:tick(ctx)
    auto:flush(ctx)
    if status.state=='authorizing'then s:poll(ctx)end
    continue_pending(ctx);prepare(ctx)
  end
  function u:pause(ctx)auto:pause(ctx);s:pause(ctx);key=nil;if self.active then prepare(ctx)end end
  function u:resume(ctx)auto:resume(ctx);if self.active then key=nil;s:open(ctx);prepare(ctx)end end
  function u:leave(ctx)auto:pause(ctx,true);self.pending=nil;s:leave(ctx)end
  function u:draw(ctx,g)
    local l=geometry;g:clear(0)
    g:text(l.x,l.y,'GitHub sync',{font=title,color=15})
    if l.pages>1 then g:text(l.x+l.w,l.y,l.page..' / '..l.pages,{font=small,color=15,align='right'})end
    local y=l.y+title.line_height+8
    for i,line in ipairs(header)do
      g:text_box(l.x,y,l.w,l.line*(i==3 and l.notice_lines or i==2 and l.status_lines or 1),line,{font=small,color=15,wrap='word',overflow='ellipsis'})
      y=y+l.line*(i==2 and l.status_lines or 1)
    end
    if l.qr then
      local q=l.qr
      g:rect(q.x,q.y,q.size,q.size,{color=0,fill=true})
      for _,r in ipairs(ApprovalQR.rects)do
        g:rect(q.x+r[1]*q.scale,q.y+r[2]*q.scale,r[3]*q.scale,q.scale,{color=15,fill=true})
      end
    end
    for i=l.first,math.min(#rows,l.first+l.per-1)do
      local ry=l.top+(i-l.first)*l.row
      if i==self.focus or rows[i].primary then g:rect(l.x,ry,l.w,l.row-2,{color=15,line_width=rows[i].primary and 2 or 1})end
      g:text_box(l.x+10,ry+6,l.w-20,l.row-8,rows[i].label,{font=small,color=15,overflow='ellipsis'})
    end
    g:line(l.footer_left,l.footer_y,l.footer_right,l.footer_y,{color=15})
    local fy=l.footer_y+33
    g:text(l.footer_left+45,fy,'Back',{font=title,color=15,align='center',valign='middle'})
    if l.page>1 then g:text((l.footer_left+l.footer_right)//2,fy,'Prev',{font=title,color=15,align='center',valign='middle'})end
    if l.page<l.pages then g:text(l.footer_right,fy,'Next',{font=title,color=15,align='right',valign='middle'})end
  end
  return u
end
return M
