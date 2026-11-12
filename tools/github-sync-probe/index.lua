local Probe=require("probe")
local Config=require("config")
local probe,index,font,results,status
local function next_case(ctx)
  if not probe then return end
  local next_index=index+1
  if next_index>#Probe.cases then status="Complete. Reopen to repeat.";ctx:invalidate();return end
  local accepted,err=probe:start(ctx,next_index,function(c,result)
    results[#results+1]=result -- hard cap: seven explicit cases per session
    status=result.pass and "PASS. OK / tap for next." or "FAIL. OK / tap for next."
    c:invalidate()
  end)
  if accepted then index=next_index;status="Request in progress..."
  else status="Not started: "..err end
  ctx:invalidate()
end
function on_load(ctx)
  results={};index=0;font=ctx.fonts:size(20)
  probe=Config.origin and Probe.new(Config.origin) or nil
  status=probe and "Dummy data only. OK / tap to begin." or "Set HTTPS origin in config.lua first."
end
function on_draw(ctx,g)
  g:clear(0)
  g:text(18,18,"Phase 0 HTTPS probe",{font=font,color=15})
  g:text(18,52,status,{font=font,color=15})
  for i,r in ipairs(results) do
    local line=i.." "..r.method.." "..r.status.." "..r.bytes.." B "..(r.pass and "PASS" or (r.err or "FAIL"))
    g:text(18,90+i*30,line,{font=font,color=15})
  end
  g:text(18,ctx.screen.height-42,"Back: cancel / exit",{font=font,color=15})
end
function on_input(ctx,ev)
  if ev.type=="key" and ev.phase=="up" and ev.key=="back" then
    if probe then probe:cancel() end;ctx:quit();return true
  end
  if ev.type=="key" and ev.phase=="up" and ev.key=="ok" then next_case(ctx);return true end
  if ev.type=="pointer" and ev.phase=="up" and ev.gesture=="tap" then next_case(ctx);return true end
end
function on_pause(ctx) if probe then probe:cancel() end;status="Cancelled. OK / tap for next." end
function on_leave(ctx) if probe then probe:cancel() end end
