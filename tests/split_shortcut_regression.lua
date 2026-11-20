local Host=require('tests.support.writer_host')
local App=require('domain.app')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local chord={ctrl=true,shift=true}
local function cycle(h,phase)
  App.input(h.ctx,{type='key',source='keyboard',phase=phase or 'down',code='KeyS',mods=chord})
  h:draw()
end
-- A fresh single document enables a split without saving or rotating.
local h=Host.new();local a=h:state();local first=a.editor
h:edit(' unsaved');local text=first.buffer:text();local writes=h.public_writes
cycle(h)
check(a.workspace.split and a.workspace.ratio=='1:1','first chord enables equal panes')
check(a.editor==first and first.buffer:text()==text and first.dirty,'initial split retains unsaved active document')
check(h.public_writes==writes and h.ctx.screen.orientation=='portrait','split chord neither saves nor rotates')
cycle(h,'repeat');cycle(h,'up')
check(a.workspace.ratio=='1:1','held and released chord do not advance again')
-- Both directions and modes preserve active B, both buffers, selection and undo.
for _,direction in ipairs({2,3})do for _,focus in ipairs({false,true})do
  h=Host.new();h:split(direction);h:split(8);a=h:state()
  if focus then h:key('KeyF',nil,chord)end
  cycle(h);h:switch();h:open('bravo.md');h:edit(' B edit')
  local b=a.editor;local originalB=b.buffer:text();local pos=b.buffer.pos;b.anchor=0
  local originalA=a.workspace.sessions[1];local textA=originalA.buffer:text();writes=h.public_writes
  for _,ratio in ipairs({'2:1','1:2','single','1:1'})do
    cycle(h)
    check((ratio=='single'and not a.workspace.split)or(a.workspace.split and a.workspace.ratio==ratio),'cycle reaches '..ratio)
    check(a.workspace.direction==(direction==2 and 'horizontal'or'vertical')and a.focus_mode==focus,'cycle keeps direction and focus')
    check(a.workspace.active==2 and a.editor==b and b.buffer.pos==pos and b.anchor==0,'cycle keeps active B and selection')
    check(a.workspace.sessions[1]==originalA and originalA.buffer:text()==textA and b.buffer:text()==originalB,'cycle keeps both sessions and contents')
    check(h.public_writes==writes and b.dirty,'cycle never saves either document')
  end
  h:key('KeyZ',nil,{ctrl=true})
  check(b.buffer:text()=='Bravo original.\r\n','undo survives a complete shortcut cycle')
end end
-- Ordinary Save and full refresh still work; shifted R owns rotation only.
h=Host.new();a=h:state();h:edit(' save');text=a.editor.buffer:text();h:save()
check(h.files['alpha.md']==text and h.public_writes==1,'Ctrl+S still saves the active document')
local refresh;h.ctx.invalidate=function(_,kind)refresh=kind end
h:key('KeyR',nil,{ctrl=true})
check(refresh=='full'and h.ctx.screen.orientation=='portrait'and not a.workspace.split,'Ctrl+R still refreshes without changing layout')
h:key('KeyR',nil,chord)
check(h.ctx.screen.orientation=='landscape'and h.ctx.state.screen_orientation=='landscape'and not a.workspace.split,'Ctrl+Shift+R rotates without splitting')
App.input(h.ctx,{type='key',source='keyboard',phase='repeat',code='KeyR',mods=chord})
App.input(h.ctx,{type='key',source='keyboard',phase='up',code='KeyR',mods=chord})
check(h.ctx.screen.orientation=='landscape','rotation does not repeat on hold or release')
-- Overlays retain keyboard ownership and recovery failure prevents activation.
h=Host.new();a=h:state();a.languages=true;a.language_focus=1;cycle(h)
check(a.languages and not a.workspace.split,'language picker consumes split chord')
a.languages=nil;App.input(h.ctx,{type='key',key='back',phase='up'});cycle(h)
check(a.close_modal and not a.workspace.split,'close confirmation consumes split chord')
h:key('Escape');h:key('KeyO',nil,{ctrl=true});cycle(h)
check(a.view=='library'and not a.workspace.split,'file picker consumes split chord')
h:key('Escape');h:key('KeyS',nil,{ctrl=true,shift=true,alt=true})
check(not a.workspace.split,'Alt-modified chord does not cycle')
h:edit(' protected');text=a.editor.buffer:text();h.fail_private='recovery-a.txt';cycle(h)
check(not a.workspace.split and a.editor.buffer:text()==text and a.editor.dirty,'failed migration keeps single document intact')
check(a.message and a.message:find('Split screen:',1,true),'failed enable has a visible error')
h.fail_private=nil;cycle(h)
check(a.workspace.split and a.workspace.ratio=='1:1','shortcut can retry after storage recovers')
return n
