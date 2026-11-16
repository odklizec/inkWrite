local Buffer=require("domain.buffer")
local Docs=require("domain.documents")
local Layout=require("domain.layout")
local Keyboard=require("keyboard")
local Stats=require("domain.stats")
local SyncUI=require('domain.sync_ui')
local M={VERSION="1.0.14"}
local PREVIEW="Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris."
local A
-- Typing pacing. None of these shorten the panel's own frame time; they keep
-- the app's work and SD writes out of the way of that frame.
local COALESCE_MS=30           -- group keys closer together than this
local FULL_REFRESH_DEFER=4000  -- keep the automatic full refresh out of a burst
local FULL_REFRESH_HOLD=25000  -- ...but not for a whole session
local QUIET_MS=700             -- a gap long enough to accept an SD write
local SAVE_FORCE_MS=120000     -- never postpone a public save beyond this
local STATS_FORCE_MS=180000    -- bound what a long unbroken session can lose
local FONT_SIZES={20,24,28,30,32,36}
local function preferred_font(ctx,px)
  local f=ctx.fonts.size and ctx.fonts:size(px)
  if f then return f end
  return px>=28 and ctx.fonts.large or ctx.fonts.medium
end
local prepare_frame
local function extend_budget(ctx)
  if ctx.budget then ctx.budget:extend() end
end
local function message(ctx,s) A.message=s; ctx:invalidate() end
local function now(ctx) return ctx.clock:millis() end
local function age(t,earlier) return (t-earlier)&0x7fffffff end
local function timing(metric,ms)
  -- Last, mean and worst. A single worst case says very little here: one
  -- unlucky sample reads 28 ms while a normal keystroke waits a whole frame.
  if not metric then return end
  metric.last=ms
  metric.n=(metric.n or 0)+1
  metric.sum=(metric.sum or 0)+ms
  if ms>metric.max then metric.max=ms end
end
local function timing_line(label,key)
  local t=A.timing[key]
  local avg=t.n>0 and t.sum//t.n or 0
  return label.." "..t.last.."/"..avg.."/"..t.max
end
local function selection()
  local p=A.buffer.pos; local a=A.anchor or p
  return math.min(a,p),math.max(a,p)
end
local function font(ctx)
  return A.body_font or A.ui_medium or ctx.fonts.medium
