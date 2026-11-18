local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local Auth=require('domain.sync_auth')
local Setup=require('domain.sync_setup')
local UI=require('domain.sync_ui')
local Store=require('domain.sync_metadata')
local Credentials=require('domain.sync_credentials')
local Auto=require('domain.sync_auto')
local Native=require('test_native')
local n=0;local function check(v,msg)n=n+1;assert(v,msg)end
local primitives={hash=Mock.hash,codec=Mock.codec}
local function host()
 local h=Host.new();local sd=Mock.host();h.ctx.storage=sd.ctx.storage
 h.ctx.invalidate=function()end;return h,sd
end
local function begin(h)
 local a=assert(Auth.setup({client_id='Iv1.TESTONLY',app_id=42,login='example'},primitives))
 a:start(h.ctx);h:respond(Host.code());h.time=5000;a:poll(h.ctx);h:respond(Host.token())
 h:respond(Host.user());return a
end
local function selected_install(h)
 local v=Host.installation();v.total_count=2;v.installations[2]={app_id=999};h:respond(v)
end
local function complete(h,a)
 local repos;assert(a:setup_repos(h.ctx,1,function(_,v)repos=v end));h:respond(Host.repositories())
 local branches;assert(a:setup_branches(h.ctx,repos.rows[1],1,function(_,v)branches=v end));h:respond({Host.branch()})
 local config;assert(a:bind_setup(h.ctx,branches.rows[1],function(_,v)config=v end))
 h:respond(Host.user());selected_install(h);h:respond(Host.repositories());h:respond(Host.repository());h:respond(Host.branch())
 return assert(config)
end
local h,sd=host();h.ctx.state.github_sync_remember=true;sd.files['github-connection.json']='old grant'
local a=begin(h);selected_install(h)
check(a:status(h.ctx).setup_ready and not a:status(h.ctx).connected,'discovery verifies account without allowing document transfers')
check(sd.files['github-connection.json']=='old grant','discovery does not overwrite existing grant')
check(a:read(h.ctx,'test.md',function()end)==nil,'document read forbidden before destination is bound')
local c=complete(h,a)
check(c.scope.repo=='example/docs'and c.scope.branch=='main'and c.repository_id==77 and c.selectable,'bind returns verified public scope')
check(a:status(h.ctx).connected and sd.files['github-connection.json']=='old grant','binding does not save candidate grant over old connection')
c.profile=1;h.ctx.state.github_sync_remember=false;check(a:activate_setup(h.ctx,c),'activate selected profile')
h.ctx.state.github_sync_remember=true;check(a:remember(h.ctx),'explicit remember saves verified candidate')
check(sd.files['gh1-github-connection.json']and sd.files['github-connection.json']=='old grant','new credentials stay in their profile')
local b=assert(Auth.new(c,primitives));check(b:restore(h.ctx),'profile grant restores')
h:respond(Host.user());selected_install(h);h:respond(Host.repositories());h:respond(Host.repository());h:respond(Host.branch())
check(b:status(h.ctx).connected,'saved selectable connection verifies again on restore')
-- Wrong accounts and installations fail without deleting the current grant.
for _,kind in ipairs({'account','missing','all','permissions','suspended','many'})do
 h,sd=host();h.ctx.state.github_sync_remember=true;sd.files['github-connection.json']='old grant'
 a=assert(Auth.setup({client_id='Iv1.TESTONLY',app_id=42,login='example'},primitives))
 a:start(h.ctx);h:respond(Host.code());h.time=5000;a:poll(h.ctx);h:respond(Host.token())
 if kind=='account'then h:respond({login='other',id=13})else
  h:respond(Host.user());local v=Host.installation()
  if kind=='missing'then v={total_count=0,installations={}}
  elseif kind=='all'then v.installations[1].repository_selection='all'
  elseif kind=='permissions'then v.installations[1].permissions.issues='write'
  elseif kind=='suspended'then v.installations[1].suspended_at='date'
  elseif kind=='many'then v.total_count=21 end
  h:respond(v)
 end
 check(not a:status(h.ctx).connected and not a:status(h.ctx).setup_ready and a:status(h.ctx).reason,'reject invalid setup '..kind)
 check(sd.files['github-connection.json']=='old grant','failed setup preserves old grant '..kind)
