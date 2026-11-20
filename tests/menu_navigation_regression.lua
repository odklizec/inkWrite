local Host=require('tests.support.writer_host')
local App=require('domain.app')
local n=0
local function check(value,message)n=n+1;assert(value,message)end
local h=Host.new()
local a=h:state()
local function back()
  return App.input(h.ctx,{type='key',key='back',phase='up'})
end
local function row(label)
  h:draw()
  for _,entries in ipairs({h.texts,h.boxes})do
    for _,item in ipairs(entries)do if item.text==label then return item end end
  end
end
local function tap(label)
  local item=assert(row(label),label)
  h:touch(item.x+(item.w and 3 or 0),item.y+3)
end
h:key('KeyT',nil,{ctrl=true,shift=true})
for _=1,3 do h:key('ArrowRight') end
h:key('Enter')
for _=1,4 do h:key('ArrowRight') end
h:key('Enter')
check(a.view=='menu' and row('Keyboard help >') and row('Statistics >') and not row('Memory & timing'),'Settings opens More without the retired diagnostics')
h:key('ArrowDown');h:key('Enter')
check(a.view=='help','More opens Keyboard help')
h:key('Escape');check(a.view=='menu'and a.focus==2,'Escape restores the exact More row')
h:key('Enter');h:key('F1');check(a.view=='menu'and a.focus==2,'the help shortcut dismisses to the origin')
tap('Statistics >');check(a.view=='statistics','touch opens Statistics')
h:touch(26,h.ctx.screen.height-35)
check(a.view=='menu'and a.focus==3,'the touch footer restores the Statistics row')
tap('Split screen >');check(a.view=='split','More opens Split screen')
check(back() and a.view=='menu'and a.focus==5,'device Back restores Split screen row in More')
back();check(a.view=='editor'and a.panel=='settings'and a.action_focus==9,'More returns to its Settings shelf')
h:key('ArrowLeft');h:key('ArrowLeft');h:key('Enter')
check(a.view=='typography','Typography opens from Settings')
h:key('Enter');check(a.view=='font_help','Typography opens font help')
back();check(a.view=='typography'and a.type_focus==1,'device Back restores the Typography control')
back();check(a.panel=='settings'and a.action_focus==7,'Typography returns to the originating shelf control')
h:key('Escape');h:key('F1');back()
check(a.view=='editor'and not a.panel,'help opened straight from writing returns to writing')
h:key('KeyP',nil,{ctrl=true,shift=true})
local last=assert(row('Back to writing'));local separated=false
for _,line in ipairs(h.lines)do if line.y==last.y-10 and line.t==line.y then separated=true end end
check(separated and row('Enter focus mode').y<last.y,'a horizontal separator precedes the final split action')
tap('Back to writing')
check(a.view=='editor'and not a.workspace.split,'the explicit writing action leaves split settings')
return n
