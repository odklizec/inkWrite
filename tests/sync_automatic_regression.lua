local Auto=require('domain.sync_auto')
local Session=require('domain.sync_session')
local Auth=require('domain.sync_auth')
local Store=require('domain.sync_metadata')
local Host=require('tests.support.auth_host')
local Mock=require('tests.support.sync_mock')
local F=require('tests.fixtures.github_contents')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function setup(connect)
 local h=Host.new();local c=h.ctx;h.private=Mock.host();c.storage=h.private.ctx.storage;c.invalidate=function()end
 c.state={github_sync_enabled=true,github_sync_auto=true};h.files={};h.public_writes=0
 c.files={size=function(_,name)local b=h.files[name];return b and #b or nil,b and nil or 'not_found'end,
  read=function(_,name,a,z)local b=h.files[name];return b and b:sub(a+1,a+z)or nil,b and nil or 'not_found'end,
  write=function(_,name,b)h.public_writes=h.public_writes+1;h.files[name]=b;return true end}
 local deps={config=Host.config(),primitives={hash=Mock.hash,codec=Mock.codec},auth_factory=function(config,p)h.auth=assert(Auth.new(config,p));return h.auth end}
 local hooks={describe=function()return {name='open.md',dirty=h.dirty,blocked=h.blocked}end}
 h.s=Session.new(hooks,deps);h.q=Auto.new(h.s,hooks,deps);h.q:load(c)
 if connect~=false then h.s:connect(c);h:respond(Host.code());h.time=5000;h.s:poll(c);h:respond(Host.token());h:verify(h.auth)end
 h.hooks=hooks;h.deps=deps
 function h:save(name,bytes)self.files[name]=bytes;self.q:saved(c,name,bytes)end
 function h:advance(ms)self.time=self.time+ms;self.q:tick(c)end
 function h:read(remote,status)self:verify(self.auth);self:respond(remote,status)end
 function h:write(name)self:verify(self.auth);assert(self.options.method=='PUT');self:respond(F.written('documents/'..name),201)end
 return h
