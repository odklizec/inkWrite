local Geometry=require('domain.pane_geometry')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local function contained(inner,outer)
  return inner.x>=outer.x and inner.y>=outer.y and inner.w>=0 and inner.h>=0
    and inner.x+inner.w<=outer.x+outer.w and inner.y+inner.h<=outer.y+outer.h
end
local weights={['1:1']={1,1},['2:1']={2,1},['1:2']={1,2}}
local cases=0
for _,model in ipairs({'x4_classic','x4_pro'})do
 for _,screen in ipairs({{480,800},{800,480}})do
  for _,focus in ipairs({false,true})do
   for _,keyboard in ipairs({false,true})do
    for _,direction in ipairs({'horizontal','vertical'})do
     for _,ratio in ipairs({'1:1','2:1','1:2'})do
      local rect={x=24,y=focus and 48 or 78,w=screen[1]-48,h=0}
      local bottom=screen[2]-(focus and 18 or 66)-(keyboard and 266 or 0)
      rect.h=math.max(0,bottom-rect.y)
      local p=assert(Geometry.split(rect,direction,ratio));cases=cases+1
      check(contained(p.a,rect) and contained(p.b,rect) and contained(p.divider,rect),'pane and divider stay inside reserved editor area')
      if direction=='vertical' then
       check(p.a.w+p.divider.w+p.b.w==rect.w and p.a.x+p.a.w==p.divider.x and p.divider.x+p.divider.w==p.b.x,'vertical split covers width exactly without overlap')
      else
       check(p.a.h+p.divider.h+p.b.h==rect.h and p.a.y+p.a.h==p.divider.y and p.divider.y+p.divider.h==p.b.y,'horizontal split covers height exactly without overlap')
      end
      for i,pane in ipairs({p.a,p.b})do
       for _,line in ipairs({20,24,36,44})do
        local area=assert(Geometry.text_area(pane,28,56,line,14))
        check(contained(area.header,pane) and contained(area.text,pane),'header and text remain inside pane with large margins/fonts')
        check(area.count==0 or area.text.y+(area.count-1)*(line+14)+line<=pane.y+pane.h,'only complete text rows are counted')
        check(area.count==0 or area.text.h-area.count*line-(area.count-1)*14<line+14,'last fitting row is used')
       end
       if pane.w>0 and pane.h>0 then
        check(Geometry.hit(p,pane.x,pane.y)==i,'first pixel maps to the owning pane')
        check(Geometry.hit(p,pane.x+pane.w-1,pane.y+pane.h-1)==i,'last pixel maps to the same pane')
       end
      end
      if p.divider.w>0 and p.divider.h>0 then check(Geometry.hit(p,p.divider.x,p.divider.y)==nil,'divider cannot route typing to a pane')end
      check(Geometry.hit(p,rect.x-1,rect.y)==nil and Geometry.hit(p,rect.x+rect.w,rect.y)==nil,'outer boundary is excluded')
     end
    end
   end
  end
 end
end
check(cases==96,'both devices, orientations, modes, keyboard states, directions and ratios covered')
local p=assert(Geometry.split({x=24,y=78,w=432,h=656},'vertical','2:1'))
check(p.a.w==282 and p.b.w==142 and p.divider.w==8,'known portrait two-to-one widths')
p=assert(Geometry.split({x=24,y=48,w=752,h=414},'vertical','1:2'))
check(p.a.w==248 and p.b.w==496,'known landscape one-to-two widths')
local small=assert(Geometry.text_area({x=0,y=0,w=142,h=43},44,56,24,8))
check(small.count==0 and small.header.h==43 and small.text.h==0,'tiny pane never forces a row beyond its bounds')
p=assert(Geometry.split({x=0,y=0,w=0,h=0},'horizontal','1:1'))
check(p.a.h==0 and p.b.h==0 and Geometry.hit(p,0,0)==nil,'zero usable space is safe')
for _,bad in ipairs({0/0,math.huge,-1,1.5,'480'})do
 check(Geometry.split({x=0,y=0,w=bad,h=800},'vertical','1:1')==nil,'invalid dimensions refused')
end
check(Geometry.split({x=0,y=0,w=480,h=800},'diagonal','1:1')==nil,'unknown direction refused')
check(Geometry.split({x=0,y=0,w=480,h=800},'vertical','3:1')==nil,'unsupported ratio refused')
return n
