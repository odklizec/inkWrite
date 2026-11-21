local App=require('domain.app')
local Host=require('tests.support.writer_host')
local assertions=0
local function check(value,message)
  assertions=assertions+1
  assert(value,message)
end

local function hardware(h,key)
  for _,phase in ipairs({'down','up'}) do
    App.input(h.ctx,{type='key',key=key,phase=phase})
  end
end

local function item(h,label)
  h:draw()
  for _,entries in ipairs({h.texts,h.boxes}) do
    for _,entry in ipairs(entries) do
      if entry.text==label then return entry end
    end
  end
end

local function tap(h,label)
  local entry=assert(item(h,label),label)
  h:touch(entry.w and entry.x+entry.w//2 or entry.x,entry.y+8)
end

local function open_type(h,touch)
  if touch then
    tap(h,'Settings')
    tap(h,'Type')
  else
    hardware(h,'ok')
    for _=1,3 do hardware(h,'right') end
    hardware(h,'ok')
    for _=1,2 do hardware(h,'right') end
    hardware(h,'ok')
  end
  check(h:state().view=='typography','Type opens through the writing toolbar')
end

local function system_settings(available)
  local system={opens=0}
  function system:can_open(target)
    check(target=='settings.font','checks the documented capability')
    return available
  end
  function system:open(target)
    check(target=='settings.font','opens the native Fonts page')
    self.opens=self.opens+1
  end
  return system
end

-- Classic uses the same Type action as the keyboard. A clean file is not rewritten.
local classic=system_settings(true)
local c=Host.new({system=classic,state={last='alpha.md',cursor=2,font_px=32,spacing=14,margin=40}})
open_type(c,false)
check(item(c,'Font: System fallback  >') and not item(c,'Font settings'),'single native font action')
hardware(c,'ok')
check(classic.opens==1 and c.public_writes==0 and not c.quit,'Classic launches the picker without rewriting the clean file')
check(c.saved_state.last=='alpha.md' and c.saved_state.cursor==2,'checkpoints every clean document’s active position before launch')
check(c.saved_state.font_px==32 and c.saved_state.spacing==14 and c.saved_state.margin==40,'typography settings are checkpointed')

-- Pro touch uses the same action in landscape. A partial save failure must not
-- close the editor; retry only needs to save the document that failed.
local pro=system_settings(true)
local p=Host.new({system=pro,width=800,height=480})
p:split(2)
p:edit('A')
p:switch()
p:open('bravo.md')
p:edit('B')
local workspace=p:state().workspace
local a,b=workspace.sessions[1],workspace.sessions[2]
local text_a,text_b=a.buffer:text(),b.buffer:text()
local cursor=b.buffer.pos
p.fail_public='bravo.md'
open_type(p,true)
check(not item(p,'?'),'native option does not need separate help in landscape')
tap(p,'Font: System fallback  >')
check(pro.opens==0 and p:state().view=='typography','one failed pane save blocks the handoff')
check(p.files['alpha.md']==text_a and not a.dirty,'first pane is safely saved')
check(p.files['bravo.md']=='Bravo original.\r\n' and b.dirty and b.save_failed,'failed pane retains the unsaved buffer')
check(b.buffer:text()==text_b and b.buffer.pos==cursor and p:state().message,'save failure retains text and caret and reports an error')
local writes=p.public_writes
p.fail_public=nil
tap(p,'Font: System fallback  >')
check(pro.opens==1 and p.public_writes==writes+1 and p.files['bravo.md']==text_b,'retry saves only the remaining pane before launch')
check(p.saved_state.inkwrite_workspace.active==2 and p.saved_state.cursor==cursor,'active pane and caret saved before launch')
App.leave(p.ctx)
p.ctx.state=p.saved_state
p.ctx.fonts.size=function(_,px)
  return {name='Chosen TTF',px=px,line_height=p.font.line_height,measure=p.font.measure}
end
App.load(p.ctx)
local resumed=p:state()
check(resumed.view=='editor' and resumed.workspace.split and resumed.workspace.active==2,'fresh session restores split writing')
check(resumed.font_name=='Chosen TTF' and resumed.editor.buffer.pos==cursor,'fresh session picks up the firmware font and restores the caret')
check(resumed.workspace.sessions[1].buffer:text()==text_a and resumed.editor.buffer:text()==text_b,'fresh session restores both documents')

local old=system_settings(false)
local o=Host.new({system=old})
o:edit('X')
open_type(o,true)
tap(o,'Font settings')
check(o:state().view=='font_help' and old.opens==0 and o.public_writes==0,'older firmware shows instructions without saving or leaving')

local failure=system_settings(true)
function failure:open() self.opens=self.opens+1;return nil,'invalid_argument' end
local f=Host.new({system=failure})
open_type(f,false)
f.fail_state=true
hardware(f,'ok')
check(failure.opens==0 and f:state().view=='typography','failed settings checkpoint blocks the handoff')
check(f:state().message:find('Could not save settings',1,true),'settings checkpoint failure is shown')
f.fail_state=nil
hardware(f,'ok')
check(failure.opens==1 and f:state().view=='typography','host error leaves the editor open')
check(f:state().message:find('Could not open Fonts',1,true),'host error is shown')
hardware(f,'ok')
check(failure.opens==1 and f:state().view=='font_help','failed host shortcut falls back to manual instructions')
return assertions
