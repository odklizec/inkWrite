local UI=require('domain.sync_ui')
local App=require('domain.app')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function app_state()for i=1,50 do local k,v=debug.getupvalue(App.draw,i);if k=='A'then return v end end end
for _,dims in ipairs({{480,800},{800,480}})do
 for _,height in ipairs({24,44})do
  local drawing=false;local calls=0;local private={};local files={['ideas.md']='Žluťoučký\r\n'}
  local font={line_height=height,measure=function(_,v)return (utf8.len(v)or 0)*10 end}
  local c={state={last='ideas.md',github_sync_enabled=true},screen={width=dims[1],height=dims[2],occlusion={left=8,right=8,top=8,bottom=8}},fonts={small=font,medium=font,large=font},clock={},input={},budget={}}
  local function outside()check(not drawing,'no filesystem/network/font work in draw')end
  c.fonts.size=function()outside();return font end
  c.clock.millis=function()return 0 end;c.clock.now=function()return {valid=false}end
  c.budget.extend=function()outside()end;c.input.listen=function()return true end
  c.storage={read=function(_,k)outside();return private[k],private[k]and nil or 'not_found'end,
    write=function(_,k,v)outside();private[k]=v;return true end,remove=function(_,k)outside();private[k]=nil;return true end}
  c.files={size=function(_,k)outside();return files[k]and #files[k]or nil,files[k]and nil or 'not_found'end,
    read=function(_,k,a,z)outside();return files[k]and files[k]:sub(a+1,a+z)or nil,'not_found'end,
    write=function(_,k,v)outside();files[k]=v;return true end}
  c.net={request=function()outside();calls=calls+1;return nil,'no_network'end}
  c.invalidate=function()end;c.set_tick=function()end;c.defer_full_refresh=function()end
  c.after=function()return {cancel=function()end}end
  App.load(c);c.state.github_sync_enabled=false;local a=app_state()
  local function key(code)App.input(c,{type='key',source='keyboard',phase='down',code=code,mods={}})end
  a.view='menu';a.focus=4
  local buffer,doc=a.editor.buffer,a.editor.doc;a.editor.buffer:seek(3);a.editor.anchor=0;a.editor.top=2;a.focus_mode=true
  key('Enter')
  check(a.sync.active and a.sync.focus==1,'More > GitHub opens with Sync selected')
  local labels={};local g=setmetatable({text_box=function(_,x,y,w,h,text,opts)
    check(x>=8 and x+w<=dims[1]-8 and y>=8 and y+h<=dims[2]-8,'all text boxes inside occlusion bounds')
    check(h>=opts.font.line_height,'text box contains a whole preferred-font line')
    labels[text]={x=x,y=y,w=w,h=h}
  end},{__index=function()return function()end end})
  drawing=true;App.draw(c,g);drawing=false
  check(labels['Sync this document']~=nil and labels['Back']==nil,'main list starts with Sync, without duplicate Back row')
  check(calls==0,'opening/drawing offline UI does not start networking')
  App.input(c,{type='text',text='unwanted typing'})
  check(a.editor.buffer==buffer and a.editor.buffer:text()=='Žluťoučký\r\n'and a.editor.doc==doc and a.editor.buffer.pos==3 and a.editor.anchor==0 and a.editor.top==2 and a.focus_mode,'overlay preserves document, selection, cursor, scroll and focus mode')
  a.sync.focus=6;key('Enter');labels={};drawing=true;App.draw(c,g);drawing=false
  local r=labels['GitHub sync: Off']
  App.input(c,{type='pointer',phase='up',gesture='tap',x=r.x+2,y=r.y+2})
  check(c.state.github_sync_enabled==true,'shared touch row toggles explicit opt-in')
  key('Escape');check(a.sync.page=='main'and a.sync.focus==6,'Settings Back restores the selected main row')
  App.input(c,{type='key',key='back',phase='up'})
  check(not a.sync.active and a.view=='menu'and a.focus==4,'Classic Back restores underlying menu')
  check(files['ideas.md']=='Žluťoučký\r\n'and next(private)==nil and calls==0,'offline navigation preserves local and recovery bytes')
  key('Enter');App.pause(c);App.resume(c)
  check(a.sync.active and not a.sync.session:status(c).connected,'pause clears auth; resume does not reconnect')
  -- Conflict is async: reset focus to Cancel even if Upload had focus.
  a.sync.focus=4;a.sync.session.conflict={name='ideas.md',sha=string.rep('a',40)}
  App.tick(c)
  check(a.sync.page=='conflict'and a.sync.focus==1,'new conflict defaults to Cancel')
  key('Enter');check(a.sync.page=='main'and a.sync.focus==4 and a.sync.session.conflict==nil,'Cancel restores the previous selection and leaves originals alone')
  App.input(c,{type='key',key='down',phase='down'})
  check(a.sync.focus==5,'Classic directional navigation')
  App.input(c,{type='key',key='up',phase='down'})
  a.sync.focus=6;key('Enter')
  App.input(c,{type='key',key='ok',phase='down'})
  check(c.state.github_sync_enabled==false,'Classic OK activates row once')
  check(calls==0,'no implicit background requests')
  a.sync.focus=3;key('Enter')
  check(a.sync.page=='remember'and a.sync.focus==1 and c.state.github_sync_remember~=true,'Remember requires confirmation, default Cancel')
  labels={};drawing=true;App.draw(c,g);drawing=false
  check(labels['Save GitHub login unencrypted on SD.\nAnyone with the card can recover it.']~=nil,'credential-storage risk remains visible in portrait/landscape and tall fonts')
  key('Enter');check(c.state.github_sync_remember~=true and a.sync.page=='settings'and a.sync.focus==3,'Cancel returns to Settings without enabling persistence')
  a.sync.focus=3;key('Enter');key('ArrowDown');key('Enter')
  check(c.state.github_sync_remember==true and calls==0,'only explicit Remember consent enables future persistence; no network is started')
  a.sync.focus=2;key('Enter')
  check(a.sync.page=='auto','the automatic upload settings are grouped with the opt-in')
  key('Escape');check(a.sync.page=='settings'and a.sync.focus==2,'automatic uploads returns to Settings')
  key('Escape');key('ArrowDown');key('Enter')
  check(a.sync.page=='help','help opens from the main GitHub menu')
  key('ArrowDown');key('Enter');check(a.sync.page=='revoke','revocation instructions live under Help')
  key('Escape');check(a.sync.page=='help'and a.sync.focus==2,'Back returns to the help topic list')
  key('ArrowUp');key('Enter');check(a.sync.page=='setup_help','setup instructions live under Help')
  key('Escape');key('Escape');key('Escape');a.view='editor';c.state.github_sync_remember=false;c.state.github_sync_enabled=false
  App.input(c,{type='key',source='keyboard',code='KeyG',phase='down',mods={ctrl=true}})
  check(a.sync.active and a.sync.page=='connect'and a.editor.buffer:text()==files['ideas.md']and calls==0,'Ctrl+G opens first-use Sync setup without typing into the document')

 end
end
return n
