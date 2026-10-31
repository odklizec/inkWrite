local M={}
-- Small source view, preserving whitespace and byte positions exactly.
-- Prefer spaces/tabs for soft wraps, preserving every source byte.
function M.rows(buffer,font,width,start,count,previous,dirty_from)
  local out={}; local p=start
  -- A source edit cannot change rows ending before its byte offset. Reuse
  -- those rows; recompute the boundary row so appended text wraps correctly.
  if previous and dirty_from and previous[1] and previous[1].a==start then
    for _,r in ipairs(previous) do
      if #out>=count or r.nextp<=r.a then break end
      if (r.watch or r.nextp)<dirty_from or r.nextp==dirty_from and r.nextp>r.z then
        out[#out+1]=r; p=r.nextp
      else break end
    end
  end
  for _=#out+1,count do
    if p>buffer.size then break end
    if p==buffer.size and #out>0 and out[#out].nextp==out[#out].z then break end
    local stop=math.min(buffer.size,p+512)
    while not buffer:is_boundary(stop) do stop=stop-1 end
    local s=buffer:slice(p,stop)
    local nl=s:find("\n",1,true); local segment=nl and s:sub(1,nl-1) or s
    local chars=utf8.len(segment) or 0; local lo,hi=0,chars
    while lo<hi do
      local mid=(lo+hi+1)//2
      local finish=(utf8.offset(segment,mid+1) or (#segment+1))-1
      if font:measure(segment:sub(1,finish))<=width then lo=mid else hi=mid-1 end
    end
    if chars>0 and lo==0 then lo=1 end
    local used=(utf8.offset(segment,lo+1) or (#segment+1))-1
    -- A changed next character can alter the last fitting prefix and hence
    -- the word break, even when it is beyond the rendered row.
    local watch=math.min(buffer.size,p+used+4)
    if used<#segment and used>0 then
      local last,word
      for i=1,used do
        local c=segment:byte(i)
        if c==32 or c==9 then if word then last=i end else word=true end
      end
      if last then used=last end
    end
    local nextp=p+used
    if used==#segment and nl then nextp=nextp+1 end
    out[#out+1]={a=p,z=p+used,nextp=nextp,text=segment:sub(1,used),watch=watch}
    if nextp==p then break end
    p=nextp
  end
  return out
end
function M.caret_row(rows,p)
  for i,r in ipairs(rows) do
    if p>=r.a and (p<r.nextp or p==r.z and (i==#rows or r.nextp>r.z)) then return i end
  end
  return nil
end
-- Use the same measured prefixes as drawing; never split a UTF-8 code point.
function M.nearest(row,font,x)
  local s=row.text; local count=utf8.len(s) or 0
  if x<=0 or count==0 then return row.a end
  local lo,hi=0,count
  local function bytes(n) return (utf8.offset(s,n+1) or (#s+1))-1 end
  local function width(n) return font:measure(s:sub(1,bytes(n))) end
  while lo<hi do
    local mid=(lo+hi+1)//2
    if width(mid)<=x then lo=mid else hi=mid-1 end
  end
  if lo<count and x-width(lo)>=width(lo+1)-x then lo=lo+1 end
  return row.a+bytes(lo)
end
return M