end
-- Repository/branch candidates cannot be forged or retained after another page.
h,sd=host();a=begin(h);selected_install(h)
local page;assert(a:setup_repos(h.ctx,1,function(_,v)page=v end))
local repos=Host.repositories();repos.total_count=12
repos.repositories[2]={id=78,full_name='example/public',private=false,permissions={push=true}}
repos.repositories[3]={id=79,full_name='someone/docs',private=true,permissions={push=true}}
h:respond(repos)
check(#page.rows==1 and page.more,'only owned private writable repositories appear')
check(not a:setup_branches(h.ctx,{id=77,full_name='example/docs'},1,function()end),'forged repository rejected')
local old=page.rows[1];a:setup_repos(h.ctx,2,function(_,v)page=v end);h:respond({total_count=12,repositories={}})
check(not a:setup_branches(h.ctx,old,1,function()end),'stale candidate rejected after pagination')
a:setup_repos(h.ctx,1,function(_,v)page=v end);h:respond(Host.repositories())
local br;a:setup_branches(h.ctx,page.rows[1],1,function(_,v)br=v end);h:respond({Host.branch()})
check(not a:bind_setup(h.ctx,{name='main'},function()end),'forged branch rejected')
-- Failure during final bind must not remove the old profile's credentials.
sd.files['github-connection.json']='old';h.ctx.state.github_sync_remember=true
a:bind_setup(h.ctx,br.rows[1],function()end);h:respond({login='other',id=13})
check(sd.files['github-connection.json']=='old','failed final verification preserves old grant')
-- Bounded profile switching keeps checkpoint/queue files untouched.
h,sd=host();local manager=Setup.new(h.ctx,{primitives=primitives})
check(not manager.config and #manager.profiles==0 and not h.ctx.state.github_sync_enabled,'fresh install has no owner destination')
c=Host.config();c.selectable=true
local first=assert(manager:save(c));check(first.profile==1 and h.ctx.state.github_sync_auto==false,'first setup gets isolated slot and auto Off')
local raw=sd.files[Setup.FILE];check(not raw:find('ghu_',1,true)and not raw:find('ghr_',1,true),'setup contains public values only')
sd.files['gh1-github-sync.json']='checkpoint';sd.files['gh1-github-auto-queue.json']='pending'
c.scope.branch='drafts';local second=assert(manager:save(c));check(second.profile==2,'new branch gets separate slot')
check(sd.files['gh1-github-sync.json']=='checkpoint'and sd.files['gh1-github-auto-queue.json']=='pending','switch preserves old records and pending queue')
local back=assert(manager:save(first,1));check(back.profile==1 and #manager.profiles==2,'switching back reuses saved scope')
local restart=Setup.new(h.ctx,{primitives=primitives});check(restart.config.profile==1,'setup survives reopening')
h.ctx.state.github_sync_auto=true;h.ctx.state.github_sync_remember=true;h.ctx.state.github_setup_revision=0
restart=Setup.new(h.ctx,{primitives=primitives});check(not h.ctx.state.github_sync_auto and not h.ctx.state.github_sync_remember and not h.ctx.state.github_sync_enabled,'crash between setup commit and state save fails closed')
for i=3,4 do c.scope.branch='branch'..i;assert(manager:save(c))end
c.scope.branch='overflow';local v,e=manager:save(c);check(not v and e:find('Four',1,true),'profile count bounded')
-- Missing/changed/corrupt SD state never silently chooses the owner.
h,sd=host();sd.files[Setup.FILE]='broken';manager=Setup.new(h.ctx,{primitives=primitives})
check(manager.error and not manager.config,'corrupt setup fails closed')
h,sd=host();manager=Setup.new(h.ctx,{primitives=primitives});sd.fail_write=true
check(not manager:save(Host.config())and manager.error,'write failure blocks connection until reopen')
h,sd=host();manager=Setup.new(h.ctx,{primitives=primitives});sd.fail_after_commit=true
check(not manager:save(Host.config())and manager.error,'ambiguous write remains blocked')
sd.fail_after_commit=false;restart=Setup.new(h.ctx,{primitives=primitives})
check(restart.config and not h.ctx.state.github_sync_enabled,'complete committed setup recovered safely after ambiguous write')
h,sd=host();h.ctx.state.github_sync_enabled=true;manager=Setup.new(h.ctx,{primitives=primitives})
check(manager.config and manager.config.login=='odklizec'and not manager.config.profile,'existing owner configuration migrates without moving files')
-- Actual stores isolate records and queues even for the same document name.
h,sd=host();c=Host.config();c.profile=1
local scoped=Store.for_config(c);local empty,revision=scoped.load(h.ctx,c.scope,Mock.hash)
local record={remote_path='documents/test.md',remote_blob_sha=string.rep('a',40),last_synced_local_fingerprint=Mock.hash('one')}
assert(scoped.save(h.ctx,assert(Store.checkpoint(empty,'test.md',record,c.scope)),c.scope,Mock.hash,revision))
c.profile=2;local other=Store.for_config(c);local clean=other.load(h.ctx,c.scope,Mock.hash)
check(not clean.documents['test.md']and sd.files['gh1-github-sync.json']and not sd.files[Store.FILE],'metadata profile isolation')
h.ctx.state.github_sync_enabled=true;h.ctx.state.github_sync_auto=true
local q=Auto.new({cancel_auto=function()end},{},{config=c,primitives=primitives});q:saved(h.ctx,'test.md','two');assert(q:flush(h.ctx))
check(sd.files['gh2-github-auto-queue.json']and not sd.files[Auto.FILE],'automatic queue profile isolation')
-- Fresh-user setup UI starts safely; canceling sign-in sends no document request.
h,sd=host();manager=Setup.new(h.ctx,{primitives=primitives})
h.ctx.screen={width=480,height=800};h.ctx.input={};local font={line_height=24,measure=function(_,v)return #v*10 end}
local ui=UI.new({},font,font,{setup=manager,primitives=primitives});ui:open(h.ctx)
check(ui.setup.active and ui.setup.fields.client_id==''and h.calls==0,'fresh setup presents empty public fields without network')
local drawing=false;local labels={};local g={clear=function()end,text=function(_,_,_,t)labels[t]=true end,text_box=function(_,_,_,_,_,t)labels[t]=true end,rect=function()end,line=function()end}
ui:draw(h.ctx,g);check(labels['Sign in and choose repository']and not labels['odklizec/inkwrite-docs / main'],'fresh setup does not advertise owner repo')
ui:input(h.ctx,{type='key',key='back',phase='up'});check(not ui.active,'Back exits fresh setup')
-- Whole UI flow uses actual Auth and Session, no token crosses the view boundary.
h,sd=host();manager=Setup.new(h.ctx,{primitives=primitives});h.ctx.screen={width=480,height=800};h.ctx.input={}
ui=UI.new({},font,font,{setup=manager,primitives=primitives});ui:open(h.ctx)
local function press(index)
 ui.focus=index;ui:input(h.ctx,{type='key',key='ok',phase='down'})
end
h.ctx.input.text=function(_,options,done)done(h.ctx,options.title:find('Client',1,true)and 'Iv1.TESTONLY'or options.title:find('numeric',1,true)and '42'or 'example')end
press(1);press(2);press(3)
check(ui.setup.fields.login=='example'and ui.setup.fields.app_id=='42','public setup fields work through system text input')
press(4);h:respond(Host.code());ui:tick(h.ctx)
labels={};ui:draw(h.ctx,g);check(labels['Sign-in code: ABCD-EFGH\nApprove the App in your browser.'],'setup shows device code')
ui:pause(h.ctx);ui:resume(h.ctx);h.time=5000;ui:tick(h.ctx);h:respond(Host.token());h:respond(Host.user());selected_install(h)
ui:tick(h.ctx);h:respond(Host.repositories());ui:tick(h.ctx)
check(ui.setup.page=='setup_repos','successful account check opens repository picker')
press(1);h:respond({Host.branch()});ui:tick(h.ctx)
check(ui.setup.page=='setup_branches','repository selection opens branch picker')
press(1);h:respond(Host.user());selected_install(h);h:respond(Host.repositories());h:respond(Host.repository());h:respond(Host.branch());ui:tick(h.ctx)
check(ui.setup.page=='setup_confirm'and not sd.files[Setup.FILE],'verified destination requires explicit Save')
press(2);check(not ui.setup.active and manager.config.profile==1 and ui.session:status(h.ctx).connected,'Save switches actual runtime to verified candidate without another approval')
check(not h.ctx.state.github_sync_auto and not h.ctx.state.github_sync_remember and not sd.files['gh1-github-connection.json'],'setup does not silently enable uploads or save credentials')
press(6);press(2)
check(h.ctx.state.github_sync_remember and sd.files['gh1-github-connection.json'],'Remember after setup saves candidate in correct profile')
-- Setup drawing remains passive across device sizes and never needs top Back.
for _,dims in ipairs({{480,800},{800,480}})do
 h.ctx.screen.width=dims[1];h.ctx.screen.height=dims[2]
 ui.setup:open();ui:tick(h.ctx);local calls=h.calls;local writes=sd.writes
 labels={};ui:draw(h.ctx,g)
 check(h.calls==calls and sd.writes==writes and labels['Back'],'setup draw has universal Back and no network or storage work')
end
return n
