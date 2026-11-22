local Session=require('domain.sync_session')
local Config=require('domain.sync_config')
local Automatic=require('domain.sync_auto')
local ApprovalQR=require('domain.approval_qr')
local GuideQR=require('domain.github_guide_qr')
local ReviewText=require('domain.sync_review')
local Panes=require('domain.pane_geometry')
local SetupUI=require('domain.sync_setup_ui')
local Primitives=require('domain.sync_primitives')
local M={}
function M.new(hooks,small,title,dependencies)
  local d=dependencies or {};local config=d.config or Config;local manager=d.setup
  local wizard
  local s=Session.new(hooks,dependencies)
  local auto=Automatic.new(s,hooks,dependencies)
  s.on_checkpoint=function(ctx,name,fingerprint)auto:ack(ctx,name,fingerprint)end
  s.on_connected=function(ctx)auto:connection_verified(ctx)end
  local u={active=false,page='main',focus=1,parents={},session=s,auto=auto}
  local rows,header,geometry,key,status={},{},{},nil,{}
  local function enter(page)
    u.parents[#u.parents+1]={page=u.page,focus=u.focus}
    u.page=page;u.focus=1
  end
  local function up()
    local parent=table.remove(u.parents)
    u.page=parent and parent.page or 'main'
    u.focus=parent and parent.focus or 1
  end
  local function reviewing()
    return u.page=='compare'or u.page=='review'or u.page=='resolve_local'or u.page=='resolve_github'
  end
  local function leave_review()
    u.comparison=nil;s.review=nil
    while reviewing() do up() end
  end
  local function prepare(ctx)
    status=s:status(ctx)
    if not u.pending and s.conflict and u.page~='conflict'then enter('conflict') end
    if not u.pending and s.pending_update and u.page~='update'then enter('update') end
    if s.review and not u.pending and not reviewing() then
      enter('compare')
      u.comparison={active=1,readers={ReviewText.new(s.review,'local'),ReviewText.new(s.review,'github')}}
    end
    if reviewing() and not s.review then leave_review() end
    rows={}
    if u.page=='main'then
      rows={{label='Sync this document',action='sync',primary=true},
        {label='Browse remote documents...',action='browse'},
        {label='Version history: current document...',action='current_history'},
        {label='Review current document versions',action='review'},
        {label=(status.connected or status.busy or status.user_code)and (ctx.state.github_sync_remember==true and 'Disconnect for now'or 'Disconnect')or 'Connect',action='connect'},
        {label='Settings...',action='settings'},
        {label='Help...',action='help'}}
    elseif u.page=='settings'then
      rows={{label='GitHub sync: '..(ctx.state.github_sync_enabled==true and 'On'or 'Off'),action='toggle'},
        {label='Automatic uploads: '..(ctx.state.github_sync_auto==true and 'On'or 'Off')..'...',action='auto_settings'}}
      rows[#rows+1]={label=ctx.state.github_sync_remember==true and 'Forget saved connection'or 'Remember connection on this device',action='remember'}
      if ctx.state.github_sync_remember==true and status.connected and status.remember_error=='connection_write_failed'then
        rows[#rows+1]={label='Retry saving connection',action='retry_remember'}
      end
      if manager then rows[#rows+1]={label='Set up or change repository...',action='setup_open'}end
    elseif u.page=='help'then
      rows={{label='Setup instructions',action='setup_guide'},{label='How to revoke access',action='revoke'}}
    elseif u.page=='auto'then
      rows={{label=ctx.state.github_sync_auto==true and 'Turn automatic uploads Off'or 'Enable automatic uploads',action='auto_toggle'},
        {label='Upload delay: '..((ctx.state.github_sync_delay==15 or ctx.state.github_sync_delay==60)and ctx.state.github_sync_delay or 30)..' seconds',action='auto_delay'},
        {label='Retry pending uploads',action='auto_retry'},
        {label='Clear upload queue',action='auto_clear'}}
      for _,v in ipairs(auto.items)do rows[#rows+1]={label=(v.held and 'Review: 'or 'Pending: ')..v.name,action=v.reason=='conflict'and 'review'or 'auto_info',file=v}end
    elseif u.page=='remote'then
      rows[#rows+1]={label='Refresh remote folder',action='browse'}
      for _,r in ipairs(s.rows)do rows[#rows+1]={label=r.name..'...',action='select',file=r}end
    elseif u.page=='confirm'then
      rows={{label='Cancel',action='back'}}
      rows[#rows+1]={label='Download as local copy',action='download',file=u.selected}
      rows[#rows+1]={label='Version history...',action='file_history',file=u.selected}
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
    elseif u.page=='review'then
      if s.review.remote.exists then rows[#rows+1]={label='Use GitHub version locally',action='choose_local'}end
      rows[#rows+1]={label='Keep local version on GitHub',action='choose_github'}
      rows[#rows+1]={label='Refresh both versions',action='review',file={name=s.review.name}}
    elseif u.page=='resolve_local'or u.page=='resolve_github'then
      rows={{label='Cancel',action='back'},
        {label=u.page=='resolve_local'and 'Replace local version'or 'Overwrite GitHub version',action=u.page=='resolve_local'and 'resolve_local'or 'resolve_github'}}
    elseif u.page=='conflict'then
      rows={{label='Cancel',action='back'},{label='Review both versions',action='review'}}
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
    local approving=status.user_code~=nil
    if approving then rows={{label='Cancel sign-in',action='cancel_auth'}}end
    header={config.scope.repo..' / '..config.scope.branch,'Status: '..status.state:gsub('_',' '),s.notice}
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
    if u.page=='settings'then header[1]='Settings' end
    if u.page=='help'then header[1]='Help' end
    if u.page=='confirm'then header[3]='Download: '..u.selected.name end
    if u.page=='history'then
      header[1]='History: '..(u.history_name or '')
      header[2]='Page '..(s.history and s.history.page or 1)..' / '..status.state:gsub('_',' ')
    end
    if u.page=='version'then header[3]=u.version.date..' '..u.version.sha:sub(1,7)..'\nOriginals kept; restore creates a copy.'end
    if u.page=='revoke'then header[3]='GitHub Settings > Applications > Authorized GitHub Apps. Revoke inkWrite; then disconnect here.'end
    if s.review and reviewing() then
      header[1]='Review: '..s.review.name
      header[2]='Local '..#s.review.file.bytes..' B / GitHub '..(s.review.remote.exists and #s.review.remote.bytes..' B'or 'missing')
      header[3]=s.notice
      if u.page=='compare'then header={'Read-only: '..s.review.name}end
      if u.page=='resolve_local'then header[3]='Replace local text with GitHub? A backup of local text is kept first.'end
      if u.page=='resolve_github'then header[3]='Overwrite GitHub with local text? The reviewed GitHub version is backed up on SD first.'end
    end
    if u.page=='update'then header[3]='Only GitHub changed. A local backup is kept before updating.'end
    if u.page=='connect'then header[3]='Save GitHub login unencrypted on SD.\nAnyone with the card can recover it.'end
    if u.page=='remember'then header[3]='Save GitHub login unencrypted on SD.\nAnyone with the card can recover it.'end
    if wizard and wizard.active then
      rows,header,status=wizard:view(ctx);approving=status.user_code~=nil;status_lines=1
    end
    local page_name=wizard and wizard.active and wizard.page or u.page
    local guide=page_name=='setup_guide'
    if guide then
      local address=GuideQR.url:gsub('(/blob/main/)','\n%1',1)
      rows={};header={'Setup instructions',address,'Scan with your phone camera.'}
      approving=false;status_lines=2
    end
    local o=ctx.screen.occlusion or {};local x,y=(o.left or 0)+16,(o.top or 0)+12
    local w=ctx.screen.width-(o.right or 0)-x-16
    local bottom=ctx.screen.height-(o.bottom or 0)-18
    local notice_lines=(u.page=='remember'or u.page=='connect'or u.page=='auto')and (w>=640 and 3 or 4)or 2
    if wizard and wizard.active then notice_lines=approving and 2 or 4 end
    if u.page=='compare'then notice_lines=0;status_lines=0 end
    if u.page=='resolve_local'or u.page=='resolve_github'then notice_lines=4 end
    if guide then notice_lines=1 end
    local line=small.line_height+4
    local rh=math.max(44,small.line_height+12)
    if wizard and wizard.active and not guide then
      local room=bottom-48-(y+title.line_height+8)-line*(1+status_lines)-rh
      notice_lines=math.max(0,math.min(notice_lines,room//line))
    end
    local top=y+title.line_height+8+line*(1+status_lines+notice_lines)
    local qr
    local qr_data=approving and ApprovalQR or guide and GuideQR
    if qr_data then
      local available=math.min(w,bottom-top-48-(approving and rh or 0)-10,222)
      local scale=math.floor(available/qr_data.size)
      if scale>=2 then
        local size=qr_data.size*scale
        qr={x=x+(w-size)//2,y=top+2,size=size,scale=scale,rects=qr_data.rects}
        top=qr.y+size+8
      end
    end
    local footer_y=bottom-48
    local per=math.max(1,(footer_y-top)//rh)
    u.focus=math.max(1,math.min(#rows,u.focus))
    local page=((u.focus-1)//per)+1;local pages=math.max(1,(#rows+per-1)//per)
    geometry={x=x,y=y,w=w,bottom=bottom,page=page,pages=pages,touch_left=o.left or 0,touch_right=ctx.screen.width-(o.right or 0),touch_bottom=ctx.screen.height-(o.bottom or 0),footer_y=footer_y,footer_left=(o.left or 0)+20,footer_right=ctx.screen.width-(o.right or 0)-20,top=top,row=rh,per=per,first=((u.focus-1)//per)*per+1,line=line,notice_lines=notice_lines,status_lines=status_lines,qr=qr}
    local comparison=u.comparison
    if u.page=='compare' and comparison then
      local direction=ctx.screen.width>ctx.screen.height and 'vertical' or 'horizontal'
      local panes=Panes.split({x=x,y=top,w=w,h=math.max(0,footer_y-top-8)},direction,'1:1',8)
      geometry.panes=panes
      for i,rect in ipairs({panes.a,panes.b}) do
        local reader=comparison.readers[i]
        if reader then reader:prepare(ctx,small,math.max(1,rect.w-16),rect.h-line-8) end
      end
    end
    local next_key=table.concat({u.page,u.focus,status.state,status.user_code or '',tostring(status.busy),status.reason or '',status.remember_error or '',tostring(s.busy),s.file_status,tostring(ctx.state.github_sync_enabled),tostring(ctx.state.github_sync_remember),s.notice,s.review and s.review.name or '',comparison and comparison.active or 0,comparison and comparison.readers[1].page or 0,comparison and comparison.readers[2] and comparison.readers[2].page or 0,auto.notice,tostring(ctx.state.github_sync_auto),tostring(ctx.state.github_sync_delay),#auto.items,#rows,wizard and wizard.active and wizard.page or '',table.concat(header,'|'),s.history and s.history.page or 0,s.history and s.history.anchor or '',x,y,w,bottom},'|')
    if key~=next_key then key=next_key;ctx:invalidate()end
  end
  local function setup_locked()return manager and (manager.error or not manager.config)end
  if manager then
    wizard=SetupUI.new(manager,function(ctx,next_config,selected,candidate)
      auto:interrupt(ctx)
      if auto.dirty and not auto:flush(ctx)then return nil,'Could not save the old upload queue. Retry before switching.'end
      s:disconnect(ctx);u.pending=nil
      ctx.state.github_sync_auto=false;ctx.state.github_sync_enabled=false;ctx.state.github_sync_remember=false
      local final,e=manager:save(next_config,selected)
      if not final then return nil,e end
      local p=d.primitives or Primitives.new(ctx)
      if candidate and not candidate:activate_setup(ctx,final)then candidate:disconnect();candidate=nil end
      config=final
      local next_dependencies={config=config,primitives=p,auth=candidate}
      s=Session.new(hooks,next_dependencies);auto=Automatic.new(s,hooks,next_dependencies)
      s.on_checkpoint=function(c,name,fingerprint)auto:ack(c,name,fingerprint)end
      s.on_connected=function(c)auto:connection_verified(c)end
      u.session=s;u.auto=auto;u.page='main';u.focus=1;u.parents={};u.comparison=nil
      s.notice=candidate and 'Setup saved. Connected; automatic uploads Off.'or 'Setup selected. Connect to verify access; automatic uploads Off.'
      return final
    end,d)
    u.setup=wizard
  end
  function u:open(ctx)
    auto:interrupt(ctx);auto:load(ctx);auto:prune_missing(ctx);self.active=true;self.page='main';self.focus=1
    self.parents={};self.comparison=nil;self.wizard_focus=nil;key=nil
    if setup_locked()then wizard:open()else s:open(ctx)end;prepare(ctx)
  end
  local function back(ctx)
    if wizard and wizard.active then
      local root=wizard.page=='setup';u.focus=wizard:back(ctx) or u.wizard_focus or 1
      if root and setup_locked()then u.active=false;ctx:invalidate()else prepare(ctx)end;return
    end
    if u.pending then u.pending=nil;s:disconnect(ctx)end
    if s.busy then s:disconnect(ctx)end
    if u.page=='main'then s:close(ctx);u.active=false;ctx:invalidate();return end
    if u.page=='conflict'then s.conflict=nil end
    if u.page=='update'then s.pending_update=nil end
    if u.page=='version'then u.version=nil end
    if u.page=='confirm'then u.selected=nil end
    if u.page=='compare'then leave_review() else up() end
    prepare(ctx)
  end
  local function connect(ctx)
    local current=s:status(ctx)
    if current.busy or current.user_code then return end
    if ctx.state.github_sync_remember==true or ctx.state.github_sync_connection_choice==true then
      ctx.state.github_sync_enabled=true;s:connect(ctx)
    else enter('connect') end
  end
  local function perform(ctx,r)
    if r.action=='setup_open'then auto:interrupt(ctx);u.wizard_focus=u.focus;wizard:open();u.focus=1
    elseif r.action=='cancel_auth'then u.pending=nil;s:disconnect(ctx);u.focus=1
    elseif r.action=='settings'or r.action=='help'or r.action=='setup_guide'or r.action=='revoke'then enter(r.action)
    elseif r.action=='review'then
      s:review_document(ctx,r.file and r.file.name)
      if u.page=='conflict'and not s.conflict then up() end
    elseif r.action=='choose_local'or r.action=='choose_github'then
      enter(r.action=='choose_local'and 'resolve_local'or 'resolve_github')
    elseif r.action=='resolve_local'or r.action=='resolve_github'then
      s:resolve_review(ctx,r.action=='resolve_local'and 'local'or 'github');up()
    elseif r.action=='sync'then
      s:sync(ctx)
    elseif r.action=='auto_settings'then auto:load(ctx);enter('auto')
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
    elseif r.action=='update_local'then s:update_local(ctx);up()
    elseif r.action=='update_copy'then s:download(ctx,s.pending_update);up()
    elseif r.action=='connect_remember'or r.action=='connect_once'then
      ctx.state.github_sync_enabled=true;ctx.state.github_sync_connection_choice=true
      if r.action=='connect_remember'then s:remember(ctx)end
      up();s:connect(ctx)
    elseif r.action=='current_history'then
      do
        local info=hooks.describe and hooks.describe()
        if info and info.name then u.history_name=info.name;enter('history');s.history=nil;s:current_history(ctx)
        else s.notice='Open a document to view its history.'end
      end
    elseif r.action=='file_history'then
      u.history_name=r.file.name;enter('history');s.history=nil;s:history_page(ctx,r.file.name,1)
    elseif r.action=='history_refresh'then s:history_page(ctx,u.history_name,1);u.focus=1
    elseif r.action=='history_prev'or r.action=='history_next'then
      local h=s.history;if h then s:history_page(ctx,h.name,h.page+(r.action=='history_next'and 1 or -1),h.anchor);u.focus=1 end
    elseif r.action=='version'then u.version=r.file;enter('version')
    elseif r.action=='restore_version'then s:restore_revision(ctx,r.file);u.version=nil;up()
    elseif r.action=='new'then s:upload(ctx,true);up()
    elseif r.action=='browse'then
      if u.page~='remote'then enter('remote') end
      u.focus=1;s:browse(ctx)
    elseif r.action=='select'then u.selected=r.file;enter('confirm')
    elseif r.action=='download'then s:download(ctx,r.file);u.selected=nil;up() end
    if r.action=='remember'then
      if ctx.state.github_sync_remember==true then s:forget(ctx)
      else enter('remember') end
    elseif r.action=='consent'then s:remember(ctx);up()
    elseif r.action=='retry_remember'then s:remember(ctx)end
    prepare(ctx)
  end
  local network_actions={review=true,resolve_local=true,resolve_github=true,sync=true,browse=true,current_history=true,file_history=true,
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
    if wizard and wizard.active then
      if r.action=='setup_cancel'then back(ctx);return end
      wizard:perform(ctx,r,u.focus)
      if r.action~='setup_edit'then u.focus=1 end
      prepare(ctx);return
    end
    if setup_locked()then wizard:open();u.focus=1;prepare(ctx);return end
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
    if geometry.panes then u.comparison.readers[u.comparison.active]:turn(delta);return end
    local target=geometry.page+delta
    if target>=1 and target<=geometry.pages then u.focus=(target-1)*geometry.per+1 end
  end
  function u:review_document(ctx,name)
    self:open(ctx);if setup_locked()then return end;local r={action='review',file=name and {name=name}}
    status=s:status(ctx)
    if not status.connected or status.busy then self.pending=r;connect(ctx);prepare(ctx);continue_pending(ctx)else perform(ctx,r)end
  end
  function u:sync_document(ctx)self:open(ctx);if not setup_locked()then activate(ctx,1)end;prepare(ctx)end
  function u:input(ctx,ev)
    if ev.type=='key'then
      if ev.key=='back'and not (ev.source=='keyboard'and ev.code=='Escape') then
        if ev.phase=='up'then back(ctx)end
      elseif ev.phase=='down'or ev.phase=='repeat'then
        local code=ev.code or ev.key
        if code=='Escape'then if ev.phase=='down'then back(ctx)end
        elseif geometry.panes then
          if code=='ArrowUp'or code=='up'or code=='PageUp'then turn_page(-1)
          elseif code=='ArrowDown'or code=='down'or code=='PageDown'then turn_page(1)
          elseif code=='left'or code=='ArrowLeft'then self.comparison.active=1
          elseif code=='right'or code=='ArrowRight'then
            if self.comparison.readers[2]then self.comparison.active=2 end
          elseif code=='Tab'and ev.phase=='down'and self.comparison.readers[2]then
            self.comparison.active=3-self.comparison.active
          elseif (code=='Enter'or code=='ok')and ev.phase=='down'then enter('review') end
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
        local relative=(ev.x-l.touch_left)/(l.touch_right-l.touch_left)
        if l.panes then
          if relative<0.25 then back(ctx)
          elseif relative<0.5 then enter('review')
          else turn_page(relative<0.75 and -1 or 1)end
        elseif relative<1/3 then back(ctx)
        else turn_page(relative<2/3 and -1 or 1)end
      elseif l.panes then
        local i=Panes.hit(l.panes,ev.down_x or ev.x,ev.down_y or ev.y)
        if i and self.comparison.readers[i] then
          if tap or ev.gesture=='swipe_up'or ev.gesture=='swipe_down'then self.comparison.active=i end
          if ev.gesture=='swipe_up'then turn_page(1)
          elseif ev.gesture=='swipe_down'then turn_page(-1)end
        end
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
    if wizard and wizard.active then wizard:tick(ctx);prepare(ctx);return end
    if s:status(ctx).state=='authorizing'then s:poll(ctx)end
    continue_pending(ctx);prepare(ctx)
  end
  function u:pause(ctx)auto:pause(ctx);s:pause(ctx);key=nil;if self.active then prepare(ctx)end end
  function u:resume(ctx)auto:resume(ctx);if self.active then key=nil;if not(wizard and wizard.active)then s:open(ctx)end;prepare(ctx)end end
  function u:leave(ctx)if wizard then wizard:cancel()end;auto:pause(ctx,true);self.pending=nil;self.comparison=nil;s:leave(ctx)end
  function u:draw(ctx,g)
    local l=geometry;g:clear(0)
    g:text(l.x,l.y,l.panes and 'Compare versions'or 'GitHub sync',{font=title,color=15})
    if l.pages>1 then g:text(l.x+l.w,l.y,l.page..' / '..l.pages,{font=small,color=15,align='right'})end
    local y=l.y+title.line_height+8
    for i,line in ipairs(header)do
      if i~=3 or l.notice_lines>0 then
        g:text_box(l.x,y,l.w,l.line*(i==3 and l.notice_lines or i==2 and l.status_lines or 1),line,{font=small,color=15,wrap='word',overflow='ellipsis'})
      end
      y=y+l.line*(i==2 and l.status_lines or 1)
    end
    if l.qr then
      local q=l.qr
      g:rect(q.x,q.y,q.size,q.size,{color=0,fill=true})
      for _,r in ipairs(q.rects)do
        g:rect(q.x+r[1]*q.scale,q.y+r[2]*q.scale,r[3]*q.scale,q.scale,{color=15,fill=true})
      end
    end
    if l.panes then
      for i,rect in ipairs({l.panes.a,l.panes.b}) do
        local reader=self.comparison.readers[i]
        local label=i==1 and 'Local'or 'GitHub'
        if reader then label=label..' / Page '..reader.page end
        local x,y=rect.x+8,rect.y+4
        g:rect(rect.x,rect.y,rect.w,rect.h,{color=15,line_width=i==self.comparison.active and 2 or 1})
        g:text_box(x,y,rect.w-16,l.line,label,{font=small,color=15,overflow='ellipsis'})
        if reader and reader.bytes>0 then
          for row,r in ipairs(reader.lines)do
            g:text(x,y+row*l.line,r.text,{font=small,color=15})
          end
        else
          g:text_box(x,y+l.line,rect.w-16,l.line,reader and 'Empty file'or 'No GitHub version',{font=small,color=15,overflow='ellipsis'})
        end
      end
    end
    for i=l.first,math.min(#rows,l.first+l.per-1)do
      local ry=l.top+(i-l.first)*l.row
      if i==self.focus or rows[i].primary then g:rect(l.x,ry,l.w,l.row-2,{color=15,line_width=rows[i].primary and 2 or 1})end
      g:text_box(l.x+10,ry+6,l.w-20,l.row-8,rows[i].label,{font=small,color=15,overflow='ellipsis'})
    end
    g:line(l.footer_left,l.footer_y,l.footer_right,l.footer_y,{color=15})
    local fy=l.footer_y+33
    if l.panes then
      local reader=self.comparison.readers[self.comparison.active]
      local width=(l.touch_right-l.touch_left)//4
      local labels={'Back','Actions',reader.page>1 and 'Prev',reader.more and 'Next'}
      for i,label in ipairs(labels)do
        if label then g:text(l.touch_left+(2*i-1)*width//2,fy,label,{font=small,color=15,align='center',valign='middle'})end
      end
      return
    end
    g:text(l.footer_left+45,fy,'Back',{font=title,color=15,align='center',valign='middle'})
    if l.page>1 then g:text((l.footer_left+l.footer_right)//2,fy,'Prev',{font=title,color=15,align='center',valign='middle'})end
    if l.page<l.pages then g:text(l.footer_right,fy,'Next',{font=title,color=15,align='right',valign='middle'})end
  end
  return u
end
return M
