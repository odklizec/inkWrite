local UI=require('domain.sync_ui')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function setup(w,h,size,count)
 local c={state={},screen={width=w,height=h,occlusion={left=8,right=8,top=8,bottom=8}},invalidate=function()end}
 local font={line_height=size};local u=UI.new({},font,font)
 u:open(c);u.page='remote'
 for i=1,count do u.session.rows[i]={name=string.format('row%02d.md',i)}end
 u:tick(c)
 local function draw()
  local visible,texts={},{}
  local g=setmetatable({text_box=function(_,x,y,w,ht,t)if t:match('^row%d+%.md$')then visible[#visible+1]=t end end,
   text=function(_,x,y,t)texts[t]=true end},{__index=function()return function()end end})
  u:draw(c,g);return table.concat(visible,','),texts
 end
 local function tap(x,y,gesture)u:input(c,{type='pointer',phase='up',x=x,y=y,gesture=gesture or 'tap'})end
 return u,c,draw,tap
end
for _,dim in ipairs({{480,800},{800,480}})do for _,size in ipairs({24,44})do
 local w,h=dim[1],dim[2];local u,c,draw,tap=setup(w,h,size,40)
 local first,t=draw();check(t.Next and not t.Prev,'first page offers only available Next')
 tap(w-30,h-10);local second,t=draw()
 check(first~=second and t.Prev,'one Next tap immediately changes visible rows, including bottom margin')
 local focus=u.focus;tap(w-30,h-10,'double_tap');local third=draw()
 check(u.focus>focus and third~=second,'quick second tap advances another real page')
 tap(w//2,h-10);local returned=draw();check(returned==second,'one Prev tap returns exactly one page')
 u:input(c,{type='key',code='ArrowLeft',phase='down'});local returned,t=draw()
 check(returned==first and not t.Prev,'keyboard paging agrees with touch paging')
 u.focus=41;u:tick(c);local last,t=draw();local focus=u.focus
 check(t.Prev and not t.Next,'last page has no misleading Next control')
 tap(w-30,h-10);check(u.focus==focus and draw()==last,'unavailable Next cannot silently move focus')
 tap(w//2,h-10,'swipe_left');check(u.focus==focus,'swipes are not interpreted as footer taps')
 -- Back covers the full footer including side and bottom padding.
 tap(9,h-9);check(u.active and u.page=='main','bottom-left padding triggers one Back level')
 tap(9,h-9,'double_tap');check(not u.active,'second rapid Back tap closes sync instead of being ignored')
end end
local u,c,draw,tap=setup(480,800,24,0);u.page='main';u.focus=1;u:tick(c)
local _,t=draw();check(not t.Prev and not t.Next,'all main actions fit: no inactive paging controls')
tap(450,790);check(u.focus==1,'tapping absent Next never jumps to Version history')
-- Footer boundary starts at the drawn divider and uses three generous zones.
u,c,draw,tap=setup(480,800,24,40);tap(470,735);local _,t=draw();check(t.Prev,'right-edge footer tap is accepted')
tap(50,735);check(u.page=='main','Back at divider is accepted')
return n
