-- GitHub App device flow, with optional consented app-private credential storage.
local Transport=require('domain.sync_transport')
local Sync=require('domain.sync')
local Payload=require('domain.github_payload')
local Credentials=require('domain.sync_credentials')
local M={API_VERSION='2026-03-10',VERIFY_URL='https://github.com/login/device'}
local int=Transport.integer
local function login_ok(v)return type(v)=='string'and #v>0 and #v<=39 and not v:find('[^A-Za-z0-9-]')end
local function encode(s)return (s:gsub('[^A-Za-z0-9_.~-]',function(c)return string.format('%%%02X',c:byte())end))end
local function age(t,start)return (t-start)&0x7fffffff end
local function clock(ctx)
  local value=Transport.call(ctx.clock,'millis')
  if int(value,0,2147483647)then return value end
end
local function only_one(items)
  if type(items)~='table'or type(items[1])~='table'then return nil end
  for k in pairs(items)do if k~=1 then return nil end end
  return items[1]
end
local function config_ok(c)
  return Sync.fields(c,{client_id=true,app_id=true,login=true,scope=true,repository_id=true,selectable=true,profile=true})
    and type(c.client_id)=='string'and #c.client_id>=8 and #c.client_id<=64
    and not c.client_id:find('[^A-Za-z0-9_.-]')and int(c.app_id,1,2147483647)
    and (c.selectable==nil or c.selectable==true)and (c.profile==nil or int(c.profile,1,4))
    and login_ok(c.login)and Sync.scope_ok(c.scope)
    and (c.repository_id==nil or int(c.repository_id,1,2147483647))