end
local h=setup();local c=h.ctx;local initial=h.calls
h:save('ideas.md','first saved bytes');h:advance(29000)
check(h.calls==initial and not h.s.busy,'no network before configured 30 second delay')
h:advance(1000);check(h.s.busy and h.q.items[1].attempts==1,'one upload starts after delay while idle')
h:read({},404);h:write('ideas.md');h:advance(1000)
check(#h.q.items==0 and h.public_writes==0,'successful upload removes queue without changing public documents')
local m=assert(Store.load(c,Host.config().scope,Mock.hash));check(m.documents['ideas.md'].last_synced_local_fingerprint==Mock.hash('first saved bytes'),'only verified upload checkpoints exact saved fingerprint')
h:save('ideas.md','first saved bytes');h:advance(30000);local count=h.calls;h:read(F.file('ideas.md','first saved bytes',F.NEW))
check(h.calls==count+5 and #h.q.items==0,'equal remote bytes never create a duplicate PUT')
-- Lost response after GitHub committed: re-fetch before retry prevents another commit.
h=setup();h:save('ideas.md','saved');h:advance(30000);h:read({},404);h:verify(h.auth);h:respond('',200,{ok=false,err='timeout'})
check(h.q.items[1].attempts==1 and not h.q.items[1].held,'transient upload failure is retained')
h:advance(29999);check(not h.s.busy,'retry honors backoff');h:advance(1);count=h.calls;h:read(F.file('ideas.md','saved',F.NEW))
check(#h.q.items==0 and h.calls==count+5,'unknown write outcome checks equality and does not duplicate commit')
-- Both sides changed / remote-only changes are held, never downloaded or overwritten.
for _,remote in ipairs({F.file('ideas.md','other',F.OLD),F.file('ideas.md','other',F.NEW)})do
 h=setup();h:save('ideas.md','saved');h:advance(30000);h:read(remote)
 check(h.q.items[1].held and h.q.items[1].reason=='conflict'and h.files['ideas.md']=='saved'and h.public_writes==0,'remote conflict holds for manual review')
 local calls=h.calls;h:save('ideas.md','new edit');h:advance(3600000);check(h.calls==calls and h.q.items[1].held,'new autosaves cannot silently retry unresolved conflict')
end
h=setup();h:save('ideas.md','one');h:save('ideas.md','two');h:advance(30000)
check(#h.q.items==1 and h.q.items[1].fingerprint==Mock.hash('two'),'multiple saves coalesce to newest fingerprint without retaining bytes')
local writes=h.private.writes;h.q:interrupt(h.ctx)
check(not h.s.busy and h.private.writes==writes,'typing cancels in-flight request without writing queue during input')
h:advance(30000);h:read({},404);h:write('ideas.md');check(#h.q.items==0,'cancelled request can retry conservatively')
h=setup();h:save('ideas.md','saved');h.dirty=true;h:advance(30000);check(not h.s.busy,'unsaved typing blocks uploads');h.dirty=false
h.q:interrupt(h.ctx);h:advance(9999);check(not h.s.busy,'ten-second typing quiet window enforced');h:advance(1);check(h.s.busy,'idle upload resumes after quiet window');h.q:pause(h.ctx)
check(not h.s.busy and h.private.files[Auto.FILE]and h.q.paused,'pause cancels and durably preserves bounded queue')
h:advance(3600000);check(not h.s.busy,'paused app never sends requests');h.q:resume(h.ctx)
-- Never upload changed external bytes, missing files or corrupt metadata.
h=setup();h:save('ideas.md','saved');h.files['ideas.md']='external';count=h.calls;h:advance(30000)
check(h.calls==count and h.q.items[1].held and h.q.items[1].reason=='saved_file_changed','external SD edits cannot become automatically authorized upload bytes')
h=setup();h:save('ideas.md','saved');h.private.files[Store.FILE]='bad';count=h.calls;h:advance(30000)
check(h.calls==count and h.q.items[1].held,'unreadable metadata blocks network writes')
-- Queue round-trip retains only names/fingerprints, checks scope/checksum and caps size.
h=setup();h:save('ideas.md','private document body');h.q:flush(h.ctx)
local stored=h.private.files[Auto.FILE];check(not stored:find('private document body',1,true)and not stored:find('ghu_',1,true),'queue stores no document content or credentials')
local q=Auto.new(h.s,h.hooks,h.deps);q:load(h.ctx)
check(#q.items==1 and q.items[1].fingerprint==Mock.hash('private document body'),'pending queue survives a fresh scheduler')
h.private.files[Auto.FILE]=stored..'broken';q=Auto.new(h.s,h.hooks,h.deps);q:load(h.ctx)
check(q.bad and h.private.files[Auto.FILE]==stored..'broken','corrupt queue fails closed without overwriting evidence');q:clear(h.ctx)
check(not q.bad and #q.items==0,'explicit Clear safely resets a corrupt queue')
h=setup();for i=1,17 do h:save('file-'..i..'.md','saved')end
check(#h.q.items==16 and h.q.notice:find('full',1,true),'queue bounded at 16 without silently dropping older documents')
h.private.fail_write=true;h:advance(30000);check(h.q.bad and not h.s.busy,'queue persistence failure prevents sending an unrecorded upload')
-- At most three attempts, retained across restart; no browser sign-in from scheduler.
h=setup();h:save('ideas.md','saved')
for i=1,3 do h:advance(i==3 and 120000 or 30000);h:verify(h.auth);h:respond('',200,{ok=false,err='no_network'})end
check(h.q.items[1].held and h.q.items[1].attempts==3,'three failed attempts stop automatic retries');h.q:flush(h.ctx)
q=Auto.new(h.s,h.hooks,h.deps);q:load(h.ctx);count=h.calls;h.time=h.time+3600000;q:tick(h.ctx)
check(h.calls==count and q.items[1].held,'restart cannot reset retry budget');q:retry(h.ctx);check(not q.items[1].held and q.items[1].attempts==0,'explicit retry resets attempt budget')
h=setup(false);h:save('ideas.md','saved');h:advance(30000)
check(h.calls==0 and h.q.notice:find('Connect',1,true),'session-only disconnected queue never starts browser approval')
h.ctx.state.github_sync_remember=true;h:advance(30000)
check(h.calls==0 and h.q.items[1].held,'missing remembered grant never falls back to device approval')
h=setup();h.ctx.state.github_sync_auto=false;local writes=h.private.writes;h:save('ideas.md','off');h:advance(3600000)
check(#h.q.items==0 and h.private.writes==writes and not h.s.busy,'Off leaves local saving independent without queue work')
-- Saved grants restore/refresh without an interactive approval request.
h=setup();h.ctx.state.github_sync_remember=true;assert(h.auth:remember(h.ctx));h.auth:disconnect()
h:save('ideas.md','saved');h:advance(30000)
check(h.options.url=='https://api.github.com/user','automatic reconnect verifies a saved token, never asks for a device code')
h:verify(h.auth);h:advance(1000);h:read({},404);h:write('ideas.md');check(#h.q.items==0,'saved session continues queued upload after verification')
h=setup();h.ctx.state.github_sync_remember=true;assert(h.auth:remember(h.ctx));h.auth:disconnect();h.epoch=h.epoch+86400
h:save('ideas.md','saved');h:advance(30000)
check(h.options.body:find('grant_type=refresh_token',1,true),'expired saved access renews with the refresh grant')
h:respond(Host.token());h:verify(h.auth);h:advance(1000);h:read({},404);h:write('ideas.md')
check(#h.q.items==0,'refreshed session uploads without browser approval')
h=setup();h:save('ideas.md','saved');h:advance(30000);h:verify(h.auth);h:respond({},429)
h:advance(3599999);check(not h.s.busy,'rate-limited request waits at least an hour');h:advance(1);check(h.s.busy,'rate-limit retry remains bounded and can resume');h.q:pause(h.ctx)
h=setup();for i=1,16 do h:save(i..string.rep(string.char(0xc4,0x8d),60)..'.md','saved')end
check(h.q:flush(h.ctx)and #h.private.files[Auto.FILE]<=Auto.MAX_BYTES,'sixteen long UTF-8 filenames fit the bounded persistent queue')
local other={config={scope={repo='example/other',branch='main'}},primitives=h.deps.primitives};q=Auto.new(h.s,h.hooks,other);q:load(h.ctx)
check(q.bad,'queue from a different repository fails closed')
h=setup();h:save('ideas.md','saved');h.private.files[Auto.FILE]='external queue revision';h:advance(30000)
check(h.q.bad and not h.s.busy and h.private.files[Auto.FILE]=='external queue revision','concurrent queue replacement is preserved without automatic writes')
h=setup();h:save('ideas.md','saved');h.q:flush(h.ctx);h.ctx.state.github_sync_auto=false
q=Auto.new(h.s,h.hooks,h.deps);q:ack(h.ctx,'ideas.md',Mock.hash('saved'));q:flush(h.ctx)
check(#q.items==0 and q.loaded,'manual resolution also clears a previously saved queue while automatic uploads are Off')
return n