end
local function geometry(ctx)
  local o=ctx.screen.occlusion or {left=0,right=0,top=0,bottom=0}
  local margin=A.view=="editor" and A.margin or 24
  local l={x=o.left+margin,y=o.top+18,right=ctx.screen.width-o.right-margin,bottom=ctx.screen.height-o.bottom-18}
  l.w=l.right-l.x; l.body=l.y+108; l.foot=l.bottom-94
  if A.focus_mode and A.view=="editor" then l.body=l.y+60 end
  l.footer=not (A.focus_mode and A.view=="editor") or A.save_failed or A.blocked or A.message~=nil
  if A.view=="editor" and not A.message and not A.save_failed and not A.blocked then l.foot=l.bottom-(l.footer and 40 or 0) end
  do
    l.chrome_left=o.left+20;l.chrome_right=ctx.screen.width-o.right-20
    l.header=o.top+68;l.dock=l.bottom-48
    l.body=(A.focus_mode and A.view=="editor" and o.top+38 or l.header)+10
    l.footer=A.save_failed or A.blocked or A.message~=nil
    l.foot=A.focus_mode and A.view=="editor" and l.bottom or l.dock
    if l.footer then l.foot=l.foot-94 end
  end
  if A.virtual and A.view=="editor" then l.foot=math.min(l.foot,ctx.screen.height-o.bottom-266-(l.footer and 94 or 0)) end
  if A.view=="statistics" then l.footer=false;l.foot=l.dock end
  l.text_bottom=l.foot-12
  l.step=font(ctx).line_height+A.spacing; l.count=math.max(1,(l.text_bottom-l.body)//l.step)
  l.row=44
  if A.view=="library" then l.row=math.max(l.row,A.ui_small.line_height+8) end
  l.list_bottom=l.foot-8; l.per=math.max(1,(l.list_bottom-l.body)//l.row)
  l.key=table.concat({l.x,l.y,l.w,l.body,l.foot,l.step},":")
  if A.view=="editor" and not A.focus_mode then
    l.controls={};local width=(l.chrome_right-l.chrome_left)//4
    for i=1,4 do l.controls[i]={x=l.chrome_left+(i-1)*width,y=l.dock,w=width,h=66} end
    if A.panel=="settings" then
      local shelf_width=(l.chrome_right-l.chrome_left)//5
      for i=1,5 do l.controls[i+4]={x=l.chrome_left+(i-1)*shelf_width,y=l.dock-60,w=shelf_width,h=60} end
      l.panel_top=l.dock-60
    elseif A.panel=="new" then
      l.panel_top=l.dock-156
      for i=1,3 do l.controls[i+4]={x=l.chrome_left,y=l.panel_top+(i-1)*52,w=l.chrome_right-l.chrome_left,h=52} end
    end
  end
  if A.view=="typography" then
    l.type_controls={};local cs=l.type_controls
    local horizontal=ctx.screen.width>ctx.screen.height
    local controls_height=horizontal and 140 or 270
    local base=l.dock-controls_height-12
    l.type_notice=A.message or (A.blocked and "Files are protected") or (A.save_failed and "Save failed")
    l.footer=false
    local available=base-l.body-18-(l.type_notice and 60 or 0)
    local count=math.min(5,math.max(0,(available+A.spacing)//l.step))
    local height=count>0 and count*font(ctx).line_height+(count-1)*A.spacing or 0
    l.preview={x=o.left+A.margin,y=l.body,w=ctx.screen.width-o.right-o.left-2*A.margin,count=count,h=height}
    l.type_notice_y=base-60
    local half=(l.w-16)//2
    cs[1]={x=l.x,y=base+(horizontal and 20 or 0),w=horizontal and half or l.w,h=44,kind="font",label="Font: "..(A.font_name=="" and "System" or A.font_name)}
    local sizes=FONT_SIZES
    local cell=(horizontal and half or l.w)//(#sizes+2)
    local sx=horizontal and l.x+half+16 or l.x;local sy=base+(horizontal and 20 or 80)
    cs[#cs+1]={x=sx,y=sy,w=cell,h=44,kind="size",delta=-1,label="A-"}
    for i,value in ipairs(sizes) do cs[#cs+1]={x=sx+i*cell,y=sy,w=cell,h=44,kind="size",value=value,label=tostring(value),selected=A.font_px==value} end
    cs[#cs+1]={x=sx+(#sizes+1)*cell,y=sy,w=cell,h=44,kind="size",delta=1,label="A+"}
    local width=half//3;local gy=base+(horizontal and 96 or 162)
    for group,values in ipairs({{4,8,14},{24,40,56}}) do
      for i,value in ipairs(values) do cs[#cs+1]={x=l.x+(group-1)*(half+16)+(i-1)*width,y=gy,w=width,h=44,kind=group==1 and "spacing" or "margin",value=value,label=({"S","M","L"})[i],selected=(group==1 and A.spacing or A.margin)==value} end
    end
    cs[#cs+1]={x=horizontal and l.right-44 or l.x,y=horizontal and o.top+2 or base+226,w=horizontal and 44 or l.w,h=horizontal and 40 or 44,kind="help",label=horizontal and "?" or "Font settings"}
    l.type_labels={{x=sx,y=sy-24,text="Text size"},{x=l.x,y=gy-24,text="Line spacing"},{x=l.x+half+16,y=gy-24,text="Margins"}}
  end
  return l
end
local function refresh_layout(ctx)
  extend_budget(ctx)
  local l=geometry(ctx); local b=A.buffer
  local f=font(ctx)
  local same=A.layout_font==f and A.layout_width==l.w and A.layout_count==l.count and A.layout_top==A.top
  if not same or A.layout_revision~=b.revision then
    A.rows=Layout.rows(b,f,l.w,A.top,l.count,same and A.rows or nil,A.layout_dirty_from)
  end
  if not A.browsing and not A.text_tap and not Layout.caret_row(A.rows,b.pos) then
    A.top=math.max(0,b.pos-512)
    while not b:is_boundary(A.top) do A.top=A.top+1 end
    -- Start near the caret, then drop leading rows until it is in view.
    for _=1,32 do
      A.rows=Layout.rows(b,font(ctx),l.w,A.top,l.count)
      if Layout.caret_row(A.rows,b.pos) then break end
      if not A.rows[2] then A.top=b.pos; break end
      A.top=A.rows[2].a
    end
    A.rows=Layout.rows(b,font(ctx),l.w,A.top,l.count)
  end
  A.layout_revision=b.revision; A.layout_pos=b.pos
  A.layout_font=f; A.layout_width=l.w; A.layout_count=l.count; A.layout_top=A.top
  A.layout_dirty_from=nil
end
local function cancel_redraw()
  if A.redraw_timer then A.redraw_timer:cancel(); A.redraw_timer=nil end
  A.pending_frame_since=nil
end
local function request_editor_frame(ctx)
  -- The first key after idle is prepared and shown at once. Keys that arrive
  -- while that frame is being prepared share one 30 ms window: grouping them
  -- saves a little work and never holds text back past the frame that is
  -- already on its way. A wider window only delayed the newest text by a whole
  -- refresh, which is what made typing feel slower.
  if A.redraw_timer then
    A.pending_frame_since=A.pending_frame_since or A.input_started or now(ctx)
    return
  end
  A.pending_frame_since=A.input_started or now(ctx)
  local function flush(c)
    A.redraw_timer=nil
    local p=A.prepared;local l=geometry(c)
    if not p or p.doc~=A.doc or p.view~=A.view or p.key~=l.key or p.font~=font(c)
      or p.revision~=A.buffer.revision or p.pos~=A.buffer.pos or p.top~=A.top or p.anchor~=A.anchor then
      A.redraw_timer=c:after(COALESCE_MS,flush)
      prepare_frame(c);c:invalidate()
    else A.pending_frame_since=nil end
  end
  A.redraw_timer=ctx:after(COALESCE_MS,flush)
  prepare_frame(ctx);ctx:invalidate()
end
local function changed(ctx,from,words)
  -- One statistics update per edit: the caller passes the word delta it already
  -- knows, so a typed character is not accounted twice.
  if A.stats then A.stats:edit(ctx,words or 0) end
  A.goal_x=nil
  local t=now(ctx)
  if not A.dirty then A.first_dirty=t end
  A.dirty=true; A.last_edit=t; A.save_failed=false; A.message=nil
  A.layout_dirty_from=math.min(A.layout_dirty_from or A.buffer.size,from or 0)
  -- Frames shown inside this window neither trigger nor count toward the
  -- automatic full refresh, so slow typing no longer gets a 1.5 s flash in the
  -- middle of a sentence. It stops extending after a long unbroken run, so
  -- ghosting is still cleared during a marathon session.
  A.typing_run=A.typing_run or t
  if age(t,A.typing_run)<FULL_REFRESH_HOLD then ctx:defer_full_refresh(FULL_REFRESH_DEFER) end
  request_editor_frame(ctx)
end
local function insert(ctx,s,typing)
  local a,z=selection(); local t=now(ctx)
  if not typing or a~=z or not A.typing_time or age(t,A.typing_time)>1000 then A.typing_group={} end
  local old_words=A.buffer.words
  local ok,e=A.buffer:replace(a,z,s,nil,typing and a==z and A.typing_group or nil)
  if not ok then message(ctx,e); return end
  A.typing_time=typing and not s:find("%s") and t or nil
  A.anchor=nil; changed(ctx,a,A.buffer.words-old_words)
end
local function move(ctx,p,shift)
  if shift then A.anchor=A.anchor or A.buffer.pos else A.anchor=nil end
  A.buffer:seek(p); request_editor_frame(ctx)
end
local function cancel_navigation()
  if A.nav_timer then A.nav_timer:cancel();A.nav_timer=nil end
  A.nav_job=nil
end
local function clipboard(ctx,cut)
  local a,z=selection()
  if a==z then message(ctx,"Select text with Shift+arrows first"); return end
  if z-a>8192 then message(ctx,"Clipboard limit: 8 KiB; text unchanged"); return end
  A.clipboard=A.buffer:slice(a,z)
  if cut then insert(ctx,"") else message(ctx,"Copied inside inkWrite") end
end
-- Markdown source shortcuts. These only insert and remove markers; no rendering
-- and no change to how the editor lays text out.
local function markdown_doc(ctx)
  if A.doc and A.doc.name and A.doc.name:lower():sub(-3)==".md" then return true end
  message(ctx,"Markdown formatting is available in .md files")
  return false
end
local function line_start(b,p)
  local i=p
  while i>0 do
    if b:byte(i-1)==10 then break end
    i=i-1
  end
  return i
end
local function line_end(b,p)
  local i=p
  while i<b.size do
    if b:byte(i)==10 then break end
    i=i+1
  end
  return i
end
-- "# " with a space is a heading; a bare run of hashes is ordinary text.
local function heading_prefix(line)
  local hashes=line:match("^(#+)")
  if hashes and #hashes<=6 and line:sub(#hashes+1,#hashes+1)==" " then return #hashes end
  return 0
end
local function without_heading(line)
  local n=heading_prefix(line)
  return n>0 and line:sub(n+2) or line
end
local function set_heading(line,level)
  local base=without_heading(line)
  if level==0 then return base end
  if heading_prefix(line)==level then return base end
  return string.rep("#",level).." "..base
end
local function set_bullet(line)
  local base=without_heading(line)
  if base:sub(1,2)=="- " then return base:sub(3) end
  return "- "..base
end
local function set_quote(line)
  local base=without_heading(line)
  if base:sub(1,2)=="> " then return base:sub(3) end
  return "> "..base
end
-- Toggle a line-start marker on every line the selection touches. The block is
-- rebuilt as one string and replaced once, so byte offsets stay valid and undo
-- records a single edit.
local function markers(ctx,kind,level)
  local b=A.buffer
  local a,z=selection()
  local s=line_start(b,a)
  local e=line_end(b,z)
  local block=b:slice(s,e)
  local lines={}
  for line in (block.."\n"):gmatch("(.-)\n") do lines[#lines+1]=line end
  -- Remember which line the caret is on and how far into it, before the text
  -- changes: the marker moves the caret by the same amount it changed the line.
  local caret,offset=#lines,0
  local run=s
  for i=1,#lines do
    local n=#lines[i]
    if b.pos<=run+n then caret=i;offset=b.pos-run;break end
    run=run+n+1
  end
  if offset<0 then offset=0 end
  local out={}
  for i=1,#lines do
    if kind=="heading" then out[i]=set_heading(lines[i],level)
    elseif kind=="bullet" then out[i]=set_bullet(lines[i])
    else out[i]=set_quote(lines[i]) end
  end
  local new=table.concat(out,"\n")
  if new==block then return end
  local ok,err=b:replace(s,e,new)
  if not ok then message(ctx,err);return end
  A.anchor=nil
  local start=s
  for i=1,caret-1 do start=start+#out[i]+1 end
  local shift=#out[caret]-#lines[caret]
  local p=start+math.max(0,math.min(#out[caret],offset+shift))
  while p>s and not b:is_boundary(p) do p=p-1 end
  b:seek(p)
  changed(ctx,s)
end
local function link(ctx)
  local a,z=selection()
  local s=A.buffer:slice(a,z)
  local inner=s:match("^%[([^%]]*)%]%b()$")
  local replacement,p
  if inner then replacement,p=inner,a+#inner
  elseif s=="" then replacement,p="[]()",a+1
  else replacement,p="["..s.."]()",a+#s+3 end
  local ok,err=A.buffer:replace(a,z,replacement)
  if not ok then message(ctx,err);return end
  A.anchor=nil;A.buffer:seek(p)
  changed(ctx,a)
end
-- Shared gate for the marker shortcuts: editor only, .md only.
local function markdown_action(ctx,fn)
  if A.view~="editor" or A.blocked then return end
  if not markdown_doc(ctx) then return end
  fn()
end
local function format(ctx,marker)
  local a,z=selection(); local n=#marker
  local s=A.buffer:slice(a,z)
  local replacement
  if #s>=n*2 and s:sub(1,n)==marker and s:sub(-n)==marker then
    replacement=s:sub(n+1,-n-1)
  elseif a>=n and z+n<=A.buffer.size and A.buffer:slice(a-n,a)==marker and A.buffer:slice(z,z+n)==marker then
    a=a-n;z=z+n;replacement=s
  else replacement=marker..s..marker end
  local ok,e=A.buffer:replace(a,z,replacement)
  if not ok then message(ctx,e);return end
  if s=="" and replacement==marker..marker then
    A.anchor=nil;A.buffer:seek(a+n)
  else A.anchor=a end
  changed(ctx,a)
end
local function save(ctx)
  extend_budget(ctx)
  A.typing_time=nil; A.typing_run=nil
  if A.blocked then message(ctx,"Recovery needs attention; existing files are protected"); return false end
  if not A.doc or not A.buffer then return false end
  if not A.dirty and A.doc.base~=nil then
    ctx.state.last=A.doc.name;ctx.state.cursor=A.buffer.pos
    A.message=nil;ctx:invalidate(); return true
  end
  A.recovery_doc=nil;A.recovery_revision=nil
  A.status="Saving..."
  local started=now(ctx)
  local ok,result,err=pcall(function()
    local text=A.buffer:text()
    return Docs.save(ctx,A.doc,text)
  end)
  timing(A.timing.save,age(now(ctx),started))
  if not ok or not result then
    A.status="SAVE FAILED"; A.save_failed=true
    message(ctx,tostring(ok and err or result)); return false
  end
  A.dirty=false; A.save_failed=false; A.status="Saved on SD card"
  ctx.state.last=A.doc.name; ctx.state.cursor=A.buffer.pos
  A.message=nil;ctx:invalidate()
  return true
end
local function close_request(ctx)
  cancel_navigation();cancel_redraw();A.keyboard:reset();A.panel=nil;A.action_focus=nil
  A.close_modal={choice=1,dirty=A.dirty};ctx:invalidate()
end
local function close_choice(ctx,i)
  local modal=A.close_modal;if not modal then return end
  if i==1 then A.close_modal=nil;ctx:invalidate();return end
  if not modal.dirty then A.close_modal=nil;ctx:quit();return end
  if i==2 then
    A.close_modal=nil
    if save(ctx) then ctx:quit() end
  else
    local rec,e=Docs.load_recovery(ctx)
    if rec==nil then A.close_modal=nil;message(ctx,"Cannot discard recovery: "..tostring(e));return end
    if rec and rec.name==A.doc.name then
      local ok,err=Docs.call(ctx.storage,"remove","recovery.txt")
      if not ok then A.close_modal=nil;message(ctx,"Cannot discard recovery: "..tostring(err));return end
    end
    A.discard_exit=true;A.close_modal=nil;ctx:quit()
  end
end
local function close_rect(ctx)
  local l=geometry(ctx);local w=l.chrome_right-l.chrome_left;local h=190
  return {x=l.chrome_left,y=(ctx.screen.height-h)//2,w=w,h=h}
end
local function set_document(ctx,name,text,base,dirty)
  cancel_navigation();A.goal_x=nil;A.browsing=false;A.panel=nil;A.action_focus=nil
  cancel_redraw()
  A.recovery_doc=nil;A.recovery_revision=nil
  A.doc={name=name,base=base}; A.buffer=assert(Buffer.new(text)); A.anchor=nil; A.top=0
  A.layout_revision=nil; A.layout_dirty_from=0
  A.dirty=dirty or false; A.save_failed=false; A.status=dirty and "Unsaved" or "Saved on SD card"
  A.first_dirty=now(ctx); A.last_edit=A.first_dirty; A.view="editor"
  refresh_layout(ctx); ctx:invalidate()
end
local function new_document(ctx,plain)
  extend_budget(ctx)
  if A.blocked then return end
  if A.dirty and not save(ctx) then return end
  local t=ctx.clock:now()
  local prefix=t.valid and string.format("%04d-%02d-%02d",t.year,t.month,t.day) or "undated"
  local name,e=Docs.fresh_name(ctx,prefix,plain and ".txt" or ".md")
  if not name then message(ctx,tostring(e)); return false end
  set_document(ctx,name,"",nil,true)
  A.message=nil
  return true
end
local function library(ctx)
  if A.dirty and not save(ctx) then return end
  local rows,e=Docs.list(ctx)
  if not rows then message(ctx,"Cannot list SD files: "..tostring(e)); return end
  A.files=rows; A.focus=1;A.file_action=1; A.view="library"; A.message=nil; ctx:invalidate()
end
local function reload_files(ctx,selected)
  local rows,e=Docs.list(ctx)
  if not rows then message(ctx,"Cannot list SD files: "..tostring(e));return end
  A.files=rows;A.focus=math.max(1,math.min(A.focus,#rows))
  if selected then for i,row in ipairs(rows) do if row.name==selected then A.focus=i;break end end end
  A.view="library";A.file_action=1;ctx:invalidate()
end
local function clear_matching_recovery(ctx,name)
  local rec,e=Docs.load_recovery(ctx)
  if rec==nil then message(ctx,"Recovery check: "..tostring(e));return false end
  if rec and rec.name:lower()==name:lower() then
    local text=Docs.read(ctx,name)
    if text~=rec.text then message(ctx,"Recovery differs; reopen inkWrite before managing this file");return false end
    local ok,er=Docs.call(ctx.storage,"remove","recovery.txt")
    if not ok then message(ctx,"Recovery cleanup: "..tostring(er));return false end
  end
  return true
end
local function file_action(ctx,action)
  local row=A.files and A.files[A.focus]
  if A.blocked or not row or A.file_job or A.file_dialog then return end
  if action=="delete" then A.confirm_file={name=row.name,size=row.size};A.view="delete_confirm";A.confirm_choice=1;A.message=nil;ctx:invalidate();return end
  if not ctx.input.text then message(ctx,"Rename input unavailable on this firmware");return end
  local old=row.name;A.file_dialog=true
  local _,e=Docs.call(ctx.input,"text",{title="Rename file",text=old,max_bytes=128},function(c,name)
    A.file_dialog=nil
    if not name then c:invalidate();return end
    if not Docs.name_ok(name) then message(c,"Use a valid .md or .txt filename (up to 128 UTF-8 bytes)");return end
    if not clear_matching_recovery(c,old) then return end
    local job,err=Docs.rename(c,old,name,function(c,ok,why)
      A.file_job=nil
      if ok and A.doc.name:lower()==old:lower() then A.doc.name=name;c.state.last=name end
      reload_files(c,ok and name or old)
      if ok then A.message=nil else A.message="Rename: "..tostring(why) end
      c:invalidate()
    end)
    if not job then message(c,"Rename: "..tostring(err));return end
    A.file_job=job;A.message="Renaming file; please wait";c:invalidate()
  end)
  if e then A.file_dialog=nil;message(ctx,"Rename: "..tostring(e)) end
end
local function confirm_delete(ctx)
  local row=A.confirm_file;A.confirm_file=nil;A.view="library"
  if not row or A.blocked then ctx:invalidate();return end
  local n,e=Docs.call(ctx.files,"size",row.name)
  if n~=row.size then message(ctx,"File changed; refresh the list before deleting");return end
  if not clear_matching_recovery(ctx,row.name) then return end
  local current=A.doc.name:lower()==row.name:lower()
  local nextname
  if current then
    nextname,e=Docs.fresh_name(ctx,"untitled")
    if not nextname then message(ctx,tostring(e));return end
  end
  local ok,err=Docs.call(ctx.files,"remove",row.name)
  if not ok then message(ctx,"Delete: "..tostring(err));return end
  if current then set_document(ctx,nextname,"",nil,false);ctx.state.last=nil;ctx.state.cursor=0 end
  A.message=nil;reload_files(ctx)
end
local function file_size(n) return n<1000 and tostring(n).."B" or tostring(n//1000).."kB" end
local function file_cells(ctx,l,row)
  return l.right-88,l.right-44,l.right-96
end
local function open_file(ctx,name)
  extend_budget(ctx)
  if A.blocked then return end
  if A.dirty and not save(ctx) then return end
  local text,e=Docs.read(ctx,name)
  if not text then message(ctx,tostring(e)); return end
  set_document(ctx,name,text,text,false)
  ctx.state.last=name
end
local function today(ctx)
  extend_budget(ctx)
  if A.blocked then return end
  local t=ctx.clock:now()
  if not t.valid then message(ctx,"Set the device date before opening today's journal");return end
  if A.dirty and not save(ctx) then return end
  local name=string.format("%04d-%02d-%02d-journal.md",t.year,t.month,t.day)
  if A.doc.name==name then A.view="editor";ctx:invalidate();return end
  local text,e=Docs.read(ctx,name)
  if text then set_document(ctx,name,text,text,false);ctx.state.last=name
  elseif e=="not_found" then set_document(ctx,name,"",nil,true)
  else message(ctx,"Journal not opened: "..tostring(e)) end
end
local function select_keyboard(ctx,id)
  A.keyboard:reset();A.keyboard=Keyboard.new(id);ctx.state.keyboard_layout=A.keyboard.id
  A.national_page=nil;A.virtual_focus=nil;A.typing_time=nil
end
local function enabled_keyboards(ctx)
  local stored=ctx.state.keyboard_enabled;local ids={};local names={}
  for i,id in ipairs(Keyboard.ids) do
    if type(stored)=="table" and stored[id]==true then ids[#ids+1]=id;names[#names+1]=Keyboard.names[i] end
  end
  if #ids==0 then ids={"us"};names={"English (US)"};ctx.state.keyboard_enabled={us=true} end
  A.enabled_ids=ids;A.enabled_names=names
  local found=false;for _,id in ipairs(ids) do if id==A.keyboard.id then found=true end end
  if not found then select_keyboard(ctx,ids[1]) end
end
local function cycle_keyboard(ctx)
  local index=1;for i,id in ipairs(A.enabled_ids) do if id==A.keyboard.id then index=i end end
  select_keyboard(ctx,A.enabled_ids[index%#A.enabled_ids+1]);A.languages=nil;ctx:invalidate()
end
local function toggle_orientation(ctx)
  cancel_navigation();cancel_redraw();A.keyboard:reset();A.text_tap=nil
  local target=ctx.screen.orientation=="landscape" and "portrait" or "landscape"
  if not ctx.screen.set_orientation then message(ctx,"Screen rotation requires XTApp API 2.18");return end
  local ok,err=ctx.screen:set_orientation(target)
  if not ok then message(ctx,"Screen rotation failed: "..tostring(err));return end
  ctx.state.screen_orientation=target
  A.touch_geometry=nil;A.layout_revision=nil;A.languages=nil;A.panel=nil;A.action_focus=nil
end
local commands={"Back to writing","Save to SD card","New Markdown page","Open SD files","Typography","Where are my files?","Keyboard help","Memory & timing","Save and exit","Orientation: follow device","Focus: Ctrl+Shift+F","Today's journal: Ctrl+J","New plain text page","Keyboard layout"}
-- Ask only for sizes. API 2.17+ selects the user's Ink App font.
local function choose_font(ctx,name,px)
  extend_budget(ctx)
  local f=preferred_font(ctx,px)
  A.body_font=f;A.font_name=f.px and (f.name or "Ink App font") or "System fallback"
  A.font_px=px;A.large=px>=28
  ctx.state.font_name=nil;ctx.state.font_px=px;ctx.state.large=A.large
  A.layout_revision=nil;A.touch_geometry=nil
  return true
end
local function typography_rows()
  return {"Back to writing","Font: "..(A.font_name=="" and "System" or A.font_name),
    "Size: "..A.font_px.." px","Line spacing: +"..A.spacing.." px","Margins: "..A.margin.." px","Font settings"}
end
local function list_rows()
  if A.view=="menu" then return {commands[6],commands[7],commands[8],"Statistics","GitHub sync"} end
  if A.view=="layouts" then
    local rows={"On-screen keyboard: "..(A.virtual and "On" or "Off")}
    for _,name in ipairs(Keyboard.names) do rows[#rows+1]=name end
    return rows
  end
  if A.view=="typography" then return typography_rows() end
  if A.view=="fonts" then return A.font_names end
  return A.files
end
local function font_picker(ctx)
  A.message=nil;A.view="font_help";A.help_page=1
end
local function typography_command(ctx,i)
  A.message=nil
  if i==1 then A.view="editor";refresh_layout(ctx)
  elseif i==2 then font_picker(ctx)
  elseif i==3 then
    local sizes=FONT_SIZES
    local nextpx=sizes[1]
    for j,p in ipairs(sizes) do if p==A.font_px then nextpx=sizes[j%#sizes+1];break end end
    choose_font(ctx,A.font_name,nextpx)
  elseif i==4 then A.spacing=A.spacing==4 and 8 or A.spacing==8 and 14 or 4;ctx.state.spacing=A.spacing
  elseif i==5 then A.margin=A.margin==24 and 40 or A.margin==40 and 56 or 24;ctx.state.margin=A.margin
  elseif i==6 then A.view="font_help";A.help_page=1 end
  ctx:invalidate()
end
local function type_control(ctx,c)
  A.message=nil
  if c.kind=="font" then font_picker(ctx)
  elseif c.kind=="help" then A.view="font_help";A.help_page=1
  elseif c.kind=="size" then
    local sizes=FONT_SIZES
    local value=c.value
    if not value then
      local index=1;for i,n in ipairs(sizes) do if n==A.font_px then index=i end end
      value=sizes[math.max(1,math.min(#sizes,index+c.delta))]
    end
    choose_font(ctx,A.font_name,value)
  elseif c.kind=="spacing" then A.spacing=c.value;ctx.state.spacing=c.value
  elseif c.kind=="margin" then A.margin=c.value;ctx.state.margin=c.value end
  ctx:invalidate()
end
local function command(ctx,i)
  A.panel=nil;A.action_focus=nil;A.keyboard:reset()
  if A.message and A.message:sub(1,7)=="Accent:" then A.message=nil end
  if A.blocked and i~=1 and i~=6 and i~=7 and i~=8 and i~=9 and i~=10 and i~=15 and i~=16 then
    message(ctx,"Existing files and recovery are protected"); return
  end
  if i==1 then A.view="editor"
  elseif i==2 then save(ctx)
  elseif i==3 then new_document(ctx)
  elseif i==4 then library(ctx)
  elseif i==5 then A.view="typography";A.focus=1;A.type_focus=1;A.message=nil
  elseif i==6 then A.view="files_help";A.help_page=1
  elseif i==7 then A.view="help";A.help_page=1
  elseif i==8 then
    -- Measuring the heap can be slow, so it is sampled once on opening; the
    -- counters themselves are rebuilt every time the page is drawn.
    A.memory_heap=nil
    if ctx.gc then ctx.gc:collect();A.memory_heap="Lua heap: "..tostring(ctx.gc:count()//1024).." KiB" end
    A.view="timing"
  elseif i==9 then close_request(ctx) end
  if i==10 then toggle_orientation(ctx) end
  if i==11 then
    A.focus_mode=not A.focus_mode;ctx.state.focus_mode=A.focus_mode
    A.view="editor";A.layout_revision=nil;A.touch_geometry=nil
  end
  if i==12 then today(ctx) end
  if i==13 then new_document(ctx,true) end
  if i==15 then A.virtual=nil;A.view="statistics";A.stats_mode=A.stats_mode or 1;A.stats:tick(ctx,true) end
  if i==14 then A.view="layouts";A.focus=1 end
  if i==16 then cancel_navigation();A.sync:open(ctx)end
  ctx:invalidate()
end
local function activate(ctx,i)
  if A.view=="menu" then command(ctx,({6,7,8,15,16})[i])
  elseif A.view=="layouts" then
    if i==1 then A.virtual=not A.virtual
    else
      local id=Keyboard.ids[i-1];local enabled=ctx.state.keyboard_enabled
      if enabled[id] and #A.enabled_ids==1 then message(ctx,"Keep at least one keyboard selected");return end
      enabled[id]=not enabled[id] or nil;enabled_keyboards(ctx)
    end
    A.typing_time=nil;A.message=nil;ctx:invalidate()
  elseif A.view=="typography" then typography_command(ctx,i)
  elseif A.view=="fonts" then
    local name=i==1 and "" or A.font_names[i]
    if name then
      choose_font(ctx,name,name=="" and (A.font_px>=28 and 30 or 24) or A.font_px)
      A.view="typography";A.focus=2;ctx:invalidate()
    end
  elseif A.files[i] then open_file(ctx,A.files[i].name) end
end
local function menu(ctx) cancel_navigation();A.panel=nil;A.action_focus=nil;A.keyboard:reset();if A.message and A.message:sub(1,7)=="Accent:" then A.message=nil end;A.goal_x=nil;A.view="menu"; A.focus=1; ctx:invalidate() end
local function chrome_action(ctx,i)
  cancel_navigation();A.keyboard:reset();A.typing_time=nil
  if A.message and A.message:sub(1,7)=="Accent:" then A.message=nil end
  if i==1 or i==4 then
    local panel=i==1 and "new" or "settings"
    A.panel=A.panel==panel and nil or panel
    if A.action_focus then A.action_focus=A.panel and 5 or i end
  elseif i==2 then A.panel=nil;A.action_focus=nil;command(ctx,4)
  elseif i==3 then A.panel=nil;A.action_focus=nil;save(ctx)
  elseif A.panel=="new" then
    command(ctx,({12,3,13})[i-4])
  elseif i==9 then menu(ctx)
  else command(ctx,({11,10,5,14})[i-4]) end
  ctx:invalidate()
end
function M.load(ctx)
  extend_budget(ctx)
  A={view="editor",top=0,focus=1,large=ctx.state.large==true,caps=false,dirty=false,status="Unsaved",rows={}}
  A.timing={}
  for _,key in ipairs({"input","layout","draw","queue","save","compose"}) do A.timing[key]={last=0,max=0,n=0,sum=0} end
  A.stats=Stats.new(ctx)
  A.focus_mode=ctx.state.focus_mode==true
  A.keyboard=Keyboard.new(ctx.state.keyboard_layout)
  enabled_keyboards(ctx)
  local orientation=ctx.state.screen_orientation
  if (orientation=="portrait" or orientation=="landscape") and ctx.screen.set_orientation then
    local ok=ctx.screen:set_orientation(orientation)
    if not ok then ctx.state.screen_orientation=nil end
  end
  A.ui_small=preferred_font(ctx,20);A.ui_medium=preferred_font(ctx,24);A.ui_large=preferred_font(ctx,30)
  A.sync=SyncUI.new({
    reserved_name=function()return A.doc and A.doc.name end,
    can_import=function()return not A.blocked end,
    describe=function()return {name=A.doc and A.doc.name,dirty=A.dirty}end,
    apply_remote=function(c,captured,text)
      extend_budget(c)
      if A.blocked or A.dirty or A.doc~=captured.identity or A.buffer.revision~=captured.revision
        or A.doc.name~=captured.name or A.doc.base~=captured.bytes or A.buffer:text()~=captured.bytes then return nil end
      local next_buffer=Buffer.new(text);if not next_buffer then return nil end
      local pos=math.min(A.buffer.pos,#text)
      while pos>0 and not next_buffer:is_boundary(pos)do pos=pos-1 end
      next_buffer:seek(pos)
      local backup=Docs.update_from_remote(c,captured.name,captured.bytes,text)
      if not backup then return nil end
      cancel_navigation();cancel_redraw()
      A.doc={name=captured.name,base=text};A.buffer=next_buffer;A.anchor=nil;A.top=0
      A.layout_revision=nil;A.layout_dirty_from=0;A.goal_x=nil;A.browsing=false
      A.recovery_doc=nil;A.recovery_revision=nil;A.dirty=false;A.save_failed=false;A.status='Saved on SD card'
      c.state.last=A.doc.name;c.state.cursor=pos
      local rec=Docs.load_recovery(c)
      if rec and rec.name==captured.name and rec.text==captured.bytes then Docs.call(c.storage,'remove','recovery.txt')end
      refresh_layout(c);c:invalidate()
      return true,backup
    end,
    snapshot=function(c,save_first)
      if A.blocked or not A.doc then return nil end
      if save_first and (A.dirty or A.doc.base==nil)and not save(c)then return nil end
      if A.dirty or A.doc.base==nil then return nil end
      local bytes=A.buffer:text()
      if bytes~=A.doc.base or Docs.read(c,A.doc.name)~=bytes then return nil end
      return {identity=A.doc,name=A.doc.name,revision=A.buffer.revision,bytes=bytes,saved=true,exists=true}
    end},A.ui_small,A.ui_medium)
  A.font_name="";A.font_px=A.large and 30 or 24
  A.spacing=(ctx.state.spacing==4 or ctx.state.spacing==14) and ctx.state.spacing or 8
  A.margin=(ctx.state.margin==40 or ctx.state.margin==56) and ctx.state.margin or 24
  local px=ctx.state.font_px
  if px==20 or px==24 or px==28 or px==30 or px==32 or px==36 then A.font_px=px end
  choose_font(ctx,"",A.font_px)
  A.buffer=assert(Buffer.new()); A.doc={name="untitled-001.md",base=nil}
  if not ctx.files or not ctx.input.listen then A.blocked=true; A.message="Update to Gancao firmware supporting XTApp API 2.11"; return end
  local listened,e=ctx.input:listen({keyboard=true})
  if not listened then A.blocked=true; A.message="Keyboard listener failed: "..tostring(e); return end
  local rec,err=Docs.load_recovery(ctx)
  if rec==nil then
    A.blocked=true; A.message="Recovery protected: "..tostring(err); A.view="files_help"; refresh_layout(ctx); return
  end
  if rec then
    local public,pe=Docs.read(ctx,rec.name)
    if public==rec.text then
      set_document(ctx,rec.name,public,public,false)
    elseif public or pe=="not_found" or pe:find("32 KiB",1,true) then
      local name,ne=Docs.fresh_name(ctx,"recovered")
      if not name then A.blocked=true; A.message="Recovery kept: "..tostring(ne); A.view="files_help"; refresh_layout(ctx); return end
      set_document(ctx,name,rec.text,nil,true)
      A.message="Recovered writing; Save creates a separate file."
    else
      A.blocked=true; A.message="Recovery kept: "..tostring(pe); A.view="files_help"; refresh_layout(ctx); return
    end
  elseif type(ctx.state.last)=="string" and Docs.name_ok(ctx.state.last) then
    local s,se=Docs.read(ctx,ctx.state.last)
    if s then
      set_document(ctx,ctx.state.last,s,s,false)
      local p=ctx.state.cursor
      if type(p)=="number" and p%1==0 and A.buffer:is_boundary(p) then A.buffer:seek(p) end
    elseif se=="not_found" then
      -- A missing remembered file is a stale preference, not a reason to
      -- lock every document. Detach it before allocating a fresh filename.
      ctx.state.last=nil;ctx.state.cursor=nil
      if new_document(ctx) then
        A.message="Previous file is missing; opened a new page."
      else
        A.blocked=true;A.view="files_help"
      end
    else
      -- Never turn a failed load into an empty overwrite of the same file.
      A.message="Last file not opened: "..tostring(se); A.view="files_help"; A.blocked=true
    end
  else new_document(ctx) end
  refresh_layout(ctx)
  ctx:set_tick(1000)
end
local function vertical(ctx,d,shift,page,browse)
  refresh_layout(ctx)
  local i=browse and 1 or Layout.caret_row(A.rows,A.buffer.pos)
  if not i then return end
  local l=geometry(ctx);local f=font(ctx);local b=A.buffer
  if not browse then A.goal_x=A.goal_x or f:measure(b:slice(A.rows[i].a,b.pos)) end
  local steps=page and math.max(1,l.count-1) or 1
  local function finish(row,edge)
    if browse then
      A.top=row.a;A.browsing=true;A.layout_revision=nil;A.touch_geometry=nil
      ctx:invalidate();return
    end
    row.text=row.text or b:slice(row.a,row.z)
    local p=edge or Layout.nearest(row,f,A.goal_x)
    if page or not Layout.caret_row(A.rows,p) then A.top=row.a;A.layout_revision=nil end
    move(ctx,p,shift)
  end
  local target=A.rows[i+d*steps]
  if target then finish(target);return end
  if d>0 then
    local rows=Layout.rows(b,f,l.w,A.rows[i].a,steps+1)
    if browse and A.rows[#A.rows].nextp>=b.size then return end
    finish(rows[math.min(#rows,steps+1)],#rows<=steps and b.size or nil)
    return
  end
  if A.rows[i].a==0 then finish(A.rows[i],0);return end
  if A.nav_job then
    A.nav_job.steps=math.min(64,A.nav_job.steps+steps);return
  end
  -- Reconstruct preceding visual rows in short timer slices. Keep only a
  -- bounded trailing ring, never a document-wide line index or string copy.
  local job={p=0,stop=A.rows[i].a,steps=steps,rows={},revision=b.revision,key=l.key,shift=shift,browse=browse}
  A.nav_job=job
  local scan
  scan=function(c)
    A.nav_timer=nil
    if A.nav_job~=job or A.buffer~=b or b.revision~=job.revision or geometry(c).key~=job.key or font(c)~=f then cancel_navigation();return end
    local rows=Layout.rows(b,f,l.w,job.p,8)
    for _,r in ipairs(rows) do
      if r.a>=job.stop then break end
      job.rows[#job.rows+1]={a=r.a,z=r.z,nextp=r.nextp}
      if #job.rows>64 then table.remove(job.rows,1) end
      job.p=r.nextp
      if job.p>=job.stop or r.nextp==r.a then break end
    end
    if job.p>=job.stop or #rows==0 then
      local row=job.rows[math.max(1,#job.rows-job.steps+1)]
      A.nav_job=nil
      if row then finish(row) end
    else
      A.nav_timer=c:after(1,scan)
      if not A.nav_timer then cancel_navigation();message(c,"Navigation unavailable; try again") end
    end
  end
  A.nav_timer=ctx:after(1,scan)
  if not A.nav_timer then cancel_navigation();message(ctx,"Navigation unavailable; try again") end
end
local function keyboard(ctx,ev)
  if A.view=="statistics" then
    if ev.phase=="down" then
      if ev.code=="Escape" then A.view="editor"
      elseif ev.code=="ArrowRight" or ev.code=="ArrowDown" then A.stats_mode=A.stats_mode%3+1
      elseif ev.code=="ArrowLeft" or ev.code=="ArrowUp" then A.stats_mode=(A.stats_mode+1)%3+1 end
      ctx:invalidate()
    end
    return true
  end
  local code=ev.code; local mods=ev.mods or {}; local down=ev.phase=="down"
  if (mods.ctrl or mods.meta) and not mods.alt then code=A.keyboard:shortcut(code) end
  if A.close_modal then
    if not down then return true end
    if code=="Escape" then close_choice(ctx,1)
    elseif code=="ArrowLeft" or code=="ArrowUp" then A.close_modal.choice=math.max(1,A.close_modal.choice-1);ctx:invalidate()
    elseif code=="ArrowRight" or code=="ArrowDown" then A.close_modal.choice=math.min(A.close_modal.dirty and 3 or 2,A.close_modal.choice+1);ctx:invalidate()
    elseif code=="Enter" then close_choice(ctx,A.close_modal.choice) end
    return true
  end
  if A.view=="delete_confirm" then
    if not down then return true end
    if code=="Escape" then A.confirm_file=nil;A.view="library"
    elseif code=="ArrowLeft" or code=="ArrowUp" then A.confirm_choice=1
    elseif code=="ArrowRight" or code=="ArrowDown" then A.confirm_choice=2
    elseif code=="Enter" then if A.confirm_choice==2 then confirm_delete(ctx) else A.confirm_file=nil;A.view="library" end end
    ctx:invalidate();return true
  end
  -- Keyboard-only access; Fn itself is not exposed by the host.
  local shortcut = (mods.ctrl or mods.meta) and not mods.alt
  local help_key = (code=="F1" and not mods.ctrl and not mods.meta and not mods.alt and not mods.shift)
    or (code=="KeyH" and shortcut and not mods.shift)
  if help_key and (A.view=="editor" or A.view=="help") then
    if down then
      cancel_navigation();cancel_redraw();A.keyboard:reset();A.typing_time=nil
      A.panel=nil;A.action_focus=nil;A.virtual=nil
      if A.view=="help" then A.view="editor" else A.view="help";A.help_page=1 end
      ctx:invalidate()
    end
    return true
  end
  if A.view=='editor'and code=='KeyG'and shortcut and not mods.shift then
    if down then
      cancel_navigation();cancel_redraw();A.keyboard:reset();A.typing_time=nil;A.panel=nil;A.action_focus=nil
      A.sync:sync_document(ctx)
    end
    return true
  end
  if A.view=="editor" and code=="KeyT" and shortcut and mods.shift then
    if down then
      cancel_navigation();cancel_redraw();A.keyboard:reset();A.typing_time=nil
      if A.focus_mode then command(ctx,11) end
      A.virtual=nil;A.panel=nil;A.action_focus=1;A.layout_revision=nil
      ctx:invalidate()
    end
    return true
  end
  if A.view=="editor" and (A.panel or A.action_focus) and not (code=="KeyF" and mods.shift and (mods.ctrl or mods.meta)) then
    if ev.phase=="up" then return true end
    if code=="Escape" and down then A.panel=nil;A.action_focus=nil;ctx:invalidate()
    elseif code=="ArrowLeft" or code=="ArrowUp" then A.action_focus=math.max(1,(A.action_focus or 5)-1);ctx:invalidate()
    elseif code=="ArrowRight" or code=="ArrowDown" then A.action_focus=math.min(A.panel=="settings" and 9 or A.panel=="new" and 7 or 4,(A.action_focus or 4)+1);ctx:invalidate()
    elseif code=="Enter" and down then chrome_action(ctx,A.action_focus or 5) end
    return true
  end
  A.keyboard:modifier(ev)
  if ev.phase=="up" then return true end
  if not down and ev.phase~="repeat" then return true end
  local edit_or_move=ev.text or code=="ArrowLeft" or code=="ArrowRight" or code=="ArrowUp" or code=="ArrowDown" or code=="Home" or code=="End" or code=="PageUp" or code=="PageDown" or code=="Backspace" or code=="Delete" or code=="Enter" or code=="Tab" or ((mods.ctrl or mods.meta) and (code=="KeyA" or code=="KeyX" or code=="KeyV" or code=="KeyB" or code=="KeyI" or code=="KeyZ" or code=="KeyK" or code=="KeyL" or code=="Quote" or code:match("^Digit[0-6]$")))
  if A.view=="editor" and A.browsing and edit_or_move then
    A.browsing=false;A.layout_revision=nil;cancel_navigation()
  end
  local vertical_key=code=="ArrowUp" or code=="ArrowDown" or code=="PageUp" or code=="PageDown"
  if A.nav_job and A.nav_job.shift~=mods.shift then cancel_navigation() end
  if not vertical_key or mods.ctrl or mods.meta then cancel_navigation();A.goal_x=nil
  elseif A.nav_job and (code=="ArrowDown" or code=="PageDown") then cancel_navigation() end
  local plain=A.view=="editor" and not mods.ctrl and not mods.meta and not mods.alt and ev.text and #ev.text==1 and ev.text:byte()>=32 and ev.text:byte()<=126
  if not plain then A.typing_time=nil end
  if A.view=="editor" and not A.blocked then
    local text,handled,accent=A.keyboard:feed(ev,A.caps)
    if handled then
      if text then
        if A.browsing then A.browsing=false;A.layout_revision=nil end
        insert(ctx,text,true)
      end
      if accent then
        local a,z=selection();local prev=A.buffer:previous(a)
        local composed=a==z and Keyboard.accent(A.buffer:slice(prev,a),accent)
        A.typing_time=nil
        if composed then
          local ok,e=A.buffer:replace(prev,a,composed)
          if ok then A.anchor=nil;changed(ctx,prev) else message(ctx,e) end
        else insert(ctx,accent) end
      end
      return true
    elseif not A.keyboard.pending and A.message and A.message:sub(1,7)=="Accent:" then A.message=nil end
  end
  if code=="CapsLock" and down then A.caps=not A.caps; ctx:invalidate(); return true end
  if code=="Escape" and down then
    if A.view=="editor" then menu(ctx) else A.view="editor"; ctx:invalidate() end
    return true
  end
  if code=="KeyF" and mods.shift and (mods.ctrl or mods.meta) and not mods.alt then
    if down then command(ctx,11) end
    return true
  end
  if A.view=="typography" then
    local cs=geometry(ctx).type_controls;A.type_focus=math.max(1,math.min(#cs,A.type_focus or 1))
    if code=="ArrowUp" or code=="ArrowLeft" then A.type_focus=math.max(1,A.type_focus-1)
    elseif code=="ArrowDown" or code=="ArrowRight" then A.type_focus=math.min(#cs,A.type_focus+1)
    elseif code=="Enter" and down then type_control(ctx,cs[A.type_focus]) end
    ctx:invalidate();return true
  end
  if A.view~="editor" then
    if A.view=="menu" or A.view=="library" or A.view=="typography" or A.view=="fonts" or A.view=="layouts" then
      local rows=list_rows()
      if #rows==0 then return true end
      if A.view=="library" then
        if code=="ArrowRight" then A.file_action=math.min(3,(A.file_action or 1)+1);ctx:invalidate();return true
        elseif code=="ArrowLeft" then A.file_action=math.max(1,(A.file_action or 1)-1);ctx:invalidate();return true
        elseif code=="Enter" and down and (A.file_action or 1)>1 then file_action(ctx,A.file_action==2 and "rename" or "delete");return true end
      end
      if code=="ArrowDown" then A.focus=math.min(#rows,A.focus+1)
      elseif code=="ArrowUp" then A.focus=math.max(1,A.focus-1)
      elseif code=="PageDown" or code=="ArrowRight" then A.focus=math.min(#rows,A.focus+geometry(ctx).per)
      elseif code=="PageUp" or code=="ArrowLeft" then A.focus=math.max(1,A.focus-geometry(ctx).per)
      elseif code=="Enter" and down then
        activate(ctx,A.focus)
      end
      ctx:invalidate()
    elseif A.view=="help" or A.view=="files_help" or A.view=="orientation_help" or A.view=="font_help" then
      local d=(code=="ArrowDown" or code=="ArrowRight" or code=="PageDown") and 1 or (code=="ArrowUp" or code=="ArrowLeft" or code=="PageUp") and -1 or 0
      A.help_page=math.max(1,math.min(A.help_pages or 1,(A.help_page or 1)+d));ctx:invalidate()
    end
    return true
  end
  if A.blocked then return true end
  if (mods.ctrl or mods.meta) and not mods.alt then
    if code=="ArrowLeft" or code=="ArrowRight" then
      move(ctx,A.buffer:word(A.buffer.pos,code=="ArrowLeft" and -1 or 1),mods.shift);return true
    end
    if not down then return true end
    if code=="KeyS" then save(ctx)
    elseif code=="KeyJ" then today(ctx)
    elseif code=="KeyN" then new_document(ctx)
    elseif code=="KeyO" then library(ctx)
    elseif code=="KeyR" then cancel_redraw(); ctx:invalidate("full")
    elseif code=="KeyC" then clipboard(ctx,false)
    elseif code=="KeyX" then clipboard(ctx,true)
    elseif code=="KeyV" then
      if A.clipboard then insert(ctx,A.clipboard) else message(ctx,"inkWrite clipboard is empty") end
    elseif code=="KeyB" or code=="KeyI" then
      markdown_action(ctx,function() format(ctx,code=="KeyB" and "**" or "*") end)
    elseif code=="KeyK" then
      markdown_action(ctx,function() link(ctx) end)
    elseif code=="KeyL" then
      markdown_action(ctx,function() markers(ctx,"bullet") end)
    elseif code=="Quote" then
      markdown_action(ctx,function() markers(ctx,"quote") end)
    elseif code=="Digit0" or code=="Digit1" or code=="Digit2" or code=="Digit3"
      or code=="Digit4" or code=="Digit5" or code=="Digit6" then
      local level=tonumber(code:sub(6))
      markdown_action(ctx,function() markers(ctx,"heading",level) end)
    elseif code=="KeyA" then A.anchor=0; move(ctx,A.buffer.size,true)
    elseif code=="KeyZ" then
      local ok,e=A.buffer:undo_edit(mods.shift); A.anchor=nil
      if ok then changed(ctx) elseif e then message(ctx,e) end
    elseif code=="Home" then move(ctx,0,mods.shift)
    elseif code=="End" then move(ctx,A.buffer.size,mods.shift)
    end
    return true
  end
  local b=A.buffer
  if code=="ArrowLeft" then move(ctx,b:previous(),mods.shift)
  elseif code=="ArrowRight" then move(ctx,b:following(),mods.shift)
  elseif code=="ArrowUp" then vertical(ctx,-1,mods.shift)
  elseif code=="ArrowDown" then vertical(ctx,1,mods.shift)
  elseif code=="PageUp" then vertical(ctx,-1,mods.shift,true)
  elseif code=="PageDown" then vertical(ctx,1,mods.shift,true)
  elseif code=="Home" or code=="End" then
    refresh_layout(ctx); local r=A.rows[Layout.caret_row(A.rows,b.pos) or 1]
    move(ctx,r and (code=="Home" and r.a or r.z) or b.pos,mods.shift)
  elseif code=="Backspace" or code=="Delete" then
    local a,z=selection()
    if a==z then if code=="Backspace" then a=b:previous() else z=b:following() end end
    local ok,e=b:replace(a,z,""); A.anchor=nil
    if ok then changed(ctx,a) else message(ctx,e) end
  elseif code=="Enter" then insert(ctx,"\n")
  elseif code=="Tab" then insert(ctx,"    ")
  elseif not mods.alt and ev.text and #ev.text==1 and ev.text:byte()>=32 and ev.text:byte()<=126 then
    local s=ev.text
    if A.caps and code and code:match("^Key[A-Z]$") then s=mods.shift and s:lower() or s:upper() end
    insert(ctx,s,true)
  end
  return true
end
-- Scan at most the bounded document in small chunks; no document snapshot.
local function text_span(buffer,p,sentence)
  local function stop(c)
    if sentence then return c=="." or c=="!" or c=="?" or c=="\n" or c=="。" or c=="！" or c=="？" or c=="…" end
    return c:match("%s") or (#c==1 and c:match("%p") and c~="'" and c~="-") or c=="—" or c=="–" or c=="“" or c=="”"
  end
  local a,z=p,p
  while a>0 do
    local first=math.max(0,a-1024);while not buffer:is_boundary(first) do first=first+1 end
    local chunk=buffer:slice(first,a);local positions={}
    for i in utf8.codes(chunk) do positions[#positions+1]=i end
    local hit=false
    for i=#positions,1,-1 do
      local c=chunk:sub(positions[i],(positions[i+1] or #chunk+1)-1)
      if stop(c) then hit=true;break end
      a=first+positions[i]-1
    end
    if hit or a==first and first==0 then break end
  end
  while z<buffer.size do
    local last=math.min(buffer.size,z+1024);while not buffer:is_boundary(last) do last=last-1 end
    local chunk=buffer:slice(z,last);local base=z;local hit=false
    for i,cp in utf8.codes(chunk) do
      local following=utf8.offset(chunk,2,i) or #chunk+1;local c=chunk:sub(i,following-1)
      if stop(c) then if sentence then z=base+following-1 end;hit=true;break end
      z=base+following-1
    end
    if hit or z==last and last==buffer.size then break end
  end
  if sentence then
    while a<z do local nextp=buffer:following(a);if not buffer:slice(a,nextp):match("%s") then break end;a=nextp end
  end
  return a,z
end
local function language_geometry(ctx)
  local o=ctx.screen.occlusion or {};local top=(o.top or 0)+70
  local bottom=ctx.screen.height-(o.bottom or 0)-(A.virtual and 264 or 20)
  local per=math.max(1,(bottom-top-48)//48)
  local first=((A.language_focus-1)//per)*per+1
  return top,per,first
end
local function language_popup(ctx)
  cancel_navigation();A.panel=nil;A.action_focus=nil;A.languages=true;A.language_focus=1;A.typing_time=nil
  for i,id in ipairs(A.enabled_ids) do if id==A.keyboard.id then A.language_focus=i end end
  ctx:invalidate()
end
local function language_pick(ctx,i)
  if i==#A.enabled_ids+1 then
    cancel_navigation();A.keyboard:reset();A.languages=nil;A.panel=nil;A.action_focus=nil
    A.view="layouts";A.focus=1;A.typing_time=nil;ctx:invalidate();return
  end
  if not A.enabled_ids[i] then return end
  select_keyboard(ctx,A.enabled_ids[i])
  A.languages=nil;A.national_page=nil;A.virtual_focus=nil;A.typing_time=nil;ctx:invalidate()
end
local function virtual_keys(ctx)
  local profile=Keyboard.virtual(A.keyboard.id);local a1,a2=profile.accents[1],profile.accents[2]
  local letters={};local source=A.virtual_shift and profile.upper or profile.chars
  for _,cp in utf8.codes(source) do letters[#letters+1]=utf8.char(cp) end
  local national={};local page=(A.national_page or 0)%math.max(1,(#letters+8)//9)
  for i=page*9+1,math.min(#letters,page*9+9) do national[#national+1]=letters[i] end
  if #letters>9 then national[#national+1]="More" end
  local rows={{"Hide","1","2","3","4","5","6","7","8","9","0","Del"},national,{"q","w","e","r","t","y","u","i","o","p"},{"a","s","d","f","g","h","j","k","l",a1},{"Shift","z","x","c","v","b","n","m",a2},{"123","Space",".",","}}
  if A.keyboard.id=="fr" then rows[3]={"a","z","e","r","t","y","u","i","o","p"};rows[4]={"q","s","d","f","g","h","j","k","l","m"};rows[5]={"Shift","w","x","c","v","b","n",a1,a2} end
  if A.symbols then rows[3]={"!","@","#","$","%","^","&","*","(",")"};rows[4]={"-","_","=","+","/","?",":",";","'",'"'} end
  local o=ctx.screen.occlusion or {};local left=o.left or 0;local width=ctx.screen.width-left-(o.right or 0)
  local top=ctx.screen.height-(o.bottom or 0)-264;local keys={}
  local function add(label,x,y,w,h) keys[#keys+1]={x=x,y=y,w=w,h=h,label=label} end
  for row,values in ipairs(rows) do
    local usable=row>=5 and width*9//10 or width
    for col,raw_label in ipairs(values) do
      local label=raw_label=="ẞ" and "SS" or raw_label
      if (A.keyboard.id=="cz" or A.keyboard.id=="sk" or A.keyboard.id=="de") then if label=="y" then label="z" elseif label=="z" then label="y" end end
      if row~=2 and A.virtual_shift and #label==1 then label=label:upper() end
      local x=left+(col-1)*usable//#values;local right=left+col*usable//#values
      if row==1 then
        -- Wide corner controls; the ten digits share the remaining eight units.
        local unit=width//12
        if col==1 then x=left;right=left+unit*2
        elseif col==12 then x=left+unit*10;right=left+width
        else x=left+unit*2+(col-2)*(width-unit*4)//10;right=left+unit*2+(col-1)*(width-unit*4)//10 end
      elseif row==6 then
        local edges={0,15,70,85,100};x=left+usable*edges[col]//100;right=left+usable*edges[col+1]//100
      end
      add(label,x,top+(row-1)*44,right-x,44)
    end
  end
  add("Enter",left+width*9//10,top+176,width-width*9//10,88)
  return keys,top
end
local function virtual_press(ctx,label)
  if A.blocked and label~="Hide" and label~="Lang" and label~="Shift" and label~="123" and label~="More" then message(ctx,"Files are protected");return end
  if label=="Hide" then A.virtual=nil;A.layout_revision=nil
  elseif label=="Lang" then language_popup(ctx)
  elseif label=="Shift" then A.virtual_shift=not A.virtual_shift
  elseif label=="More" then A.national_page=(A.national_page or 0)+1
  elseif label=="123" then A.symbols=not A.symbols
  elseif label=="Del" then keyboard(ctx,{code="Backspace",phase="down",mods={}})
  elseif label=="Enter" then keyboard(ctx,{code="Enter",phase="down",mods={}})
  elseif Keyboard.virtual_accent(A.keyboard.id,label) then
    local a,z=selection();local prev=A.buffer:previous(a);local composed=a==z and Keyboard.accent(A.buffer:slice(prev,a),label)
    A.typing_time=nil
    if composed then local ok,e=A.buffer:replace(prev,a,composed);if ok then A.anchor=nil;changed(ctx,prev) else message(ctx,e) end
    else insert(ctx,label) end
  else insert(ctx,label=="Space" and " " or label);A.virtual_shift=nil end
  ctx:invalidate()
end
function M.input(ctx,ev)
  if A.sync and A.sync.active then return A.sync:input(ctx,ev)end
  if A.file_job or A.file_dialog then return true end
  if ev.type=="pointer" and (type(ev.x)~="number" or type(ev.y)~="number" or ev.x~=ev.x or ev.y~=ev.y or ev.x<0 or ev.y<0 or ev.x>=ctx.screen.width or ev.y>=ctx.screen.height) then return true end
  -- Notices belong to the action that produced them. Dismiss on the next
  -- deliberate action, not on pointer movement or the trailing key release.
  -- Save/protection state stays independent and is still shown in the chrome.
  local action=ev.type=="pointer" and ev.phase=="up" or ev.type=="key" and (ev.phase=="down" or ev.phase=="repeat" or ev.key=="back" and ev.phase=="up")
  if action and A.message then A.message=nil;ctx:invalidate() end
  if A.close_modal then
    if ev.type=="key" and ev.source~="keyboard" then
      if ev.key=="back" and ev.phase=="up" then close_choice(ctx,1)
      elseif ev.phase=="down" then local codes={up="ArrowUp",down="ArrowDown",left="ArrowLeft",right="ArrowRight",ok="Enter"};if codes[ev.key] then keyboard(ctx,{code=codes[ev.key],phase="down",mods={}}) end end
    elseif ev.type=="key" then keyboard(ctx,ev)
    elseif ev.type=="pointer" and ev.phase=="up" and ev.gesture=="tap" then
      local r=close_rect(ctx);local count=A.close_modal.dirty and 3 or 2
      if ev.x>=r.x and ev.x<r.x+r.w and ev.y>=r.y+126 and ev.y<r.y+178 then close_choice(ctx,math.min(count,(ev.x-r.x)//(r.w//count)+1)) end
    end
    return true
  end
  if ev.type=="key" and ev.source=="keyboard" and A.view~="delete_confirm" then
    local code=ev.code;local mods=ev.mods or {};local down=ev.phase=="down"
    if code=="AltRight" then A.right_alt=ev.phase~="up" end
    -- The modifier snapshot can identify Alt even if its separate down was
    -- missed (for example when the keyboard reconnected while Alt was held).
    if ev.phase=="up" and (code=="ShiftLeft" or code=="ShiftRight" or code=="AltLeft") then A.layout_chord=nil end
    if down and not mods.ctrl and not mods.meta and not A.right_alt and
        ((code=="ShiftLeft" or code=="ShiftRight") and mods.alt or code=="AltLeft" and mods.shift) then
      if not A.layout_chord then A.layout_chord=true;cycle_keyboard(ctx) end
      return true
    end
    if code=="Space" and mods.ctrl and not mods.alt and not mods.meta and not mods.shift then
      if down then cycle_keyboard(ctx) end;return true
    end
    if code=="KeyS" and mods.ctrl and mods.shift and not mods.alt and not mods.meta then
      if down then toggle_orientation(ctx) end;return true
    end
  end
  if A.languages then
    if ev.type=="key" then
      if (ev.key=="back" and ev.phase=="up") or (ev.code=="Escape" and ev.phase=="down") then A.languages=nil;ctx:invalidate()
      elseif ev.phase=="down" then
        if ev.key=="down" or ev.code=="ArrowDown" then A.language_focus=math.min(#A.enabled_ids+1,A.language_focus+1)
        elseif ev.key=="up" or ev.code=="ArrowUp" then A.language_focus=math.max(1,A.language_focus-1)
        elseif ev.key=="left" or ev.code=="ArrowLeft" or ev.code=="PageUp" then local _,per=language_geometry(ctx);A.language_focus=math.max(1,A.language_focus-per)
        elseif ev.key=="right" or ev.code=="ArrowRight" or ev.code=="PageDown" then local _,per=language_geometry(ctx);A.language_focus=math.min(#A.enabled_ids+1,A.language_focus+per)
        elseif ev.key=="ok" or ev.code=="Enter" then language_pick(ctx,A.language_focus) end
        ctx:invalidate()
      end
    elseif ev.type=="pointer" and ev.phase=="up" then
      local top,per,first=language_geometry(ctx);local row=(ev.y-top)//48+1
      if ev.gesture=="tap" and ev.x>=20 and ev.x<ctx.screen.width-20 and row>=1 and row<=per and first+row-1<=#A.enabled_ids+1 then language_pick(ctx,first+row-1)
      elseif ev.gesture=="tap" and row==per+1 and #A.enabled_ids+1>per then
        A.language_focus=math.max(1,math.min(#A.enabled_ids+1,A.language_focus+(ev.x<ctx.screen.width//2 and -per or per)));ctx:invalidate()
      else A.languages=nil;ctx:invalidate() end
    end
    return true
  end
  if A.virtual and A.view=="editor" and ev.type=="key" and ev.source~="keyboard" and ev.key~="back" then
    if ev.phase=="down" then
      local keys=virtual_keys(ctx);A.virtual_focus=A.virtual_focus or 1
      if ev.key=="right" then A.virtual_focus=math.min(#keys,A.virtual_focus+1)
      elseif ev.key=="left" then A.virtual_focus=math.max(1,A.virtual_focus-1)
      elseif ev.key=="down" then A.virtual_focus=math.min(#keys,A.virtual_focus+10)
      elseif ev.key=="up" then A.virtual_focus=math.max(1,A.virtual_focus-10)
      elseif ev.key=="ok" then virtual_press(ctx,keys[A.virtual_focus].label) end
      ctx:invalidate()
    end
    return true
  end
  if A.virtual and A.view=="editor" and ev.type=="key" and (ev.key=="back" or ev.code=="Escape") then
    if (ev.key=="back" and ev.phase=="up") or (ev.code=="Escape" and ev.phase=="down") then A.virtual=nil;A.layout_revision=nil;ctx:invalidate() end
    return true
  end
  if ev.type=="pointer" and A.view=="editor" then
    if ev.phase=="down" then A.pointer_down_y=ev.y;A.pointer_down_x=ev.x end
    local down_x=ev.down_x or A.pointer_down_x
    if ev.phase=="up" or ev.phase=="cancel" then A.pointer_down_x=nil end
    if ev.phase=="up" and ev.gesture=="swipe_right" and down_x and down_x>=0 and down_x<32 then
      A.text_tap=nil;A.virtual=nil;command(ctx,7);return true
    end
    if ev.phase=="up" and ev.gesture=="swipe_left" and down_x and down_x>=ctx.screen.width-32 and down_x<ctx.screen.width then
      A.text_tap=nil;command(ctx,15);return true
    end
    local top=(ctx.screen.occlusion or {}).top or 0
    local status_y=top+(A.focus_mode and 20 or 50)
    local l=geometry(ctx)
    local in_text=ev.x>=l.x and ev.x<l.right and ev.y>=l.body and ev.y<l.text_bottom and not A.panel and not A.action_focus
    if ev.phase=="up" then
      if (ev.gesture=="tap" or ev.gesture=="double_tap") and in_text then
        if A.touch_revision~=A.buffer.revision or A.touch_doc~=A.doc or A.touch_font~=font(ctx) or A.touch_geometry~=l.key then A.text_tap=nil
        else
          local index=(ev.y-l.body)//l.step+1;local row=A.touch_rows and A.touch_rows[index]
          local p,word
          if row and ev.x-l.x<font(ctx):measure(row.text) then
            p=Layout.nearest(row,A.touch_font,ev.x-l.x)
            if p>row.a and font(ctx):measure(A.buffer:slice(row.a,p))>ev.x-l.x then p=A.buffer:previous(p) end
            local c=A.buffer:slice(p,A.buffer:following(p));word=c~="" and not c:match("%s")
          end
          local t=type(ev.time_ms)=="number" and ev.time_ms or now(ctx);local last=A.text_tap
          local consecutive=last and age(t,last.time)<=1200 and math.abs(ev.x-last.x)<=28 and math.abs(ev.y-last.y)<=28 and last.doc==A.doc and last.revision==A.buffer.revision and last.geometry==l.key and last.font==font(ctx) and last.top==A.top
          local count=consecutive and last.count+1 or (ev.gesture=="double_tap" and 2 or 1)
          if consecutive then p=last.p;word=last.word end
          A.text_tap={time=t,x=consecutive and last.x or ev.x,y=consecutive and last.y or ev.y,doc=A.doc,revision=A.buffer.revision,geometry=l.key,font=font(ctx),word=word,p=p,top=A.top,count=count}
          if count==2 and not word then A.text_tap=nil;command(ctx,11);return true
          elseif word and (count==2 or count==3) and not A.blocked then
            local a,z=text_span(A.buffer,p,count==3)
            A.anchor=a;A.buffer:seek(z);A.browsing=false;A.typing_time=nil;cancel_navigation();cancel_redraw();ctx:invalidate()
            if count==3 then A.text_tap=nil end
            return true
          end
        end
      else A.text_tap=nil end
    end
    if ev.phase=="up" and ev.gesture=="tap" then
      local ui=A.ui_small
      local left=math.max(l.chrome_left,l.chrome_right-math.max(80,ui:measure(tostring(A.buffer.words))+36))
      if ev.x>=left and ev.x<=l.chrome_right and ev.y>=status_y-20 and ev.y<status_y+20 then
        A.text_tap=nil;command(ctx,15);return true
      end
    end
    if ev.phase=="up" and ev.gesture=="tap" and ev.x>=20 and ev.x<110 and ev.y>=status_y-20 and ev.y<status_y+20 then language_popup(ctx);return true end
    if ev.phase=="up" and ev.gesture=="swipe_up" and (ev.down_y or A.pointer_down_y or -1)>=ctx.screen.height-32 then
      A.virtual=true;A.panel=nil;A.action_focus=nil;A.layout_revision=nil;A.pointer_down_y=nil;ctx:invalidate();return true
    end
    if A.virtual then
      local keys,top=virtual_keys(ctx)
      if ev.phase=="up" and ev.gesture=="swipe_down" and (ev.down_y or A.pointer_down_y or -1)>=top then
        A.virtual=nil;A.pointer_down_y=nil;A.layout_revision=nil;ctx:invalidate();return true
      end
      if ev.y>=top then
        if ev.phase=="up" and ev.gesture=="tap" then
          for _,r in ipairs(keys) do if ev.x>=r.x and ev.x<r.x+r.w and ev.y>=r.y and ev.y<r.y+r.h then virtual_press(ctx,r.label);break end end
        end
        return true
      end
    end
  end
  if ev.type=="key" then A.text_tap=nil end
  if A.view=="statistics" and ev.type=="pointer" and ev.phase=="up" and ev.gesture=="tap" then
    local l=geometry(ctx)
    if ev.y>=l.body and ev.y<l.body+44 and ev.x>=l.x and ev.x<l.right then A.stats_mode=math.min(3,(ev.x-l.x)*3//l.w+1);ctx:invalidate();return true end
  end
  if ev.type=="key" and ev.source=="keyboard" then return keyboard(ctx,ev) end
  A.typing_time=nil
  if ev.type=="pointer" then cancel_navigation();A.goal_x=nil end
  if ev.type=="key" then
    if ev.key=="back" then
      if ev.phase=="up" then
        if A.view=="delete_confirm" then A.confirm_file=nil;A.view="library";ctx:invalidate()
        elseif A.view=="editor" and A.focus_mode then command(ctx,11)
        elseif A.view=="editor" and (A.panel or A.action_focus) then A.panel=nil;A.action_focus=nil;ctx:invalidate()
        elseif A.view=="editor" then close_request(ctx) else A.view="editor"; ctx:invalidate() end
      end
      return true
    end
    if ev.phase~="down" then return true end
    if A.view=="editor" then
      if A.focus_mode and ev.key=="ok" then command(ctx,11);A.action_focus=1
      elseif A.action_focus or A.panel then
        local codes={up="ArrowUp",down="ArrowDown",left="ArrowLeft",right="ArrowRight",ok="Enter"}
        if codes[ev.key] then keyboard(ctx,{code=codes[ev.key],phase="down",mods={}}) end
      elseif ev.key=="ok" then A.action_focus=1;ctx:invalidate()
      elseif ev.key=="up" or ev.key=="down" then
        A.browsing=false;A.layout_revision=nil;cancel_navigation()
        vertical(ctx,ev.key=="up" and -1 or 1,false)
      end
    else
      local codes={up="ArrowUp",down="ArrowDown",left="ArrowLeft",right="ArrowRight",ok="Enter"}
      if codes[ev.key] then keyboard(ctx,{code=codes[ev.key],phase="down",mods={}}) end
    end
    return true
  end
  if ev.type=="pointer" and A.view=="editor" then
    local l=geometry(ctx)
    if type(ev.x)~="number" or type(ev.y)~="number" or ev.x<0 or ev.y<0 or ev.x>=ctx.screen.width or ev.y>=ctx.screen.height then return true end
    if ev.phase=="hold" and A.focus_mode and ev.x>=l.x and ev.x<=l.right and ev.y>=l.body and ev.y<l.text_bottom then command(ctx,11);return true end
    local top=(ctx.screen.occlusion or {}).top or 0
    if not A.focus_mode and ev.phase=="up" and ev.gesture=="tap" and ev.x>=l.chrome_right-44 and ev.x<l.chrome_right and ev.y>=top and ev.y<top+40 then close_request(ctx);return true end
    if ev.phase=="up" and ev.gesture=="tap" and l.controls then
      for i,r in ipairs(l.controls) do
        if ev.x>=r.x and ev.x<r.x+r.w and ev.y>=r.y and ev.y<r.y+r.h then chrome_action(ctx,i);return true end
      end
      if A.panel then A.panel=nil;A.action_focus=nil;ctx:invalidate();return true end
      A.action_focus=nil
    elseif A.panel or A.action_focus then return true end
  end
  if ev.type=="pointer" and ev.phase=="up" and (ev.gesture=="swipe_up" or ev.gesture=="swipe_down") then
    local l=geometry(ctx);local x,y=ev.down_x or ev.x,ev.down_y or ev.y
    if A.view=="editor" and not A.blocked and x>=l.x and x<=l.right and y>=l.body and y<l.text_bottom then
      if A.touch_revision~=A.buffer.revision or A.touch_doc~=A.doc or A.touch_font~=font(ctx) or A.touch_geometry~=l.key then
        message(ctx,"Text is updating; swipe again after it refreshes")
      else
        A.browsing=true;vertical(ctx,ev.gesture=="swipe_up" and 1 or -1,false,true,true)
      end
    end
    return true
  end
  if ev.type=="pointer" and ev.phase=="up" and ev.gesture=="tap" then
    local l=geometry(ctx)
    if A.view~="editor" and ev.y>=l.dock and ev.y<l.dock+66 then
      if ev.x<l.chrome_left+100 then A.confirm_file=nil;A.view=A.view=="delete_confirm" and "library" or "editor";ctx:invalidate()
      elseif A.view~="delete_confirm" then
        local rows=list_rows();local d=ev.x<l.chrome_left+210 and -1 or ev.x>l.chrome_right-100 and 1 or 0
        if A.view=="menu" or A.view=="library" or A.view=="typography" or A.view=="fonts" or A.view=="layouts" then A.focus=math.max(1,math.min(math.max(1,#rows),A.focus+d*l.per))
        else A.help_page=math.max(1,math.min(A.help_pages or 1,(A.help_page or 1)+d)) end
        ctx:invalidate()
      end
    elseif A.view=="delete_confirm" then
      if ev.y>=l.body+160 and ev.y<l.body+212 then
        if ev.x<l.x+l.w//2 then A.confirm_file=nil;A.view="library";ctx:invalidate() else confirm_delete(ctx) end
      end
    elseif A.view=="typography" then
      for i,c in ipairs(l.type_controls) do if ev.x>=c.x and ev.x<c.x+c.w and ev.y>=c.y and ev.y<c.y+c.h then A.type_focus=i;type_control(ctx,c);break end end
    elseif A.view=="menu" or A.view=="library" or A.view=="fonts" or A.view=="layouts" then
      local row=(ev.y-l.body)//l.row+1
      local per=l.per
      local first=((A.focus-1)//per)*per+1
      local i=first+row-1; local rows=list_rows()
      if ev.y>=l.body and ev.y<l.list_bottom and row<=per and rows[i] then
        A.focus=i
        if A.view=="library" then
          local rename,delete,size=file_cells(ctx,l,rows[i])
          if ev.x>=rename and ev.x<delete then file_action(ctx,"rename")
          elseif ev.x>=delete and ev.x<l.right then file_action(ctx,"delete")
          else activate(ctx,i) end
        else activate(ctx,i) end
      end
    elseif A.view=="editor" and not A.blocked and ev.x>=l.x and ev.x<=l.right and ev.y>=l.body and ev.y<l.foot then
      -- A tap refers to the text most recently drawn. Do not reinterpret it
      -- against queued, not-yet-drawn edits or a different font/document.
      if A.touch_revision~=A.buffer.revision or A.touch_doc~=A.doc or A.touch_font~=font(ctx) or A.touch_geometry~=l.key then
        message(ctx,"Text is updating; tap again after it refreshes")
      elseif A.touch_rows and #A.touch_rows>0 then
        local tapped=(ev.y-l.body)//l.step+1
        local i=math.min(#A.touch_rows,tapped)
        local row=A.touch_rows[i]
        local p=tapped>#A.touch_rows and row.z or Layout.nearest(row,A.touch_font,ev.x-l.x)
        if A.buffer:is_boundary(p) then
          A.browsing=false;A.anchor=nil;A.buffer:seek(p);cancel_redraw();ctx:invalidate()
        end
      end
    end
    return true
  end
  return false
end
function M.tick(ctx)
  if A.sync and A.sync.active then A.sync:tick(ctx);return end
  -- The idle tick is the only place the statistics checkpoint and autosave may
  -- write to SD, so a burst of typing never waits for a file write.
  local t=now(ctx)
  local quiet=not A.last_key or age(t,A.last_key)>=QUIET_MS
  -- A pause starts a fresh full-refresh allowance.
  if quiet then A.typing_run=nil end
  -- A checkpoint still happens eventually during a marathon session, so a power
  -- loss can never discard more than a few minutes of statistics.
  local due=A.stats.saved and age(t,A.stats.saved)>=STATS_FORCE_MS
  A.stats:tick(ctx,quiet or (due and true) or false)
  if A.close_modal then return end
  if A.dirty and not A.blocked and not A.save_failed then
    local forced=A.first_dirty and age(t,A.first_dirty)>=SAVE_FORCE_MS
    if (quiet and age(t,A.last_edit)>=5000) or forced then save(ctx) end
  end
end
-- A successful snapshot already protects this exact document revision.
-- Retain only its identity, never another full copy of the document text.
local function checkpoint_recovery(ctx)
  if A.recovery_doc==A.doc and A.recovery_revision==A.buffer.revision then return true end
  local ok,result=pcall(function() return Docs.recovery(ctx,A.doc.name,A.buffer:text()) end)
  if ok and result then A.recovery_doc=A.doc;A.recovery_revision=A.buffer.revision;return true end
  return false
end
function M.pause(ctx)
  if A.sync then A.sync:pause(ctx)end
  A.right_alt=nil;A.layout_chord=nil
  extend_budget(ctx)
  if A.prepare_timer then A.prepare_timer:cancel();A.prepare_timer=nil end
  A.stats:pause(ctx)
  if A.file_job then A.file_job:cancel();A.file_job=nil;A.message="Rename interrupted; original kept; check the new copy" end
  A.keyboard:reset()
  if A.message and A.message:sub(1,7)=="Accent:" then A.message=nil end
  cancel_navigation();A.goal_x=nil
  A.typing_time=nil
  cancel_redraw()
  if A.dirty and not A.blocked then
    if not checkpoint_recovery(ctx) then A.save_failed=true; A.message="Recovery write failed" end
  end
end
function M.resume(ctx) A.right_alt=nil;A.layout_chord=nil;A.stats:resume(ctx);ctx.input:listen({keyboard=true}); refresh_layout(ctx);if A.sync then A.sync:resume(ctx)end; ctx:invalidate() end
function M.leave(ctx)
  if A and A.sync then A.sync:leave(ctx)end
  if A and A.prepare_timer then A.prepare_timer:cancel();A.prepare_timer=nil end
  if A and A.stats then A.stats:pause(ctx) end
  if A and A.file_job then A.file_job:cancel();A.file_job=nil end
  if A then cancel_navigation() end
  if A then cancel_redraw() end
  if A and not A.blocked and A.doc then
    ctx.state.last=A.doc.name; ctx.state.cursor=A.buffer.pos
    if A.dirty and not A.discard_exit then checkpoint_recovery(ctx) end
  end
end
local function box(g,f,x,y,w,h,s)
  g:text_box(x,y,w,h,s,{font=f,wrap="word",overflow="ellipsis",color=15})
end
local function pager(g,ui,l,page,pages)
  local y=l.dock+33
  g:line(l.chrome_left,l.dock,l.chrome_right,l.dock)
  g:text(l.chrome_left+45,y,"Back",{font=ui,align="center",valign="middle"})
  if page>1 then
    g:text(l.chrome_left+155,y,"Prev",{font=ui,align="center",valign="middle"})
  end
  g:text(l.chrome_left+(l.chrome_right-l.chrome_left)*3//5,y,tostring(page).." / "..tostring(pages),{font=ui,align="center",valign="middle"})
  if page<pages then
    g:text(l.chrome_right-45,y,"Next",{font=ui,align="center",valign="middle"})
  end
end
local function help_text(ctx)
  if A.view=="font_help" then return "Your Ink App font\n\nChoose the font in Ink App > Settings > Font. Then close and reopen inkWrite to start a new font session.\n\ninkWrite follows that choice for writing and controls. This page shows the font actually returned by the device.\n\nPut .ttf files in the SD card fonts folder. If the chosen font is unavailable or cannot open, the device may use the reader font or a built-in fallback.\n\nSize, line spacing and margins remain in inkWrite Typography. They change appearance only; saved document bytes are unchanged."
  elseif A.view=="files_help" then return "Your writing lives on the SD card:\n\n"..(ctx.files and ctx.files.path or "/AppFiles/inkwrite").."\n\nSave first. Power down the device, remove the SD card, then copy the .md or .txt files using a card reader.\n\nOpen them in any text editor. No account or conversion needed.\n\nPrivate recovery is removed on uninstall; saved public files remain."
  elseif A.view=="help" then return "Ctrl+H or F1   Keyboard help\nCtrl+Shift+T   Focus toolbar\nEscape   Back to writing\nCtrl+S   Save\nCtrl+N   New document\nCtrl+O   Open file\nCtrl+J   Today journal\nCtrl+Z   Undo\nCtrl+Shift+Z   Redo\nCtrl+A   Select all\nCtrl+C / X / V   Copy / cut / paste\nCtrl+B / I   Bold / italic (.md)\nCtrl+1 to Ctrl+6   Heading 1-6 (.md)\nCtrl+0   Remove heading (.md)\nCtrl+L   Bullet list (.md)\nCtrl+Quote   Quote line (.md)\nCtrl+K   Link (.md)\nCtrl+Shift+F   Toggle focus\nCtrl+Shift+S   Rotate screen\nAlt+Shift / Ctrl+Space   Next keyboard\nCtrl+R   Full screen refresh\n\nMarkdown shortcuts insert the markers in the text and work on every line the selection touches. The editor shows plain source; nothing is rendered.\n\nLeft / Right   Move character\nCtrl+Left / Right   Move word\nHome / End   Start / end of line\nCtrl+Home / End   Start / end of file\nPageUp / PageDown   Move page\nShift+movement   Select text\nEscape / Back   Return / menu\n\nTouch controls\nDouble-tap word   Select word\nTriple-tap word   Select sentence\nDouble-tap empty space   Focus\nSwipe up / down   Browse text\nLeft edge >   Shortcuts\nRight edge <   Statistics\nBottom edge up   Virtual keyboard\nKeyboard icon   Choose language\nWord count   Statistics\n\nType a letter before its accent.\nClipboard stays inside inkWrite."
  end
end
-- Layout is prepared in lifecycle/input/timer callbacks, never in draw.
prepare_frame=function(ctx)
  if not A or not A.buffer then return end
  local started=now(ctx)
  local l=geometry(ctx);local f=font(ctx);local ui=A.ui_medium
  if A.view=="editor" then
    if A.layout_revision~=A.buffer.revision or A.layout_pos~=A.buffer.pos or A.layout_width~=l.w or A.layout_count~=l.count or A.layout_font~=f or A.layout_top~=A.top then refresh_layout(ctx) end
  elseif A.view=="typography" then
    local p=l.preview;local cache=A.preview_cache
    if not cache or cache.font~=f or cache.width~=p.w or cache.count~=p.count then
      extend_budget(ctx)
      A.type_preview=A.type_preview or assert(Buffer.new(PREVIEW))
      A.preview_cache={font=f,width=p.w,count=p.count,rows=Layout.rows(A.type_preview,f,p.w,0,p.count)}
    end
  else
    local text=help_text(ctx)
    if text then
      local cache=A.help_cache
      if not cache or cache.text~=text or cache.width~=l.w or cache.font~=ui then
        extend_budget(ctx)
        cache={text=text,width=l.w,font=ui,rows=Layout.rows(assert(Buffer.new(text)),ui,l.w,0,128)};A.help_cache=cache
      end
      local count=math.max(1,(l.list_bottom-l.body)//(ui.line_height+6))
      A.help_pages=math.max(1,(#cache.rows+count-1)//count)
      A.help_page=math.max(1,math.min(A.help_page or 1,A.help_pages))
    end
  end
  local p={view=A.view,key=l.key,font=f,doc=A.doc,revision=A.buffer.revision,pos=A.buffer.pos,top=A.top,anchor=A.anchor}
  if A.view=="editor" then
    -- A composed frame may run after another edit. Keep rows and all byte-
    -- dependent drawing data together; never slice the newer buffer in draw.
    p.rows=A.rows;p.size=A.buffer.size;p.selection={}
    local ca,cz=selection()
    for i,r in ipairs(p.rows) do
      local sa,sz=math.max(ca,r.a),math.min(cz,r.z)
      if sz>sa then
        local text=r.text:sub(sa-r.a+1,sz-r.a)
        p.selection[i]={x=f:measure(r.text:sub(1,sa-r.a)),w=f:measure(text),text=text}
      end
    end
    local ci=Layout.caret_row(p.rows,p.pos)
    if ci then
      local r=p.rows[ci]
      p.caret={row=ci,x=f:measure(r.text:sub(1,p.pos-r.a))}
    end
    p.queued_since=A.pending_frame_since;A.pending_frame_since=nil
    if p.queued_since then timing(A.timing.queue,age(started,p.queued_since)) end
    timing(A.timing.layout,age(now(ctx),started))
  end
  A.prepared=p
end
local function frame_ready(l,f)
  local p=A.prepared
  if not p or p.view~=A.view or p.key~=l.key or p.font~=f or p.doc~=A.doc then return false end
  -- While a typing burst waits for its deadline, present the last coherent
  -- snapshot. Its revision remains attached to text hit testing below.
  return A.view=="editor" or p.revision==A.buffer.revision and p.pos==A.buffer.pos and p.top==A.top
end
local function help_view(ctx,g,ui,l)
  local cache=A.help_cache
  local count=math.max(1,(l.list_bottom-l.body)//(ui.line_height+6))
  local first=(A.help_page-1)*count+1
  for i=first,math.min(#cache.rows,first+count-1) do g:text(l.x,l.body+(i-first)*(ui.line_height+6),cache.rows[i].text,{font=ui}) end
  pager(g,ui,l,A.help_page,A.help_pages)
end
local function position_line(ctx,g,l,p)
  local n=p.size;local last=p.rows[#p.rows]
  if n==0 or (p.top==0 and last and last.z==n) then return end
  local visible=last and math.max(0,last.nextp-p.top) or 0
  local o=ctx.screen.occlusion or {right=0}
  local horizontal=ctx.screen.width>ctx.screen.height
  local length=horizontal and l.w or l.text_bottom-l.body
  local size=n==0 and length or math.min(length,math.max(12,length*visible//n))
  local offset=n<=visible and 0 or math.min(length-size,(length-size)*p.top//math.max(1,n-visible))
  if horizontal then
    local y=l.foot-7
    g:line(l.x,y,l.right,y)
    g:rect(l.x+offset,y-2,size,5,{fill=true})
  else
    local x=ctx.screen.width-(o.right or 0)-10
    g:line(x,l.body,x,l.text_bottom)
    g:rect(x-2,l.body+offset,5,size,{fill=true})
  end
end
-- Small line icons: no image allocations, font opens or retained screen buffers.
local function icon(g,name,x,y,f)
  if name=="keyboard" then
    g:rect(x,y+2,20,13,{radius=2})
    for row=0,1 do for col=0,4 do g:rect(x+3+col*3,y+5+row*3,1,1,{fill=true}) end end
    g:line(x+5,y+12,x+15,y+12)
  elseif name=="words" then
    -- Single-pixel letter strokes match the keyboard icon's visual weight.
    g:line(x+1,y+5,x+7,y+5);g:line(x+7,y+5,x+7,y+12)
    g:line(x+1,y+8,x+7,y+8);g:line(x+1,y+8,x+1,y+12);g:line(x+1,y+12,x+7,y+12)
    g:line(x+12,y+1,x+12,y+12);g:line(x+12,y+6,x+18,y+6)
    g:line(x+18,y+6,x+18,y+12);g:line(x+12,y+12,x+18,y+12)
    g:line(x-1,y+16,x+21,y+16);g:line(x-1,y+13,x-1,y+16);g:line(x+21,y+13,x+21,y+16)
  elseif name=="rename" then
    g:line(x+2,y+17,x+17,y+2,{line_width=2});g:line(x+5,y+20,x+20,y+5,{line_width=2})
    g:line(x+2,y+17,x+1,y+22);g:line(x+1,y+22,x+5,y+20);g:line(x+17,y+2,x+20,y+5)
  elseif name=="delete" then
    g:rect(x+4,y+6,14,16,{radius=2});g:line(x+1,y+4,x+21,y+4);g:line(x+8,y+1,x+14,y+1)
    g:line(x+9,y+9,x+9,y+18);g:line(x+14,y+9,x+14,y+18)
  elseif name=="More" then
    for col=0,2 do g:rect(x+2+col*7,y+8,3,3,{fill=true}) end
  elseif name=="Focus" then
    g:line(x,y+6,x,y);g:line(x,y,x+6,y);g:line(x+12,y,x+18,y);g:line(x+18,y,x+18,y+6)
    g:line(x,y+12,x,y+18);g:line(x,y+18,x+6,y+18);g:line(x+12,y+18,x+18,y+18);g:line(x+18,y+18,x+18,y+12)
  elseif name=="Keyboard" then icon(g,"keyboard",x,y)
  elseif name=="Settings" then
    for row=0,2 do g:line(x,y+3+row*6,x+20,y+3+row*6);g:rect(x+4+(row%2)*8,y+1+row*6,3,5,{fill=true}) end
  elseif name=="Typography" then
    g:line(x,y,x+20,y);g:line(x+10,y,x+10,y+18);g:line(x+6,y+18,x+14,y+18)
  elseif name=="Orientation" then
    g:rect(x+2,y,13,19,{radius=2});g:line(x+17,y+12,x+21,y+12);g:line(x+21,y+12,x+21,y+6)
  elseif name=="Open" then
    g:rect(x,y+5,22,14,{radius=2});g:line(x+2,y+5,x+2,y+1);g:line(x+2,y+1,x+10,y+1);g:line(x+10,y+1,x+13,y+5)
  elseif name=="Save" then
    g:rect(x,y,20,20,{radius=2});g:rect(x+4,y,11,7,{});g:rect(x+4,y+12,12,8,{})
  else
    g:rect(x+2,y,16,20,{radius=2});g:line(x+6,y+10,x+14,y+10);g:line(x+10,y+6,x+10,y+14)
  end
end
local function editor_chrome(ctx,g,l)
  local ui=A.ui_small
  local top=(ctx.screen.occlusion or {}).top or 0
  local focused=A.focus_mode and A.view=="editor"
  local y=top+(focused and 20 or 50)
  local code=Keyboard.code(A.keyboard.id)
  if not focused then
    local titles={menu="More",library="Open file",typography="Typography",fonts="Fonts",layouts="Keyboard",font_help="Fonts",orientation_help="Screen rotate",files_help="SD files",help="Shortcuts",delete_confirm="Delete file?",statistics="Statistics",timing="Memory & timing"}
    box(g,A.ui_medium,l.chrome_left,top+2,l.chrome_right-l.chrome_left-(A.view=="menu" and 120 or A.view=="editor" and 44 or 0),36,titles[A.view] or A.doc.name)
    if A.view=="menu" then g:text(l.chrome_right,top+20,M.VERSION,{font=ui,align="right",valign="middle"}) end
    if A.view=="editor" then local x=l.chrome_right-22;g:line(x-7,top+13,x+7,top+27);g:line(x+7,top+13,x-7,top+27) end
    g:line(l.chrome_left,l.header,l.chrome_right,l.header)
    local status=A.blocked and "Protected" or A.save_failed and "SAVE FAILED" or A.dirty and "Unsaved" or "Saved"
    g:text((l.chrome_left+l.chrome_right)//2,y,status,{font=ui,align="center",valign="middle"})
  end
  icon(g,"keyboard",l.chrome_left,y-8)
  g:text(l.chrome_left+27,y,code..(A.caps and " ^" or ""),{font=ui,valign="middle"})
  local count=tostring(A.buffer.words)
  local x=l.chrome_right-ui:measure(count)
  icon(g,"words",x-28,y-8,ui);g:text(l.chrome_right,y,count,{font=ui,align="right",valign="middle"})
  if not l.controls then return end
  g:line(l.chrome_left,l.dock,l.chrome_right,l.dock)
  local labels={"New","Open","Save","Settings"}
  for i=1,4 do
    local r=l.controls[i];local cx=r.x+r.w//2
    if A.action_focus==i then g:rect(r.x+2,r.y+2,r.w-4,r.h-4,{radius=4,line_width=2}) end
    icon(g,labels[i],cx-10,r.y+8)
    g:text(cx,r.y+48,labels[i],{font=ui,align="center",valign="middle"})
  end
  if not A.panel then return end
  g:rect(l.chrome_left,l.panel_top,l.chrome_right-l.chrome_left,l.dock-l.panel_top,{fill=true,color=0})
  g:line(l.chrome_left,l.panel_top,l.chrome_right,l.panel_top)
  if A.panel=="settings" then
    labels={"Focus","Orientation","Typography","Keyboard","More"}
  else labels={"Today's journal","Markdown page","Plain text page"} end
  for i=5,#l.controls do
    local r=l.controls[i];local cx=r.x+r.w//2
    if A.action_focus==i then g:rect(r.x+2,r.y+2,r.w-4,r.h-4,{radius=4,line_width=2}) end
    do
      if A.panel=="settings" then
        icon(g,labels[i-4],cx-10,r.y+5)
        local label=({"Focus","Screen","Type","Keyb.","More"})[i-4]
        g:text(cx,r.y+43,label,{font=ui,align="center",valign="middle"})
      else g:text(r.x+12,r.y+26,labels[i-4],{font=A.ui_medium,valign="middle"}) end
    end
  end
end
function M.draw(ctx,g)
  if not A then return end
  if A.sync and A.sync.active then A.sync:draw(ctx,g);return end
  local l=geometry(ctx); local f=font(ctx); local ui=A.ui_medium
  g:clear(0)
  if not frame_ready(l,f) then
    -- Geometry can change without an input event. Queue one preparation and
    -- refuse hit testing against the previous screen until it is presented.
    A.touch_rows=nil;A.touch_geometry=nil
    if not A.prepare_timer then
      A.prepare_timer=ctx:after(1,function(c)
        A.prepare_timer=nil;prepare_frame(c);c:invalidate()
      end)
    end
    box(g,ui,l.x,l.body,l.w,80,A.prepare_timer and "Preparing text..." or "Text preparation unavailable. Reopen inkWrite.")
    return
  end
  local focused=A.focus_mode and A.view=="editor"
  if A.view~="editor" then editor_chrome(ctx,g,l) end
  if A.view=="editor" then
    local p=A.prepared
    A.touch_rows=p.rows;A.touch_revision=p.revision;A.touch_font=f;A.touch_doc=p.doc;A.touch_geometry=l.key
    if p.size==0 then box(g,ui,l.x,l.body+56,l.w,100,"A little space to write.\nConnect your Bluetooth keyboard.") end
    for i,r in ipairs(p.rows) do
      local y=l.body+(i-1)*l.step
      local s=p.selection[i]
      if s then
        g:rect(l.x+s.x,y,s.w,f.line_height,{color=15,fill=true})
        g:text(l.x,y,r.text,{font=f,color=15})
        g:text(l.x+s.x,y,s.text,{font=f,color=0})
      else g:text(l.x,y,r.text,{font=f}) end
    end
    if p.caret then
      local x=l.x+p.caret.x;local y=l.body+(p.caret.row-1)*l.step
      g:line(x,y,x,y+f.line_height,{line_width=2})
    end
    position_line(ctx,g,l,p)
    editor_chrome(ctx,g,l)
  elseif A.view=="statistics" then
    local small=A.ui_small;local mode=A.stats_mode or 1
    for i,label in ipairs({"Week","Month","Year"}) do
      local x=l.x+(i-1)*l.w//3;local w=l.w//3
      g:rect(x,l.body,w-3,44,{fill=i==mode,radius=3})
      g:text(x+w//2,l.body+22,label,{font=small,align="center",valign="middle",color=i==mode and 0 or 15})
    end
    local r,e=A.stats:report(ctx,mode)
    if r then
      g:text(l.x,l.body+56,r.title,{font=small})
      g:text(l.x,l.body+90,"Words added: "..r.words,{font=small})
      g:text(l.x,l.body+120,"Typing: "..Stats.duration(r.typing).." | App: "..Stats.duration(r.app),{font=small})
      g:text(l.x,l.body+150,"Avg/day: "..Stats.duration(r.average),{font=small})
      local top,bottom=l.body+206,l.dock-44;local height=math.max(12,bottom-top)
      local peak=60;for _,v in ipairs(r.bins) do peak=math.max(peak,v) end
      g:text(l.x,top-28,"Typing time / "..(mode==3 and "month" or "day").." (max "..Stats.duration(peak)..")",{font=small})
      g:line(l.x,bottom,l.right,bottom)
      for i,v in ipairs(r.bins) do
        local x=l.x+(i-1)*l.w//r.count;local w=math.max(2,l.w//r.count-3);local h=v*height//peak
        if h>0 then g:rect(x,bottom-h,w,h,{fill=true}) end
        if mode~=2 or i==1 or (i%5==0 and i<=r.count-3) or i==r.count then
          local label=mode==1 and ({"M","T","W","T","F","S","S"})[i] or mode==3 and ({"J","F","M","A","M","J","J","A","S","O","N","D"})[i] or tostring(i)
          g:text(x+w//2,bottom+10,label,{font=small,align="center"})
        end
      end
      if A.stats.error or A.stats.save_error then g:text(l.x,l.body+178,A.stats.error or "Statistics save failed",{font=small}) end
    else box(g,small,l.x,l.body+64,l.w,100,e) end
    pager(g,small,l,1,1)
  elseif A.view=="typography" then
    local small=A.ui_small
    local p=l.preview
    local cache=A.preview_cache
    for i,row in ipairs(cache.rows) do g:text(p.x,p.y+(i-1)*l.step,row.text,{font=f}) end
    if l.type_notice then box(g,small,l.x,l.type_notice_y,l.w,48,l.type_notice) end
    for _,label in ipairs(l.type_labels) do g:text(label.x,label.y,label.text,{font=small}) end
    for i,c in ipairs(l.type_controls) do
      g:rect(c.x,c.y,c.w-3,c.h,{radius=3,fill=c.selected==true,color=15,line_width=A.type_focus==i and 2 or 1})
      g:text_box(c.x+3,c.y+2,c.w-9,c.h-4,c.label,{font=small,align="center",valign="middle",overflow="ellipsis",color=c.selected and 0 or 15})
    end
    pager(g,small,l,1,1)
  elseif A.view=="menu" or A.view=="library" or A.view=="fonts" or A.view=="layouts" then
    local rows=list_rows()
    local per=l.per; local first=((A.focus-1)//per)*per+1
    if #rows==0 then box(g,ui,l.x,l.body,l.w,120,"No Markdown or text files yet.\nEscape returns to writing.") end
    for i=first,math.min(#rows,first+per-1) do
      local y=l.body+(i-first)*l.row
      if i==A.focus then g:rect(l.x-8,y-4,l.w+16,l.row-6,{radius=10}) end
      local label=type(rows[i])=="table" and rows[i].name or rows[i]
      
      if A.view=="library" then
        local rename,delete,size=file_cells(ctx,l,rows[i]);local small=A.ui_small
        -- Preferred 20 px fonts can have a line height greater than 24 px.
        -- Keep at least one full line in the label box; geometry also drives taps.
        box(g,small,l.x,y+4,math.max(1,size-l.x-90),l.row-8,label)
        local icon_y=y+(l.row-24)//2
        icon(g,"rename",rename+11,icon_y);icon(g,"delete",delete+11,icon_y)
        g:text(size,y+l.row//2,file_size(rows[i].size),{font=small,align="right",valign="middle"})
        if i==A.focus and (A.file_action or 1)>1 then local x=A.file_action==2 and rename or delete;g:rect(x,y+(l.row-44)//2,44,44,{radius=3,line_width=2}) end
      elseif A.view=="layouts" and i>1 then
        local checked=ctx.state.keyboard_enabled[Keyboard.ids[i-1]]==true
        g:rect(l.x,y+10,22,22,{radius=2})
        if checked then g:line(l.x+4,y+21,l.x+9,y+27);g:line(l.x+9,y+27,l.x+19,y+14) end
        box(g,A.ui_small,l.x+34,y+4,l.w-34,36,label)
      else box(g,A.ui_small,l.x,y+4,l.w,36,label) end
    end
    pager(g,ui,l,((A.focus-1)//per)+1,math.max(1,(#rows+per-1)//per))
  elseif A.view=="timing" then
    local small=A.ui_small
    box(g,small,l.x,l.body,l.w,math.max(0,l.foot-l.body-8),timing_sample())
    pager(g,small,l,1,1)
  elseif A.view=="delete_confirm" then
    box(g,ui,l.x,l.body,l.w,60,A.confirm_file and A.confirm_file.name or "")
    box(g,ui,l.x,l.body+68,l.w,80,"Permanently delete this SD file?\nThis cannot be undone.")
    local y=l.body+160;local width=l.w//2
    for i,label in ipairs({"Cancel","Delete"}) do
      g:rect(l.x+(i-1)*width,y,width-6,52,{radius=4,line_width=A.confirm_choice==i and 2 or 1})
      g:text(l.x+(i-1)*width+(width-6)//2,y+26,label,{font=ui,align="center",valign="middle"})
    end
    pager(g,ui,l,1,1)
  elseif A.view=="font_help" then
    help_view(ctx,g,ui,l)
  elseif A.view=="orientation_help" then
    for i,label in ipairs({"Portrait","Horizontal"}) do
      local cx=l.x+l.w*(2*i-1)//4;local x=cx-(i==1 and 18 or 30);local y=l.body+24
      local function rr(a,b,w,h)
        if i==2 then g:rect(x+60-b-h,y+a,h,w,{radius=1}) else g:rect(x+a,y+b,w,h,{radius=1}) end
      end
      rr(0,0,36,60);rr(3,4,30,44)
      if ctx.device and ctx.device.model=="x4_classic" then for j=0,3 do rr(5+j*7,52,4,3) end else rr(15,52,6,4) end
      g:text(cx,l.body+112,label,{font=ui,align="center"})
    end
    box(g,A.ui_small,l.x,l.body+170,l.w,60,"Rotation follows device settings.")
    pager(g,ui,l,1,1)
  elseif A.view=="files_help" then
    help_view(ctx,g,ui,l)
  elseif A.view=="help" then
    help_view(ctx,g,ui,l)
  end
  if l.footer then
  g:line(l.x,l.foot,l.right,l.foot)
  local status=A.blocked and "Protected" or A.save_failed and "SAVE FAILED" or A.dirty and "Unsaved" or "Saved"
  box(g,ui,l.x,l.foot+8,l.w,30,status.." | "..A.buffer.words..(A.buffer.words==1 and " word" or " words").." | "..tostring(A.buffer.size).." B"..(A.browsing and " | Browse" or "")..(A.caps and " CAPS" or ""))
  if A.message then box(g,ui,l.x,l.foot+40,l.w,54,A.message) end
  end
  if A.virtual and A.view=="editor" and not A.close_modal then
    local keys,top=virtual_keys(ctx);local small=A.ui_small
    g:rect(0,top,ctx.screen.width,ctx.screen.height-top,{fill=true,color=0})
    for i,r in ipairs(keys) do
      g:rect(r.x+1,r.y+2,r.w-2,r.h-4,{radius=3,line_width=A.virtual_focus==i and 2 or 1})
      g:text_box(r.x+2,r.y+3,r.w-4,r.h-6,r.label=="Shift" and "Aa" or r.label=="Enter" and "Ent" or r.label=="More" and ">" or r.label=="—" and "--" or r.label=="…" and "..." or r.label,{font=small,align="center",valign="middle",overflow="ellipsis"})
    end
  end
  if A.languages and not A.close_modal then
    local top,per,first=language_geometry(ctx);local small=A.ui_small
    local total=#A.enabled_ids+1
    local count=math.min(per,total-first+1)
    g:rect(20,top,ctx.screen.width-40,(count+(total>per and 1 or 0))*48,{fill=true,color=0})
    for row=1,count do
      local i=first+row-1;local chosen=A.keyboard.id==A.enabled_ids[i]
      g:rect(20,top+(row-1)*48,ctx.screen.width-40,48,{fill=chosen,color=15,line_width=A.language_focus==i and 2 or 1})
      g:text_box(32,top+(row-1)*48+2,ctx.screen.width-64,44,A.enabled_names[i] or "Add more...",{font=small,valign="middle",overflow="ellipsis",color=chosen and 0 or 15})
    end
    if total>per then
      g:text(32,top+per*48+24,"< Prev",{font=small,valign="middle"})
      g:text(ctx.screen.width-32,top+per*48+24,"Next >",{font=small,align="right",valign="middle"})
    end
  end
  if A.close_modal then
    local r=close_rect(ctx);local modal=A.close_modal;local small=A.ui_small
    g:rect(r.x,r.y,r.w,r.h,{fill=true,color=0,radius=8});g:rect(r.x,r.y,r.w,r.h,{radius=8,line_width=2})
    g:text(r.x+r.w//2,r.y+28,"Close inkWrite?",{font=ui,align="center",valign="middle"})
    g:text_box(r.x+12,r.y+58,r.w-24,56,modal.dirty and "Save changes before closing?" or A.blocked and "Files are unchanged." or "No unsaved changes.",{font=small,align="center",wrap="word",overflow="ellipsis"})
    local labels=modal.dirty and {"Cancel","Save","Discard"} or {"Cancel","Close"};local w=r.w//#labels
    for i,label in ipairs(labels) do
      g:rect(r.x+(i-1)*w+6,r.y+126,w-12,52,{fill=modal.choice==i,radius=4})
      g:text(r.x+(i-1)*w+w//2,r.y+152,label,{font=small,align="center",valign="middle",color=modal.choice==i and 0 or 15})
    end
  end
end
-- Every callback that can change the picture prepares itself; this wrapper only
-- repairs a snapshot that no longer matches (a document change, a rotation, a
-- notice) so the next frame is never built from stale rows.
for _,name in ipairs({"load","input","tick","resume"}) do
  local callback=M[name]
  M[name]=function(ctx,...)
    local started=name=="input" and A and A.view=="editor" and now(ctx) or nil
    if started and A then A.input_started=started;A.last_key=started end
    local result=callback(ctx,...)
    if A and not frame_ready(geometry(ctx),font(ctx)) then prepare_frame(ctx) end
    if started and A then timing(A.timing.input,age(now(ctx),started));A.input_started=nil end
    return result
  end
end
local draw=M.draw
M.draw=function(ctx,g)
  local started=now(ctx)
  draw(ctx,g)
  if A and A.view=="editor" then
    local finished=now(ctx);timing(A.timing.draw,age(finished,started))
    local p=A.prepared
    if p and p.queued_since and not p.sampled and A.touch_rows==p.rows and A.touch_revision==p.revision then
      timing(A.timing.compose,age(finished,p.queued_since));p.sampled=true
    end
  end
end
-- Desktop harness uses the real controller through public lifecycle functions.
return M

