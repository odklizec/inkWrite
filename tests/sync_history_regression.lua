local function run()
local Auth=require('domain.sync_auth')
local UI=require('domain.sync_ui')
local Payload=require('domain.github_payload')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local F=require('tests.fixtures.github_contents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function commits(count,offset)
 local rows={}
 for i=1,count do rows[i]={sha=string.format('%040x',i+(offset or 0)),commit={message='Saved version '..i..'\nprivate second line',committer={date='2026-11-16T09:30:00Z'}}}end
 return rows
end
local function setup()
 local h=Host.new();local c=h.ctx;local private=Mock.host();c.storage=private.ctx.storage
 c.state.github_sync_enabled=true;c.invalidate=function()end;c.screen={width=480,height=800}
 h.files={['ideas.md']='current buffer', ['restore-001.md']='existing restore'}
 c.files={size=function(_,name)local v=h.files[name:lower()];return v and #v or nil,v and nil or 'not_found'end,
 read=function(_,name,a,b)local v=h.files[name:lower()];return v and v:sub(a+1,a+b)or nil,v and nil or 'not_found'end,
 write=function(_,name,v)if h.fail_sd then return nil,'io_error'end;h.files[name:lower()]=v;return true end}
 local auth
 local hooks={describe=function()return {name='ideas.md',dirty=true}end,reserved_name=function()return 'ideas.md'end,can_import=function()return not h.protected end}
 local font={line_height=24}
 local u=UI.new(hooks,font,font,{config=Host.config(),primitives={hash=Mock.hash,codec=Mock.codec},auth_factory=function(config,p)auth=assert(Auth.new(config,p));return auth end})
 local s=u.session;s:connect(c);h:respond(Host.code());h.time=5000;s:poll(c);h:respond(Host.token());h:verify(auth)
 h.private=private;h.auth=auth;h.u=u;h.s=s
 function h:history(rows,page,anchor)
  self.s:history_page(c,'ideas.md',page or 1,anchor);self:verify(auth);self:respond(rows)
 end
 function h:key(code)u:input(c,{type='key',code=code,phase='down'})end
 return h
end
local rows=assert(Payload.history(commits(5)))
check(#rows==5 and rows[1].date=='2026-11-16'and rows[1].summary=='Saved version 1','history boundary retains only short display fields')
for _,v in ipairs({commits(6),{[2]=commits(1)[1]},{foo=commits(1)[1]},{commits(1)[1],commits(1)[1]},{{sha='branch',commit={}}}})do
 check(Payload.history(v)==nil,'oversized/sparse/object/duplicate/invalid revisions rejected')
end
local long=commits(1);long[1].commit.message=string.rep('x',200)..'\nsecret'
check(#assert(Payload.history(long))[1].summary==64,'display summaries are capped')
for _,bad in ipairs({'\255',string.rep('x',8193)})do local v=commits(1);v[1].commit.message=bad;check(Payload.history(v)==nil,'malformed/oversized commit message rejected')end
local h=setup();local c,s=h.ctx,h.s;local got,err
local calls=h.calls
for _,args in ipairs({{'../outside.md',1},{'ideas.md',0},{'ideas.md',21},{'ideas.md',2},{'ideas.md',1,'main'}})do
 check(h.auth:history(c,args[1],args[2],args[3],function()end)==nil and h.calls==calls,'invalid history request refused before network')
end
check(h.auth:read_revision(c,'ideas.md','main',function()end)==nil and h.calls==calls,'historical reads require full immutable commit SHA')
s:history_page(c,'ideas.md',1);h:verify(h.auth)
check(h.options.url=='https://api.github.com/repos/example/docs/commits?path=documents%2Fideas.md&sha='..Host.branch().commit.sha..'&per_page=5&page=1','first history page pinned to verified branch head and scoped path')
h:respond(commits(5));check(#s.history.rows==5 and s.history.more and s.history.page==1 and not s.busy,'one bounded page retained')
local anchor=s.history.anchor;s:history_page(c,'ideas.md',2,anchor);h:verify(h.auth,{[5]=function(v)v.commit.sha=F.OLD end})
check(h.options.url:find('sha='..anchor..'&per_page=5&page=2',1,true),'next page remains pinned despite new branch commits')
h:respond(commits(1,5));check(s.history.page==2 and #s.history.rows==1 and not s.history.more,'last page replaces previous rows')
s:history_page(c,'ideas.md',20,anchor);h:verify(h.auth);h:respond(commits(5,95))
check(s.history.limited and not s.history.more and s.notice:find('100 versions',1,true),'hard browsing limit is explicit')
h:history({});check(#s.history.rows==0 and not s.history.more,'empty history handled')
h:history(commits(1));local row=s.history.rows[1]
c.storage:write('recovery.txt','UNRELATED RECOVERY');c.storage:write('github-sync.json','unchanged checkpoint')
local text='Historical bytes\r\n\r\n';s:restore_revision(c,row);h:verify(h.auth)
check(h.options.method=='GET'and h.options.url:find('?ref='..row.sha,1,true),'restore fetches selected commit, never current branch')
local replay=h:respond(F.file('ideas.md',text,F.OLD))
check(h.files['restore-002.md']==text and h.files['ideas.md']=='current buffer'and h.files['restore-001.md']=='existing restore','restore allocates new copy and preserves active/existing files and exact CRLF bytes')
check(c.storage:read('recovery.txt')=='UNRELATED RECOVERY'and c.storage:read('github-sync.json')=='unchanged checkpoint','historical restore leaves recovery and current sync metadata untouched')
check(s.notice=='Restored as local copy: restore-002.md'and not s.busy,'successful verified import is reported')
local before=h.calls;s:restore_revision(c,{sha=row.sha});check(h.calls==before,'unselected injected revision cannot start restore')
h.protected=true;s:restore_revision(c,row);check(h.calls==before,'blocked editor prevents restore before network');h.protected=false
for _,status in ipairs({404,403,429,502})do
 local b=setup();b:history(commits(1));b.s:restore_revision(b.ctx,b.s.history.rows[1]);b:verify(b.auth);b:respond({},status)
 check(not b.s.busy and b.files['restore-002.md']==nil,'missing/forbidden/rate/server response never creates local copy')
end
for _,patch in ipairs({function(v)v.size=32769 end,function(v)v.path='documents/other.md'end,function(v)v.content='/w==';v.size=1 end})do
 s:restore_revision(c,row);h:verify(h.auth);local v=F.file('ideas.md','valid',F.OLD);patch(v);h:respond(v)
 check(not s.busy and h.files['restore-003.md']==nil,'oversized/wrong-path/invalid UTF8 historical content rejected')
end
h.fail_sd=true;s:restore_revision(c,row);h:verify(h.auth);h:respond(F.file('ideas.md','old',F.OLD))
check(not s.busy and h.files['restore-003.md']==nil and h.files['ideas.md']=='current buffer','SD failure leaves original untouched');h.fail_sd=false
s:restore_revision(c,row);h:verify(h.auth);h.protected=true;h:respond(F.file('ideas.md','old',F.OLD));check(h.files['restore-003.md']==nil,'editor protection rechecked after async read');h.protected=false
s:restore_revision(c,row);local cancelled=h.cancelled;s:pause(c);check(not s.busy and h.cancelled==cancelled+1,'pause cancels history restore while preserving files')
s:close(c);replay();check(s.history==nil and h.files['restore-003.md']==nil,'close drops history and late callbacks cannot restore twice')
-- Maximum document size and accented UTF-8 remain byte-exact.
local big=setup();big:history(commits(1));local bytes=string.char(0xc4,0x8d)..'aj\r\n'..string.rep('x',32762)
check(#bytes==32768,'32 KiB fixture boundary')
big.s:restore_revision(big.ctx,big.s.history.rows[1]);big:verify(big.auth);big:respond(F.file('ideas.md',bytes,F.OLD))
check(big.files['restore-002.md']==bytes and big.files['ideas.md']=='current buffer','32 KiB accented historical document restored byte-exact')
local bad=setup();bad.s:history_page(bad.ctx,'ideas.md',1);bad:verify(bad.auth,{[1]=function(v)v.login='other'end})
check(not bad.s.busy and not bad.s.history and not bad.auth:status(bad.ctx).connected,'history revalidates account before any commit request')
-- Actual UI + auth integration: entry from current doc, explicit confirm, footer/back.
h=setup();c,s=h.ctx,h.s;local u=h.u;u:open(c);u.focus=3;h:key('Enter');h:verify(h.auth);h:respond(commits(5));u:tick(c)
check(u.page=='history'and s.history.name=='ideas.md','main history opens current document even with unsaved edits, without saving it')
u.focus=3;h:key('Enter');check(u.page=='version'and u.focus==1,'version selection defaults to Cancel')
local before=h.calls;h:key('Enter');check(u.page=='history'and h.calls==before,'Cancel version issues no read or write')
u.focus=3;h:key('Enter');u.focus=2;h:key('Enter');h:verify(h.auth);h:respond(F.file('ideas.md','restored',F.OLD));u:tick(c)
check(u.page=='history'and h.files['restore-002.md']=='restored','explicit UI restore creates a new copy')
local labels={};local g=setmetatable({text_box=function(_,x,y,w,ht,t)labels[t]=true end},{__index=function()return function()end end});u:draw(c,g)
check(labels['Restored as local copy: restore-002.md'],'restore result stays visible on history page')
h:key('Escape');check(u.page=='main','history Back returns to original sync page')
-- Page failures retain the previous successful list and visible error, no retries.
u.focus=3;h:key('Enter');h:verify(h.auth);h:respond(commits(5));u:tick(c);u.focus=2;h:key('Enter');h:verify(h.auth);h:respond({},429);u:tick(c)
check(s.history.page==1 and not s.busy and s.notice:find('did not finish',1,true),'failed page retains prior page for manual retry')
return n

end
local ok,result=xpcall(run,debug.traceback);assert(ok,result);return result
