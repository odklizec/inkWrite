-- Setup owns a separate RAM-only sign-in until the user confirms the destination.
local Auth=require('domain.sync_auth')
local Primitives=require('domain.sync_primitives')
local M={}
function M.new(manager,changed,dependencies)
  local d=dependencies or {};local w={active=false,page='setup',notice='',fields={}}
  local auth,verified_config,selected_profile,waiting
  local parents={}
  local function stop()if auth then auth:disconnect()end;auth=nil;verified_config=nil;selected_profile=nil end
  local function reset()
    stop();parents={};waiting=nil;w.list=nil;w.repo=nil
  end
  local function location(focus)
    return {page=w.page,list=w.list,repo=w.repo,focus=focus}
  end
  local function enter(page,focus)
    parents[#parents+1]=location(focus);w.page=page
  end
  function w:open()
    reset();self.active=true;self.page='setup';self.notice=manager.error or ''
    local c=manager.config;self.fields={client_id=c and c.client_id or '',app_id=c and tostring(c.app_id)or '',login=c and c.login or ''}
  end
  function w:status(ctx)return auth and auth:status(ctx)or {state='disconnected',connected=false}end
  function w:cancel()reset();self.active=false end
  function w:back(ctx)
    if self.page=='setup'then self:cancel();return end
    local parent
    if waiting then
      parent=waiting.page=='setup_signin'and table.remove(parents) or waiting
      waiting=nil
    else parent=table.remove(parents) end
    if parent and parent.page=='setup'then
      reset()
    elseif auth and not auth:back_to_setup(ctx)then
      reset();self.page='setup';self.notice='Session expired. Sign in again.';return 1
    end
    self.page=parent and parent.page or 'setup';self.list=parent and parent.list;self.repo=parent and parent.repo
    verified_config=nil;selected_profile=nil;self.notice=''
    return parent and parent.focus or 1
  end
  local function result(c,v,e,page)
    if v then w.list=v;w.page=page;w.notice=#v.rows==0 and 'No matching entries on this page.'or ''
    else
      local messages={repository_limit='Limit: 100 selected repositories. Narrow the App installation and retry.',
        access_forbidden='Check App permissions and selected private repositories, then sign in again.',
        request_failed='Check access and initialize the repository with a README, then retry.',
        no_network='No network. Reconnect and sign in again.',timeout='GitHub timed out. Sign in again.',
        account_mismatch='Account changed. Retry with the expected GitHub login.',
        branch_mismatch='Branch missing or unsupported. Check GitHub and retry.',
        repository_scope_mismatch='Repository access changed. Check installation and retry.'}
      reset();w.notice=messages[e]or 'Connection failed. Retry setup.';w.page='setup'
    end
    c:invalidate()
  end
  local function load_list(ctx,focus,page,request)
    local origin=location(focus)
    waiting=origin;w.page='setup_wait'
    local function done(c,v,e)
      if waiting~=origin then return end
      waiting=nil
      if v and origin.page~=page and origin.page~='setup_signin'then parents[#parents+1]=origin end
      result(c,v,e,page)
    end
    local ok,e=request(done)
    if not ok then done(ctx,nil,e)end
  end
  function w:perform(ctx,r,focus)
    if r.action=='setup_edit'then
      stop();self.page='setup';self.notice=''
      if not ctx.input or not ctx.input.text then self.notice='Text entry unavailable. Update firmware.';return end
      local field=r.field
      ctx.input:text({title=r.title,text=self.fields[field],max_bytes=field=='login'and 39 or field=='app_id'and 10 or 64},function(c,text)
        if text and w.active then w.fields[field]=text;w.notice='';c:invalidate()end
      end)
    elseif r.action=='setup_guide'or r.action=='setup_profiles'then enter(r.action,focus)
    elseif r.action=='setup_signin'then
      stop();local p=d.primitives or Primitives.new(ctx)
      local public={client_id=self.fields.client_id,app_id=tonumber(self.fields.app_id),login=self.fields.login}
      auth=Auth.setup(public,p)
      if not auth then self.notice='Enter a valid public Client ID, numeric App ID and GitHub login.';return end
      enter('setup_signin',focus);self.notice='Approve the App in your browser.'
      auth:start(ctx)
    elseif r.action=='setup_repos'then
      load_list(ctx,focus,'setup_repos',function(done)return auth:setup_repos(ctx,r.number or 1,done)end)
    elseif r.action=='setup_repo'or r.action=='setup_branches'then
      local repo=r.file or self.repo
      load_list(ctx,focus,'setup_branches',function(done)
        return auth:setup_branches(ctx,repo,r.number or 1,function(c,v,e)
          if v then self.repo=repo end
          done(c,v,e)
        end)
      end)
    elseif r.action=='setup_branch'then
      local origin=location(focus)
      waiting=origin;self.page='setup_wait'
      local function done(c,v,e)
        if waiting~=origin then return end
        waiting=nil
        if v then
          parents[#parents+1]=origin;verified_config=v;self.page='setup_confirm'
          self.notice='Verified private repository. Local files stay on SD.'
        else reset();self.page='setup';self.notice=e or 'Repository check failed.'end
        c:invalidate()
      end
      local ok,e=auth:bind_setup(ctx,r.file,done)
      if not ok then done(ctx,nil,e)end
    elseif r.action=='setup_saved'then
      stop();selected_profile=r.number;verified_config=manager.profiles[r.number];enter('setup_confirm',focus)
      self.notice='Connect after switching. Sync records and pending uploads belong to each repository setup.'
    elseif r.action=='setup_save'then
      if not verified_config then return end
      if not selected_profile and (not auth or not auth:status(ctx).connected)then self.notice='Session expired. Return and sign in again.';return end
      local config,e=changed(ctx,verified_config,selected_profile,auth)
      if config then auth=nil;self:cancel()
      else self.notice=e or 'Setup was not saved.'end
    end
  end
  function w:tick(ctx)
    if not auth then return end
    local s=auth:status(ctx)
    if s.state=='authorizing'then auth:poll(ctx)end
    if s.setup_ready and self.page=='setup_signin'then self:perform(ctx,{action='setup_repos'})end
  end
  function w:pause()end
  function w:view(ctx)
    local rows={};local status=self:status(ctx);local header={'GitHub setup','Direct device sign-in',self.notice}
    if self.page=='setup'then
      rows={{label='Client ID: '..self.fields.client_id,action='setup_edit',field='client_id',title='GitHub App public Client ID'},
        {label='App ID: '..self.fields.app_id,action='setup_edit',field='app_id',title='GitHub App numeric ID'},
        {label='GitHub login: '..self.fields.login,action='setup_edit',field='login',title='Your GitHub login'},
        {label='Sign in and choose repository',action='setup_signin'},
        {label='Setup instructions',action='setup_guide'}}
      if manager.config then header[2]='Active: '..manager.config.scope.repo..' / '..manager.config.scope.branch end
      for _,v in ipairs(manager.profiles)do
        if not manager.config or v.profile~=manager.config.profile then
          rows[#rows+1]={label='Switch to a saved repository...',action='setup_profiles'};break
        end
      end
      if manager.error then rows={{label='Setup instructions',action='setup_guide'}}end
    elseif self.page=='setup_profiles'then
      header={'Saved repositories','Choose a repository and branch',''}
      for i,v in ipairs(manager.profiles)do
        if not manager.config or v.profile~=manager.config.profile then
          rows[#rows+1]={label=v.scope.repo..' / '..v.scope.branch,action='setup_saved',number=i}
        end
      end
    elseif self.page=='setup_repos'or self.page=='setup_branches'then
      local repos=self.page=='setup_repos';header[2]=(repos and 'Choose private repository'or 'Choose branch')..' / page '..self.list.page
      for _,v in ipairs(self.list.rows)do rows[#rows+1]={label=(repos and v.full_name..'...' or v.name),action=repos and 'setup_repo'or 'setup_branch',file=v}end
      if self.list.page>1 then rows[#rows+1]={label='Previous results',action=repos and 'setup_repos'or 'setup_branches',number=self.list.page-1}end
      if self.list.more then rows[#rows+1]={label='More results',action=repos and 'setup_repos'or 'setup_branches',number=self.list.page+1}end
    elseif self.page=='setup_confirm'then
      header={verified_config.scope.repo,verified_config.login..' / '..verified_config.scope.branch,self.notice..' Automatic uploads will be Off.'}
      rows={{label='Cancel',action='setup_cancel'},{label='Save and use this setup',action='setup_save'}}
    elseif self.page=='setup_signin'then
      header[2]='Status: '..status.state:gsub('_',' ')
      if status.user_code then header[2]='github.com/login/device';header[3]='Sign-in code: '..status.user_code..'\nApprove the App in your browser.'end
      if status.reason then
        local errors={account_mismatch='Signed into another account. Retry with the expected login.',app_not_installed='Install this App on your account and selected private repository, then retry.',
          installation_scope_mismatch='Use selected repositories, Contents write and Metadata read only. Check App installation.',installation_limit='Over 20 installations. Use an account within the setup limit.',
          device_flow_disabled='Enable device flow in GitHub App settings.',incorrect_client_credentials='Check the public Client ID.',no_network='No network. Reconnect and retry.',repository_limit='Choose an App installation with at most 100 repositories.'}
        header[3]=errors[status.reason]or 'Sign-in failed or expired. Go Back and retry.'
      end
    elseif self.page=='setup_wait'then
      header[2]='Checking GitHub...';header[3]='Local documents are unchanged.'
    end
    return rows,header,status
  end
  return w
end
return M
