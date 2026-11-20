local Host=require('tests.support.writer_host')
local Workspace=require('domain.workspace')
local Native=require('test_native')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local chord={ctrl=true,shift=true}
local function direction(h)return Workspace.effective_direction(h:state().workspace,h.ctx.screen)end
local function cycle(h)h:key('KeyS',nil,chord);h:draw()end
local function rotate(h)
  -- The host publishes the new dimensions only after the callback returns.
  local target
  h.ctx.screen.set_orientation=function(_,value)target=value;return true end
  local previous=direction(h)
  h:key('KeyR',nil,chord)
  check(direction(h)==previous,'async rotation keeps current geometry until dimensions arrive')
  check(target=='portrait'or target=='landscape','rotation requests a valid orientation')
  check(h:state().prepare_timer~=nil,'rotation schedules preparation before the next drawing callback')
  h.ctx.screen.width,h.ctx.screen.height=h.ctx.screen.height,h.ctx.screen.width
  h.ctx.screen.orientation=target
  h:advance(1);h:draw()
  check(h:state().prepare_timer==nil,'new dimensions are prepared without requiring another input or drawing callback')
end
local function same_state(v)return Native.decode(Native.encode(v))end
-- Auto is the marked default and the first setting after Back to writing.
local menu=Host.new();menu:key('KeyP',nil,chord);menu:draw()
local back,auto,horizontal
for _,entries in ipairs({menu.texts,menu.boxes})do for _,row in ipairs(entries)do
  if row.text=='Back to writing'then back=row
  elseif row.text:find('Auto: follow screen',1,true)==1 then auto=row
  elseif row.text:find('Horizontal: top / bottom',1,true)==1 then horizontal=row end
end end
check(back and auto and horizontal and back.y<auto.y and auto.y<horizontal.y,'Auto is directly below Back and above fixed directions')
check(auto.text=='Auto: follow screen *','new workspace marks Auto as the default')
menu:key('ArrowDown');menu:key('Enter')
check(menu:state().workspace.split and menu:state().workspace.direction_auto,'second menu row enables Auto')
-- Defaults use actual dimensions, including a landscape launch with no saved state.
for _,size in ipairs({{480,800,'horizontal'},{800,480,'vertical'}})do
  for _,focus in ipairs({false,true})do
    local h=Host.new({width=size[1],height=size[2],state={last='alpha.md',focus_mode=focus}})
    h.ctx.screen.orientation=size[1]>size[2]and 'landscape'or 'portrait'
    local a=h:state()
    check(a.workspace.direction_auto and direction(h)==size[3],'new workspace follows screen dimensions')
    cycle(h);h:switch();h:open('bravo.md');h:edit(' B edit')
    local b=a.editor;local first=a.workspace.sessions[1];local textA=first.buffer:text();local textB=b.buffer:text()
    b.anchor=0;local pos=b.buffer.pos;cycle(h);local writes=h.public_writes
    check(a.workspace.ratio=='2:1'and a.workspace.direction_auto,'ratio cycle keeps automatic direction')
    for i=1,2 do
      rotate(h)
      check(direction(h)==(h.ctx.screen.width>h.ctx.screen.height and 'vertical'or 'horizontal'),'automatic split follows rotation in both directions')
      check(a.workspace.ratio=='2:1'and a.focus_mode==focus and a.workspace.active==2,'rotation keeps ratio, mode and active pane')
      check(a.editor==b and a.workspace.sessions[1]==first and b.buffer.pos==pos and b.anchor==0,'rotation keeps sessions and selection')
      check(first.buffer:text()==textA and b.buffer:text()==textB and h.public_writes==writes,'rotation does not save or change either buffer')
      local pa=first.prepared;local pb=b.prepared
      check(pa and pb and pa.key~=pb.key and a.editor.touch_geometry==pb.key,'both pane frames and active hit testing are prepared after rotation')
    end
    h:key('KeyZ',nil,{ctrl=true});check(b.buffer:text()=='Bravo original.\r\n','undo survives automatic rotation')
  end
end
-- A menu choice, even the same direction as Auto, becomes a persistent override.
for _,choice in ipairs({3,4})do
  local h=Host.new();cycle(h);h:split(choice);local a=h:state()
  local fixed=choice==3 and 'horizontal'or 'vertical'
  check(not a.workspace.direction_auto and direction(h)==fixed,'explicit direction disables Auto')
  rotate(h);rotate(h)
  check(direction(h)==fixed and not a.workspace.direction_auto,'explicit direction survives both rotations')
  local saved=same_state(h.ctx.state)
  local restored=Host.new({state=saved,files=h.files,private=h.private})
  check(not restored:state().workspace.direction_auto and direction(restored)==fixed,'manual choice survives reopen')
  restored:split(2)
  check(restored:state().workspace.direction_auto and direction(restored)=='horizontal','Auto menu option releases the override immediately')
  rotate(restored);check(direction(restored)=='vertical','Auto resumes following subsequent rotations')
end
-- Auto persists across hiding/reopening split and reopening the app.
local h=Host.new();cycle(h);h:split(9);local saved=same_state(h.ctx.state)
check(saved.inkwrite_workspace.direction_auto==true,'Auto preference is persisted explicitly')
local restored=Host.new({width=800,height=480,state=saved,files=h.files,private=h.private})
check(not restored:state().workspace.split and direction(restored)=='vertical','hidden split derives direction from new screen on reopen')
cycle(restored);check(direction(restored)=='vertical'and restored:state().workspace.split,'shortcut reopens hidden split using current screen')
-- Older preferences without a mode flag now use the default Auto policy.
saved.inkwrite_workspace.direction_auto=nil;saved.inkwrite_workspace.direction='horizontal'
restored=Host.new({width=800,height=480,state=saved,files=h.files,private=h.private})
check(restored:state().workspace.direction_auto and direction(restored)=='vertical','legacy settings default to Auto')
-- Invalid mode flags protect the original settings and files.
saved.inkwrite_workspace.direction_auto='yes'
restored=Host.new({state=saved,files=h.files,private=h.private})
check(restored:state().blocked and saved.inkwrite_workspace.direction_auto=='yes'and restored.public_writes==0,'malformed Auto preference is protected')
-- Choosing Auto must use the same recovery guard as other split settings.
h=Host.new();h:edit(' protected');h.fail_private='recovery-a.txt';h:split(2)
check(not h:state().workspace.split and h:state().editor.dirty,'failed Auto enable preserves single document')
return n
