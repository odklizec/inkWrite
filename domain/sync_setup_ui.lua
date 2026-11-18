-- Setup owns a separate RAM-only sign-in until the user confirms the destination.
local Auth=require('domain.sync_auth')
local Primitives=require('domain.sync_primitives')
local M={}
function M.new(manager,changed,dependencies)
  local d=dependencies or {};local w={active=false,page='setup',notice='',fields={}}
  local auth,verified_config,selected_profile
  local function stop()if auth then auth:disconnect()end;auth=nil;verified_config=nil;selected_profile=nil end
  function w:open()
    stop();self.active=true;self.page='setup';self.notice=manager.error or ''
    local c=manager.config;self.fields={client_id=c and c.client_id or '',app_id=c and tostring(c.app_id)or '',login=c and c.login or ''}
  end
  function w:status(ctx)return auth and auth:status(ctx)or {state='disconnected',connected=false}end
  function w:cancel()stop();self.active=false end
  function w:back()
    if self.page=='setup'then self:cancel()else stop();self.page='setup';self.notice=''end
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
      w.notice=messages[e]or 'Connection failed. Go Back and retry setup.';w.page='setup'
    end
    c:invalidate()
  end
  function w:perform(ctx,r)
    if r.action=='setup_edit'then
      stop();self.page='setup';self.notice=''
      if not ctx.input or not ctx.input.text then self.notice='Text entry unavailable. Update firmware.';return end
      local field=r.field
      ctx.input:text({title=r.title,text=self.fields[field],max_bytes=field=='login'and 39 or field=='app_id'and 10 or 64},function(c,text)
        if text and w.active then w.fields[field]=text;w.notice='';c:invalidate()end
      end)
    elseif r.action=='setup_help'then self.page='setup_help'
    elseif r.action=='setup_signin'then
      stop();local p=d.primitives or Primitives.new(ctx)
      local public={client_id=self.fields.client_id,app_id=tonumber(self.fields.app_id),login=self.fields.login}
      auth=Auth.setup(public,p)
      if not auth then self.notice='Enter a valid public Client ID, numeric App ID and GitHub login.';return end
      self.page='setup_signin';self.notice='Approve the App in your browser.'
      auth:start(ctx)
    elseif r.action=='setup_repos'then
      self.page='setup_wait';auth:setup_repos(ctx,r.number or 1,function(c,v,e)result(c,v,e,'setup_repos')end)
    elseif r.action=='setup_repo'or r.action=='setup_branches'then
      self.repo=r.file or self.repo;self.page='setup_wait'
      auth:setup_branches(ctx,self.repo,r.number or 1,function(c,v,e)result(c,v,e,'setup_branches')end)
    elseif r.action=='setup_branch'then
      self.page='setup_wait';auth:bind_setup(ctx,r.file,function(c,v,e)
        if v then verified_config=v;w.page='setup_confirm';w.notice='Verified private repository. Local files stay on SD.'
        else w.page='setup';w.notice=e or 'Repository check failed.'end;c:invalidate()
      end)
    elseif r.action=='setup_saved'then
      stop();selected_profile=r.number;verified_config=manager.profiles[r.number];self.page='setup_confirm'
      self.notice='Saved setup. Its records and pending uploads are kept separately.'
    elseif r.action=='setup_save'then
      if not verified_config then return end
      if not selected_profile and (not auth or not auth:status(ctx).connected)then self.notice='Session expired. Return and sign in again.';return end
      local config,e=changed(ctx,verified_config,selected_profile,auth)
      if config then auth=nil;verified_config=nil;self.active=false
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
        {label='Setup instructions',action='setup_help'}}
      for i,v in ipairs(manager.profiles)do rows[#rows+1]={label='Use saved: '..v.scope.repo..' / '..v.scope.branch,action='setup_saved',number=i}end
      if manager.error then rows={{label='Setup instructions',action='setup_help'}}end
    elseif self.page=='setup_help'then
      header={'Before signing in','Your own GitHub App + private repo','GitHub App: enable device flow; Contents read/write, Metadata read. Install on selected private repositories. Initialize the repo with a README.'}
    elseif self.page=='setup_repos'or self.page=='setup_branches'then
      local repos=self.page=='setup_repos';header[2]=(repos and 'Choose private repository'or 'Choose branch')..' / page '..self.list.page
      for _,v in ipairs(self.list.rows)do rows[#rows+1]={label=repos and v.full_name or v.name,action=repos and 'setup_repo'or 'setup_branch',file=v}end
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
    else header[2]='Checking GitHub...';header[3]='Local documents are unchanged.'end
    return rows,header,status
  end
  return w
end
return M
