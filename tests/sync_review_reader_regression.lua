local Reader=require('domain.sync_review')
local UI=require('domain.sync_ui')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local bytes=string.rep('Line '..string.char(0xc4,0x8d)..'aj  \r\n',400)
local calls=0;local font={line_height=24,measure=function(_,t)calls=calls+1;return (utf8.len(t)or 0)*10 end}
local c={budget={extend=function()end}}
local review={name='ideas.md',file={bytes=bytes},remote={exists=true,bytes=string.rep('GitHub text\n',150)}}
local r=Reader.new(review,'local');local slices={}
repeat
 r:prepare(c,font,200,120)
 for _,row in ipairs(r.lines)do slices[#slices+1]=bytes:sub(row.a+1,row.nextp)end
 local before=calls;r:prepare(c,font,200,120);check(calls==before,'unchanged page performs no layout work')
 local more=r.more;if more then r:turn(1)else break end
until false
check(table.concat(slices)==bytes,'all UTF-8, whitespace and CRLF source bytes are covered exactly once across review pages')
local last=r.page;r:turn(-1);r:prepare(c,font,200,120);check(r.page==last-1,'Prev returns one read-only source page')
r:prepare(c,font,400,120);check(r.page==1,'rotation resets to a valid measured source page')
r=Reader.new(review,'github');r:prepare(c,font,200,120);check(r.lines[1].text=='GitHub text','GitHub side uses independent source')
local f={line_height=24,measure=font.measure};local ctx={state={},screen={width=480,height=800},invalidate=function()end,budget=c.budget}
local u=UI.new({},f,f);u:open(ctx);u.focus=4;u.session.review=review;u:tick(ctx)
local function key(code)u:input(ctx,{type='key',phase='down',code=code})end
local function touch(x,y,gesture)
 u:input(ctx,{type='pointer',phase='up',x=x,y=y,gesture=gesture or 'tap'})
end
local function draw()
 local text={}
 local function record(_,x,y,value)text[value]={x=x,y=y}end
 local g=setmetatable({text=record,text_box=function(_,x,y,w,h,t)record(nil,x,y,t)end},
  {__index=function()return function()end end})
 local before=calls;u:draw(ctx,g)
 check(calls==before,'drawing prepared review does not measure or rebuild text')
 return text
end
check(u.page=='compare','review response opens comparison directly')
local text=draw();local left,right=text['Local / Page 1'],text['GitHub / Page 1']
check(left and right and left.x==right.x and left.y<right.y and text['GitHub text'],'portrait shows both read-only sources stacked')
key('ArrowDown')
check(draw()['Local / Page 2'] and u.comparison.readers[2].page==1,'Classic can page the local pane independently')
touch(right.x+10,right.y+10,'swipe_up')
check(draw()['GitHub / Page 2'] and u.comparison.readers[1].page==2,'touch scrolls the pane under the gesture')
ctx.screen.width,ctx.screen.height=800,480;u:tick(ctx)
text=draw();left,right=text['Local / Page 1'],text['GitHub / Page 1']
check(left and right and left.y==right.y and left.x<right.x,'landscape lays out both sources side by side')
key('ArrowLeft');key('PageDown');key('Tab');key('PageDown')
check(u.comparison.readers[1].page==2 and u.comparison.readers[2].page==2,'keyboard can page and switch between both panes')
text=draw();touch(text['Actions >'].x,text['Actions >'].y)
check(u.page=='review','touch opens version actions from comparison')
key('Enter');check(u.page=='resolve_local'and u.focus==1,'local replacement defaults to Cancel')
key('Enter');check(u.page=='review'and u.session.review==review,'Cancel preserves both captured versions without an operation')
key('ArrowDown');key('Enter');check(u.page=='resolve_github'and u.focus==1,'remote overwrite also defaults to Cancel')
key('Escape');key('Escape')
check(u.page=='compare'and draw()['Local / Page 2'] and draw()['GitHub / Page 2'],'Back from actions returns to both prepared pages')
key('Escape')
check(u.page=='main'and u.focus==4 and u.session.review==nil and u.comparison==nil,'leaving comparison restores origin and releases both readers')
u.session.review={name='ideas.md',file={bytes=''},remote={exists=false}};u:tick(ctx)
text=draw()
check(text['Empty file'] and text['No GitHub version'],'missing GitHub text is distinct from an empty local file')
key('Enter');text=draw()
check(not text['Use GitHub version locally...']and text['Keep local version on GitHub...'],'missing GitHub version cannot replace local text')
return n