end
M.config_ok=config_ok
function M.new(config,primitives,discovery)
  if not config_ok(config)then return nil,'setup_required'end
  if type(primitives)~='table'or type(primitives.hash)~='function'or type(primitives.codec)~='table'then return nil,'primitives_unavailable'end
  -- Copy public setup: mutating caller tables cannot retarget a live session.
  local client_id,app_id,expected_login=config.client_id,config.app_id,config.login
  local scope={repo=config.scope.repo,branch=config.scope.branch}
  local narrowed_id=config.repository_id
  local credentials=Credentials.new(config)
  local saved_record,remember_error,saved=false,nil,false
  local setup_pending,setup_ready,installation_id,candidates,branches,chosen
  local selectable=config.selectable==true
  local setup_uncommitted=discovery==true
  local owner,repo=scope.repo:match('^([^/]+)/(.+)$')
  local prefix='/repos/'..encode(owner)..'/'..encode(repo)
  local oauth=assert(Transport.new('https://github.com'))
  local api=assert(Transport.new('https://api.github.com'))
  local generation,busy=0,false
  local state,reason='disconnected',nil
  local http_status
  local token,token_start,token_ms,device_code,user_code,code_start,code_ms,last_poll,interval
  local verified,account_id,repository_id=false,nil,nil
  local s={}
  local function stop(next_state,why)
    generation=generation+1;oauth:cancel();api:cancel();busy=false
    token=nil;token_start=nil;token_ms=nil;device_code=nil;user_code=nil
    code_start=nil;code_ms=nil;last_poll=nil;interval=nil;verified=false
    account_id=nil;repository_id=nil;state=next_state;reason=why
    setup_ready=nil;setup_pending=nil;candidates=nil;branches=nil;chosen=nil;installation_id=nil
  end
  local function valid_token(ctx)
    if not token then return false end
    local now=clock(ctx)
    if not now or age(now,token_start)>=token_ms then stop('auth_required','session_expired');return false end
    return true
  end
  local function failure(err,ctx)
    local next_state=(err=='no_network'or err=='timeout'or err=='io_error')and 'offline'
      or (err=='authorization_required'and 'auth_required'or 'error')
    stop(next_state,err)
    local invalid={account_mismatch=true,installation_scope_mismatch=true,
      repository_scope_mismatch=true,branch_mismatch=true,bad_refresh_token=true,expired_token=true}
    if ctx and not setup_uncommitted and invalid[err]and ctx.state.github_sync_remember==true then
      local ok,e=credentials:forget(ctx);saved=false;saved_record=nil;remember_error=ok and nil or e
    end
  end
  local function response_error(res)
    if res.err then return res.err end
    if res.status==401 then return 'authorization_required'end
    if res.status==403 then return 'access_forbidden'end
    if res.status==409 or res.status==422 then return 'remote_race'end
    return 'request_failed'
  end
  local function headers(auth)
    local h={Accept='application/vnd.github+json',['X-GitHub-Api-Version']=M.API_VERSION,['User-Agent']='inkWrite'}
    if auth then h.Authorization='Bearer '..token end
    return h
  end
  local function send(ctx,transport,request,fn)
    local id=generation
    local ok,err=transport:request(ctx,request,function(c,res)
      if generation==id then
        http_status=int(res.status,100,599)and res.status or nil
        fn(c,res)
      end
    end)
    if not ok and generation==id then fn(ctx,{err=err})end
  end
  local function get(ctx,path,fn)
    if not valid_token(ctx)then fn(ctx,{err='session_expired'});return end
    send(ctx,api,{path=path,method='GET',headers=headers(true),response_limit=49152},fn)
  end
  local function validate_legacy(ctx,done)
    get(ctx,'/user',function(c,r)
      local u=r.data
      if r.err or r.status~=200 then done(c,nil,response_error(r));return end
      if type(u)~='table'or not login_ok(u.login)or u.login:lower()~=expected_login:lower()
        or not int(u.id,1,2147483647)or (account_id and u.id~=account_id)then done(c,nil,'account_mismatch');return end
      local user_id=u.id
      get(c,'/user/installations?per_page=2&page=1',function(c2,r2)
        if r2.err or r2.status~=200 then done(c2,nil,response_error(r2));return end
        local data=r2.data;local installation=type(data)=='table'and only_one(data.installations)
        local null=c2.json.null
        if not installation or data.total_count~=1 or installation.app_id~=app_id
          or not int(installation.id,1,2147483647)or installation.repository_selection~='selected'
          or null==nil or installation.suspended_at~=null or type(installation.account)~='table'
          or type(installation.account.login)~='string'or installation.account.login:lower()~=owner:lower()
          or not Sync.fields(installation.permissions,{contents=true,metadata=true})
          or installation.permissions.contents~='write'or installation.permissions.metadata~='read'then
          done(c2,nil,'installation_scope_mismatch');return
        end
        get(c2,'/user/installations/'..string.format('%d',installation.id)..'/repositories?per_page=2&page=1',function(c3,r3)
          if r3.err or r3.status~=200 then done(c3,nil,response_error(r3));return end
          local list=r3.data;local repository=type(list)=='table'and only_one(list.repositories)
          if not repository or list.total_count~=1 or type(repository.full_name)~='string'
            or repository.full_name:lower()~=scope.repo:lower()or not int(repository.id,1,2147483647)
            or (narrowed_id and repository.id~=narrowed_id)or (repository_id and repository.id~=repository_id)
            or repository.private~=true
            or type(repository.permissions)~='table'or repository.permissions.push~=true then
            done(c3,nil,'repository_scope_mismatch');return
          end
          local repo_id=repository.id
          -- The installation list uses a smaller repository representation.
          -- Fetch full metadata rather than assume optional detail fields exist.
          get(c3,prefix,function(c4,r4)
            if r4.err or r4.status~=200 then done(c4,nil,response_error(r4));return end
            local details=r4.data
            if type(details)~='table'or details.id~=repo_id or type(details.full_name)~='string'
              or details.full_name:lower()~=scope.repo:lower()or details.private~=true
              or details.visibility~='private'or details.archived~=false or details.disabled~=false then
              done(c4,nil,'repository_scope_mismatch');return
            end
            get(c4,prefix..'/branches/'..encode(scope.branch),function(c5,r5)
              if r5.err or r5.status~=200 then done(c5,nil,response_error(r5));return end
              local branch=r5.data
              if type(branch)~='table'or branch.name~=scope.branch or type(branch.commit)~='table'
                or not Sync.hex_ok(branch.commit.sha,40)then done(c5,nil,'branch_mismatch');return end
              if not valid_token(c5)then done(c5,nil,'session_expired');return end
              account_id=user_id;repository_id=repo_id;verified=true
              done(c5,true,nil,branch.commit.sha)
            end)
          end)
        end)
      end)
    end)
  end
  -- Setup may discover several selected repositories. Legacy connections retain
  -- the original single-installation/single-repository restriction.
  local function array(t,limit)
    if type(t)~='table'then return nil end
    local n=0;for k in pairs(t)do n=n+1;if not int(k,1,limit)then return nil end end
    for i=1,n do if type(t[i])~='table'then return nil end end
    return n<=limit and n or nil
  end
  local function installation(ctx,done)
    get(ctx,'/user',function(c,r)
      local u=r.data
      if r.err or r.status~=200 then done(c,nil,response_error(r));return end
      if type(u)~='table'or not login_ok(u.login)or u.login:lower()~=expected_login:lower()
        or not int(u.id,1,2147483647)or (account_id and account_id~=u.id)then done(c,nil,'account_mismatch');return end
      account_id=u.id
      get(c,'/user/installations?per_page=20&page=1',function(c2,r2)
        local d=r2.data
        if r2.err or r2.status~=200 then done(c2,nil,response_error(r2));return end
        if type(d)~='table'or not int(d.total_count,0,20)or array(d.installations,20)~=d.total_count then done(c2,nil,'installation_limit');return end
        local match
        for _,v in ipairs(d.installations)do
          if v.app_id==app_id then
            if match then done(c2,nil,'installation_scope_mismatch');return end
            match=v
          end
        end
        if not match then done(c2,nil,'app_not_installed');return end
        if not int(match.id,1,2147483647)or match.repository_selection~='selected'
          or c2.json.null==nil or match.suspended_at~=c2.json.null or type(match.account)~='table'
          or type(match.account.login)~='string'or match.account.login:lower()~=expected_login:lower()
          or not Sync.fields(match.permissions,{contents=true,metadata=true})
          or match.permissions.contents~='write'or match.permissions.metadata~='read'then done(c2,nil,'installation_scope_mismatch');return end
        installation_id=match.id;done(c2,true)
      end)
    end)
  end
  local function repo_ok(v)
    return type(v)=='table'and int(v.id,1,2147483647)and type(v.full_name)=='string'
      and Sync.scope_ok({repo=v.full_name,branch='main'})
      and v.full_name:match('^([^/]+)/'):lower()==expected_login:lower()
      and v.private==true and type(v.permissions)=='table'and v.permissions.push==true
  end
  local function repo_page(ctx,page,done)
    get(ctx,'/user/installations/'..string.format('%d',installation_id)..'/repositories?per_page=10&page='..page,function(c,r)
      if r.err or r.status~=200 then done(c,nil,response_error(r));return end
      local d=r.data;local n=type(d)=='table'and array(d.repositories,10)
      if not n or not int(d.total_count,0,100)then done(c,nil,'repository_limit');return end
      local rows={};for _,v in ipairs(d.repositories)do if repo_ok(v)then rows[#rows+1]={id=v.id,full_name=v.full_name}end end
      done(c,{rows=rows,page=page,more=page*10<d.total_count})
    end)
  end
  local function validate_selected(ctx,done)
    installation(ctx,function(c,ok,err)
      if not ok then done(c,nil,err);return end
      if discovery then setup_ready=true;done(c,true);return end
      local function find(c2,page)
        repo_page(c2,page,function(c3,result,e)
          if not result then done(c3,nil,e);return end
          local found
          for _,v in ipairs(result.rows)do
            if v.full_name:lower()==scope.repo:lower()and (not narrowed_id or v.id==narrowed_id)
              and (not repository_id or v.id==repository_id)then found=v;break end
          end
          if not found then if result.more and page<10 then find(c3,page+1)else done(c3,nil,'repository_scope_mismatch')end;return end
          get(c3,prefix,function(c4,r)
            local v=r.data
            if r.err or r.status~=200 then done(c4,nil,response_error(r));return end
            if not repo_ok(v)or v.id~=found.id or v.full_name:lower()~=scope.repo:lower()
              or v.visibility~='private'or v.archived~=false or v.disabled~=false then done(c4,nil,'repository_scope_mismatch');return end
            get(c4,prefix..'/branches/'..encode(scope.branch),function(c5,r5)
              local b=r5.data
              if r5.err or r5.status~=200 then done(c5,nil,response_error(r5));return end
              if type(b)~='table'or b.name~=scope.branch or type(b.commit)~='table'or not Sync.hex_ok(b.commit.sha,40)then done(c5,nil,'branch_mismatch');return end
              if not valid_token(c5)then done(c5,nil,'session_expired');return end
              repository_id=found.id;verified=true;done(c5,true,nil,b.commit.sha)
            end)
          end)
        end)
      end
      find(c,1)
    end)
  end
  local function validate_access(ctx,done)
    if selectable then validate_selected(ctx,done)else validate_legacy(ctx,done)end
  end
  function s:setup_repos(ctx,page,done)
    if not discovery or not setup_ready or busy or not int(page,1,10)then return nil,'setup_not_ready'end
    busy=true
    repo_page(ctx,page,function(c,result,e)
      busy=false;if not result then failure(e,c)else candidates=result.rows;branches=nil;chosen=nil end
      done(c,result,e)
    end);return true
  end
  function s:setup_branches(ctx,record,page,done)
    if not discovery or not setup_ready or busy or not int(page,1,10)then return nil,'setup_not_ready'end
    local candidate
    for _,v in ipairs(candidates or {})do if v==record then candidate=v end end
    if not candidate then return nil,'invalid_repository'end
    busy=true
    get(ctx,'/repos/'..encode(expected_login)..'/'..encode(candidate.full_name:match('/(.+)$'))..'/branches?per_page=10&page='..page,function(c,r)
      busy=false
      if r.err or r.status~=200 then local e=response_error(r);failure(e,c);done(c,nil,e);return end
      local n=array(r.data,10);local rows={}
      if n then for _,b in ipairs(r.data)do
        if not Sync.scope_ok({repo=candidate.full_name,branch=b.name})or type(b.commit)~='table'or not Sync.hex_ok(b.commit.sha,40)then n=nil;break end
        rows[#rows+1]={name=b.name}
      end end
      if not n then failure('branch_mismatch',c);done(c,nil,'branch_mismatch');return end
      chosen=candidate;branches=rows;done(c,{rows=rows,page=page,more=n==10 and page<10})
    end);return true
  end
  function s:bind_setup(ctx,branch,done)
    if not discovery or not setup_ready or busy or not chosen then return nil,'setup_not_ready'end
    local found;for _,v in ipairs(branches or {})do if v==branch then found=true end end
    if not found then return nil,'invalid_branch'end
    scope={repo=chosen.full_name,branch=branch.name};owner,repo=scope.repo:match('^([^/]+)/(.+)$')
    prefix='/repos/'..encode(owner)..'/'..encode(repo);narrowed_id=chosen.id
    discovery=false;busy=true;state='verifying'
    validate_selected(ctx,function(c,ok,e)
      busy=false
      if not ok then failure(e,c);done(c,nil,e);return end
      state='connected';setup_ready=nil
      done(c,{client_id=client_id,app_id=app_id,login=expected_login,scope={repo=scope.repo,branch=scope.branch},repository_id=repository_id,selectable=true})
    end);return true
  end
  function s:activate_setup(ctx,final)
    if not verified or not valid_token(ctx)or not config_ok(final)or final.client_id~=client_id or final.app_id~=app_id
      or final.login~=expected_login or final.scope.repo~=scope.repo or final.scope.branch~=scope.branch
      or final.repository_id~=repository_id then return nil,'setup_not_ready'end
    credentials=Credentials.new(final);setup_uncommitted=false
    if setup_pending then
      setup_pending.account_id=account_id;setup_pending.verified_repository_id=repository_id
      saved_record=credentials:record(setup_pending);setup_pending=nil
    end
    return true
  end
  function s:back_to_setup(ctx)
    if not setup_uncommitted or not valid_token(ctx)then return false end
    self:cancel_operation()
    discovery=true;setup_ready=true;verified=false;repository_id=nil;state='setup_ready'
    return true
  end
  local function epoch(ctx)
    local t=Transport.call(ctx.clock,'now')
    return type(t)=='table'and t.valid==true and int(t.epoch_sec,1,2147483647)and t.epoch_sec or nil
  end
  local function persist(ctx)
    if setup_uncommitted or ctx.state.github_sync_remember~=true then return true end
    if not saved_record then saved=false;remember_error=remember_error or 'remember_requires_signin';return nil end
    local ok,e=credentials:save(ctx,saved_record);saved=ok==true;remember_error=e;return ok
  end
  function s:remember(ctx)return persist(ctx)end
  function s:forget(ctx)
    self:disconnect();saved_record=nil;saved=false
    local ok,e=credentials:forget(ctx);remember_error=e;return ok
  end
  function s:disconnect()http_status=nil;stop('disconnected',nil);saved_record=nil end
  s.pause=s.disconnect;s.cancel=s.disconnect
  -- Cancel a document operation while preserving the RAM sign-in. System covers
  -- do not destroy the VM; code exchange callbacks may safely resume afterwards.
  function s:cancel_operation()
    generation=generation+1;oauth:cancel();api:cancel();busy=false
    state=verified and token and 'connected'or 'disconnected';reason=nil
  end
  local function accept_token(c,d,refreshing)
    if type(d)~='table'or type(d.access_token)~='string'or #d.access_token>255 or not d.access_token:match('^ghu_[A-Za-z0-9]+$')
      or d.token_type~='bearer'or d.scope~=''or not int(d.expires_in,61,28800)then failure('invalid_token_response',c);return end
    local now=clock(c);if not now then failure('clock_unavailable',c);return end
    token=d.access_token;token_start=now;token_ms=(d.expires_in-60)*1000
    local wall=epoch(c);local pending
    if wall and type(d.refresh_token)=='string'and #d.refresh_token<=255 and d.refresh_token:match('^ghr_[A-Za-z0-9]+$')
      and int(d.refresh_token_expires_in,61,15897600)then
      pending={access_token=token,refresh_token=d.refresh_token,issued_at=wall,
        access_expires_at=wall+d.expires_in-60,refresh_expires_at=wall+d.refresh_token_expires_in-60}
    end
    if not pending then
      saved_record=nil
      if c.state.github_sync_remember==true then
        remember_error=wall and 'refresh_unavailable'or 'clock_unavailable'
        if refreshing then credentials:forget(c);saved=false end
      end
    end
    d.access_token=nil;d.refresh_token=nil;device_code=nil;user_code=nil;code_start=nil
    if refreshing and pending and saved_record then
      pending.account_id=saved_record.account_id;pending.verified_repository_id=saved_record.verified_repository_id
      saved_record=credentials:record(pending)
      -- Rotation invalidates the old refresh token. Commit the replacement
      -- before optional verification requests can fail while offline.
      persist(c)
    end
    state='verifying';busy=true
    validate_access(c,function(c2,ok,err)
      busy=false;if not ok then failure(err,c2);return end
      if pending and not discovery then
        pending.account_id=account_id;pending.verified_repository_id=repository_id
        saved_record=credentials:record(pending)
      end
      if discovery then setup_pending=pending;saved_record=nil
      elseif not refreshing then persist(c2)end
      state=discovery and 'setup_ready'or 'connected';reason=nil
      if c2.invalidate then c2:invalidate()end
    end)
  end
  local function refresh_saved(ctx,record)
    token=nil;token_start=nil;token_ms=nil;verified=false
    state='refreshing';busy=true
    send(ctx,oauth,{path='/login/oauth/access_token',method='POST',response_limit=4096,
      headers={Accept='application/json',['Content-Type']='application/x-www-form-urlencoded',['User-Agent']='inkWrite'},
      body='client_id='..encode(client_id)..'&grant_type=refresh_token&refresh_token='..encode(record.refresh_token)},function(c,res)
        busy=false
        if res.err or res.status~=200 then failure(response_error(res),c);return end
        local data=res.data
        if data.error then
          local invalid=data.error=='bad_refresh_token'or data.error=='expired_token'or data.error=='token_expired'
          failure(invalid and 'bad_refresh_token'or 'refresh_failed',c);return
        end
        accept_token(c,data,true)
      end)
  end
  function s:restore(ctx)
    if busy then return nil,'busy'end
    if setup_uncommitted or ctx.state.github_sync_remember~=true then return false end
    local record,e=credentials:load(ctx)
    if not record then
      saved=false;remember_error=e
      if e then state='error';reason=e end
      return record,e
    end
    local wall,now=epoch(ctx),clock(ctx)
    if not wall or not now or wall<record.issued_at then state='error';reason='clock_unavailable';return nil,reason end
    stop('verifying',nil);saved_record=record;saved=true;remember_error=nil
    account_id=record.account_id;repository_id=record.verified_repository_id
    if record.refresh_expires_at<=wall then failure('expired_token',ctx);return nil,'expired_token'end
    busy=true
    if record.access_expires_at>wall then
      token=record.access_token;token_start=now;token_ms=(record.access_expires_at-wall)*1000
      validate_access(ctx,function(c,ok,why)
        busy=false
        if not ok then
          -- A rejected access token does not prove the refresh grant was revoked.
          -- Try exactly one renewal, without replaying any document operation.
          if why=='authorization_required'and http_status==401 then refresh_saved(c,record)
          else failure(why,c)end
          return
        end
        state='connected';reason=nil;if c.invalidate then c:invalidate()end
      end)
    else
      refresh_saved(ctx,record)
    end
    return true
  end
  function s:status(ctx)
    if token then valid_token(ctx)end
    if device_code then
      local now=clock(ctx)
      if not now or age(now,code_start)>=code_ms then stop('auth_required','code_expired')end
    end
    return {state=state,reason=reason,setup_ready=setup_ready==true,http_status=http_status,busy=busy,connected=verified and token~=nil,
      login=(verified or setup_ready)and expected_login or nil,repo=scope.repo,branch=scope.branch,
      user_code=user_code,verification_uri=user_code and M.VERIFY_URL or nil,
      remembered=saved,remember_error=remember_error}
  end
  function s:start(ctx)
    if busy then return nil,'busy'end
    if token then return nil,'disconnect_first'end
    http_status=nil;remember_error=nil;stop('requesting_code',nil);local now=clock(ctx)
    if not now then failure('clock_unavailable');return nil,'clock_unavailable'end
    busy=true;code_start=now
    send(ctx,oauth,{path='/login/device/code',method='POST',response_limit=4096,
      headers={Accept='application/json',['Content-Type']='application/x-www-form-urlencoded',['User-Agent']='inkWrite'},
      body='client_id='..encode(client_id)},function(c,res)
        busy=false
        if res.err or res.status~=200 then failure(response_error(res));return end
        local d=res.data
        if type(d)~='table'or type(d.device_code)~='string'or #d.device_code~=40 or d.device_code:find('[^A-Za-z0-9]')
          or type(d.user_code)~='string'or not d.user_code:match('^[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]%-[A-Z0-9][A-Z0-9][A-Z0-9][A-Z0-9]$')
          or d.verification_uri~=M.VERIFY_URL or not int(d.expires_in,1,900)or not int(d.interval,5,180)then failure('invalid_device_response');return end
        local current=clock(c)
        if not current or age(current,code_start)>=d.expires_in*1000 then failure('code_expired');return end
        device_code=d.device_code;user_code=d.user_code;code_ms=d.expires_in*1000
        interval=d.interval*1000;last_poll=current;state='authorizing'
      end)
    return true
  end
  function s:poll(ctx)
    if busy then return nil,'busy'end
    if not device_code then return nil,'not_authorizing'end
    local now=clock(ctx)
    if not now or age(now,code_start)>=code_ms then failure('code_expired');return nil,'code_expired'end
    if age(now,last_poll)<interval then return nil,'wait_interval'end
    busy=true;last_poll=now
    local body='client_id='..encode(client_id)..'&device_code='..encode(device_code)
      ..'&grant_type='..encode('urn:ietf:params:oauth:grant-type:device_code')
    if narrowed_id then body=body..'&repository_id='..string.format('%d',narrowed_id)end
    send(ctx,oauth,{path='/login/oauth/access_token',method='POST',response_limit=4096,
      headers={Accept='application/json',['Content-Type']='application/x-www-form-urlencoded',['User-Agent']='inkWrite'},body=body},function(c,res)
        busy=false
        local current=clock(c)
        if not current or age(current,code_start)>=code_ms then failure('code_expired');return end
        if res.err or res.status~=200 then failure(response_error(res));return end
        local d=res.data
        if d.error=='authorization_pending'and d.access_token==nil then last_poll=current;return end
        if d.error=='slow_down'and d.access_token==nil then
          local seconds=math.max(interval//1000+5,int(d.interval,5,180)and d.interval or 0)
          if seconds>180 then failure('poll_interval_exceeded');return end
          interval=seconds*1000;last_poll=current;return
        end
        if d.error~=nil then
          local errors={access_denied=true,expired_token=true,token_expired=true,device_flow_disabled=true,incorrect_client_credentials=true}
          failure(errors[d.error]and d.error or 'authorization_failed');return
        end
        accept_token(c,d,false)
      end)
    return true
  end
  local function operation(ctx,name,done,write,bytes,sha,expected_sha,before_write,commit_ref)
    if type(done)~='function'or not Sync.name_ok(name)then return nil,'invalid_argument'end
    if busy then return nil,'busy'end
    if not verified or not valid_token(ctx)then return nil,'authorization_required'end
    if write and (not Sync.text_ok(bytes)or (sha~=nil and not Sync.hex_ok(sha,40)))then return nil,'invalid_document'end
    busy=true;state='verifying';reason=nil
    validate_access(ctx,function(c,ok,err)
      if not ok then failure(err,c);done(c,nil,err);return end
      local path='documents/'..name
      local route=prefix..'/contents/documents/'..encode(name)
      local req={path=route..'?ref='..encode(commit_ref or scope.branch),method='GET',headers=headers(true),response_limit=49152}
      local fingerprint
      if write then
        if before_write and before_write(c)~=true then busy=false;state='connected';done(c,nil,'local_changed');return end
        Transport.call(c.budget,'extend')
        fingerprint=Sync.digest(primitives.hash,bytes)
        local data=Payload.write_request(scope,path,bytes,sha,primitives.codec)
        local body=data and Transport.call(c.json,'encode',data.body)
        if not fingerprint or type(body)~='string'or #body>65536 then failure('encode_failed');done(c,nil,'encode_failed');return end
        req.path=route;req.method='PUT';req.body=body;req.headers['Content-Type']='application/json'
      end
      state=write and 'uploading'or 'downloading'
      send(c,api,req,function(c2,res)
        busy=false
        if not valid_token(c2)then done(c2,nil,'session_expired');return end
        if res.err or (res.status~=200 and res.status~=201 and not (not write and res.status==404))then
          local why=response_error(res)
          if res.status==401 or (res.status==403 and res.err~='rate_limited')then failure(why,c2)
          else state=(why=='timeout'or why=='no_network'or why=='io_error')and 'offline'or 'error';reason=why end
          done(c2,nil,why);return
        end
        local result,why
        if write then result,why=Payload.written(res.status,res.data,path,fingerprint)
        else
          result,why=Payload.read(res.status,res.data,path,primitives.codec)
          if result and expected_sha and (not result.exists or result.sha~=expected_sha)then result=nil;why='remote_changed'end
        end
        state=result and 'connected'or 'error';reason=why
        done(c2,result,why)
      end)
    end)
    return true
  end
  function s:read(ctx,name,done,expected_sha)
    if expected_sha~=nil and not Sync.hex_ok(expected_sha,40)then return nil,'invalid_revision'end
    return operation(ctx,name,done,false,nil,nil,expected_sha)
  end
  function s:read_revision(ctx,name,commit,done)
    if not Sync.hex_ok(commit,40)then return nil,'invalid_revision'end
    return operation(ctx,name,done,false,nil,nil,nil,nil,commit)
  end
  function s:history(ctx,name,page,anchor,done)
    if not Sync.name_ok(name)or not int(page,1,Payload.HISTORY_MAX_PAGES)
      or (anchor~=nil and not Sync.hex_ok(anchor,40))or (page>1 and anchor==nil)
      or type(done)~='function'then return nil,'invalid_history_request'end
    if busy then return nil,'busy'end
    if not verified or not valid_token(ctx)then return nil,'authorization_required'end
    busy=true;state='verifying';reason=nil
    validate_access(ctx,function(c,ok,why,head)
      if not ok then failure(why,c);done(c,nil,why);return end
      local ref=anchor or head
      state='history'
      get(c,prefix..'/commits?path='..encode('documents/'..name)..'&sha='..ref
        ..'&per_page='..Payload.HISTORY_PAGE_SIZE..'&page='..page,function(c2,res)
        busy=false
        if not valid_token(c2)then done(c2,nil,'session_expired');return end
        local rows,err
        if res.err or res.status~=200 then err=response_error(res)
        else rows,err=Payload.history(res.data)end
        if err=='authorization_required'then failure(err,c2)else state=rows and 'connected'or 'error';reason=err end
        done(c2,rows and {rows=rows,page=page,anchor=ref,
          more=#rows==Payload.HISTORY_PAGE_SIZE and page<Payload.HISTORY_MAX_PAGES,
          limited=#rows==Payload.HISTORY_PAGE_SIZE and page==Payload.HISTORY_MAX_PAGES}or nil,err)
      end)
    end)
    return true
  end
  function s:write(ctx,name,bytes,sha,done,before_write)
    if before_write~=nil and type(before_write)~='function'then return nil,'invalid_guard'end
    return operation(ctx,name,done,true,bytes,sha,nil,before_write)
  end
  function s:list(ctx,done)
    if type(done)~='function'then return nil,'invalid_callback'end
    if busy then return nil,'busy'end
    if not verified or not valid_token(ctx)then return nil,'authorization_required'end
    busy=true;state='verifying';reason=nil
    local function finish(c,rows,why)
      busy=false
      if not valid_token(c)then done(c,nil,'session_expired');return end
      if why=='authorization_required'then failure(why,c)else state=rows and 'connected'or 'error';reason=why end
      done(c,rows,why)
    end
    validate_access(ctx,function(c,ok,why)
      if not ok then failure(why,c);done(c,nil,why);return end
      get(c,prefix..'/git/trees/'..encode(scope.branch),function(c2,res)
        if res.err or res.status~=200 then finish(c2,nil,response_error(res));return end
        local tree,err=Payload.tree(res.data,128);if not tree then finish(c2,nil,err);return end
        local folder
        for _,entry in ipairs(tree)do
          if entry.path=='documents'then
            if folder or entry.type~='tree'or entry.mode~='040000'or not Sync.hex_ok(entry.sha,40)then finish(c2,nil,'invalid_documents_folder');return end
            folder=entry.sha
          end
        end
        if not folder then finish(c2,{});return end
        get(c2,prefix..'/git/trees/'..folder,function(c3,r3)
          if r3.err or r3.status~=200 then finish(c3,nil,response_error(r3));return end
          if type(r3.data)~='table'or r3.data.sha~=folder then finish(c3,nil,'invalid_tree');return end
          local rows,e=Payload.directory(r3.data);finish(c3,rows,e)
        end)
      end)
    end)
    return true
  end
  return s
end
function M.setup(public,primitives)
  if type(public)~='table'or not login_ok(public.login)then return nil,'setup_required'end
  return M.new({client_id=public.client_id,app_id=public.app_id,login=public.login,
    scope={repo=public.login..'/pending-setup',branch='main'},selectable=true},primitives,true)
end
return M
