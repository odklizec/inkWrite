-- Pure integer geometry shared by the future renderer and hit testing.
local M={}
local RATIOS={['1:1']={1,1},['2:1']={2,1},['1:2']={1,2}}
local function integer(v,minimum)
  return type(v)=='number' and v==v and v<math.huge and v>=minimum and v%1==0
end
function M.split(rect,direction,ratio,gap)
  if type(rect)~='table' or not integer(rect.x,0) or not integer(rect.y,0)
    or not integer(rect.w,0) or not integer(rect.h,0) then return nil,'Invalid workspace rectangle' end
  if direction~='horizontal' and direction~='vertical' then return nil,'Invalid split direction' end
  local weights=RATIOS[ratio];if not weights then return nil,'Invalid split ratio' end
  gap=gap or 8;if not integer(gap,0) then return nil,'Invalid divider' end
  local length=direction=='vertical' and rect.w or rect.h
  gap=math.min(gap,length)
  local available=length-gap
  local first=available*weights[1]//(weights[1]+weights[2])
  local second=available-first
  if direction=='vertical' then
    return {a={x=rect.x,y=rect.y,w=first,h=rect.h},
      b={x=rect.x+first+gap,y=rect.y,w=second,h=rect.h},
      divider={x=rect.x+first,y=rect.y,w=gap,h=rect.h}}
  end
  return {a={x=rect.x,y=rect.y,w=rect.w,h=first},
    b={x=rect.x,y=rect.y+first+gap,w=rect.w,h=second},
    divider={x=rect.x,y=rect.y+first,w=rect.w,h=gap}}
end
function M.text_area(pane,header_height,margin,line_height,spacing)
  if type(pane)~='table' or not integer(pane.x,0) or not integer(pane.y,0)
    or not integer(pane.w,0) or not integer(pane.h,0)
    or not integer(header_height,0) or not integer(margin,0)
    or not integer(line_height,1) or not integer(spacing,0) then return nil,'Invalid pane metrics' end
  local header=math.min(pane.h,math.max(44,header_height))
  local padding=math.min(margin,pane.w//12)
  local text={x=pane.x+padding,y=pane.y+header,w=math.max(0,pane.w-2*padding),h=pane.h-header}
  local count=text.w>0 and text.h>=line_height and 1+(text.h-line_height)//(line_height+spacing) or 0
  return {header={x=pane.x,y=pane.y,w=pane.w,h=header},text=text,count=count,padding=padding}
end
function M.hit(layout,x,y)
  if type(x)~='number' or type(y)~='number' then return nil end
  for i,key in ipairs({'a','b'}) do local p=layout[key]
    if x>=p.x and x<p.x+p.w and y>=p.y and y<p.y+p.h then return i end
  end
end
return M
