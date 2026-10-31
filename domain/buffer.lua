-- Byte offsets refer to gaps between UTF-8 code points (0 .. size).
-- Two stacks of <=1024-byte blocks avoid copying a document on each key.
local M = { MAX = 32768, BLOCK = 1024 }
local B = {}; B.__index = B
local function whitespace(n)
  return n==nil or n==32 or n==9 or n==10 or n==11 or n==12 or n==13
end
-- Count transitions with external context. The right-hand character's start
-- belongs to this contribution so joining/splitting words updates correctly.
local function contribution(s,left,right)
  local count=0;local gap=left
  for i=1,#s do
    local nextgap=whitespace(s:byte(i))
    if gap and not nextgap then count=count+1 end
    gap=nextgap
  end
  if right==false and gap then count=count+1 end
  return count
end
local function valid(s)
  return type(s)=="string" and not s:find("%z") and utf8.len(s)~=nil
end
M.valid = valid
local function boundary(s, p)
  return p==0 or p==#s or (p>=0 and p<#s and (s:byte(p+1)<128 or s:byte(p+1)>=192))
end
local function push(stack, s)
  -- Walk the original string. Repeatedly slicing off its shrinking tail made
  -- opening/pasting a long document allocate its contents many times over.
  local offset=1
  while offset<=#s do
    local finish=math.min(#s,offset+M.BLOCK-1)
    while not boundary(s,finish) do finish=finish-1 end
    local part=s:sub(offset,finish);local last=stack[#stack]
    if last and #last+#part<=M.BLOCK then stack[#stack]=last..part
    else stack[#stack+1]=part end
    offset=finish+1
  end
end
function M.new(s)
  s=s or ""
  if not valid(s) or #s>M.MAX then return nil,"invalid_text" end
  local b=setmetatable({left={},right={},pos=0,size=#s,words=contribution(s,true,true),revision=0,undo={},redo={},history_bytes=0},B)
  push(b.left,s); b.pos=#s
  return b
end
function B:text()
  local t={}
  for i=1,#self.left do t[#t+1]=self.left[i] end
  for i=#self.right,1,-1 do t[#t+1]=self.right[i] end
  return table.concat(t)
end
function B:slice(a,z)
  a=math.max(0,a); z=math.min(self.size,z)
  if z<=a then return "" end
  local offset=0;local first,out
  -- Usually a character or one visible line is wholly inside a single block.
  -- Allocate a join table only when the requested range crosses a block.
  for i=1,#self.left+#self.right do
    local s=i<=#self.left and self.left[i] or self.right[#self.right-(i-#self.left)+1]
    local finish=offset+#s
    if finish>a then
      local part=s:sub(math.max(1,a-offset+1),math.min(#s,z-offset))
      if first then
        if not out then out={first} end
        out[#out+1]=part
      else first=part end
      if finish>=z then return out and table.concat(out) or first end
    end
    offset=finish
  end
  return out and table.concat(out) or first or ""
end
-- Read a byte without building a slice, closure or temporary join table.
function B:byte(p)
  if p<0 or p>=self.size then return nil end
  for i=1,#self.left do local s=self.left[i];if p<#s then return s:byte(p+1) end;p=p-#s end
  for i=#self.right,1,-1 do local s=self.right[i];if p<#s then return s:byte(p+1) end;p=p-#s end
end
function B:is_boundary(p)
  if p<0 or p>self.size then return false end
  if p==0 or p==self.size then return true end
  local n=self:byte(p);return n<128 or n>=192
end
function B:previous(p)
  p=p or self.pos
  if p<=0 then return 0 end
  p=p-1
  while p>0 do local n=self:byte(p);if n<128 or n>=192 then break end;p=p-1 end
  return p
end
function B:following(p)
  p=p or self.pos
  if p>=self.size then return self.size end
  local n=self:byte(p)
  return p+(n<128 and 1 or n<224 and 2 or n<240 and 3 or 4)
end
-- Whitespace-delimited movement. Read one bounded window rather than slicing
-- the block stacks once per character. Long unbroken runs advance in 1 KiB hops.
function B:word(p,d)
  local a,z=math.max(0,p-1024),math.min(self.size,p+1024)
  while not self:is_boundary(a) do a=a+1 end
  while not self:is_boundary(z) do z=z-1 end
  local s=self:slice(a,z);local q=p-a
  local function space(i) return s:sub(i,i):match("%s")~=nil end
  if d<0 then
    while q>0 and space(q) do q=q-1 end
    while q>0 and not space(q) do q=q-1 end
    while q>0 and s:byte(q+1)>=128 and s:byte(q+1)<192 do q=q-1 end
  else
    while q<#s and not space(q+1) do q=q+1 end
    while q<#s and space(q+1) do q=q+1 end
    while q<#s and s:byte(q+1)>=128 and s:byte(q+1)<192 do q=q+1 end
  end
  return a+q
end
function B:seek(p)
  p=math.max(0,math.min(self.size,p))
  if not self:is_boundary(p) then return nil,"invalid_boundary" end
  while self.pos>p do
    local s=self.left[#self.left]; local n=math.min(self.pos-p,#s)
    local part=s:sub(#s-n+1); s=s:sub(1,#s-n)
    if s=="" then self.left[#self.left]=nil else self.left[#self.left]=s end
    local last=self.right[#self.right]
    if last and #last+#part<=M.BLOCK then self.right[#self.right]=part..last
    else self.right[#self.right+1]=part end
    self.pos=self.pos-n
  end
  while self.pos<p do
    local s=self.right[#self.right]; local n=math.min(p-self.pos,#s)
    push(self.left,s:sub(1,n)); s=s:sub(n+1)
    if s=="" then self.right[#self.right]=nil else self.right[#self.right]=s end
    self.pos=self.pos+n
  end
  return true
end
function B:replace(a,z,s,record,group)
  if not valid(s) or not self:is_boundary(a) or not self:is_boundary(z) or z<a then return nil,"invalid_text" end
  if self.size-(z-a)+#s>M.MAX then return nil,"Document limit: 32 KiB" end
  local old=self:slice(a,z)
  if old==s then self:seek(a+#s); return true end
  local left=a==0 or whitespace(self:byte(a-1))
  local right=z==self.size or whitespace(self:byte(z))
  self.words=self.words+contribution(s,left,right)-contribution(old,left,right)
  self:seek(z)
  while self.pos>a do
    local last=self.left[#self.left]; local n=math.min(self.pos-a,#last)
    last=last:sub(1,#last-n)
    if last=="" then self.left[#self.left]=nil else self.left[#self.left]=last end
    self.pos=self.pos-n
  end
  push(self.left,s); self.pos=a+#s; self.size=self.size-(z-a)+#s
  self.revision=(self.revision+1)%1000000000
  if record~=false then
    local branching=#self.redo>0
    for _,h in ipairs(self.redo) do self.history_bytes=self.history_bytes-#h.old-#h.new end
    self.redo={}
    local last=self.undo[#self.undo]
    if group and not branching and old=="" and last and last.group==group and last.old=="" and last.a+#last.new==a and #last.new+#s<=256 then
      last.new=last.new..s
    else
      local h={a=a,old=old,new=s,group=group}; self.undo[#self.undo+1]=h
    end
    self.history_bytes=self.history_bytes+#old+#s
    while #self.undo>100 or self.history_bytes>32768 do
      local first=table.remove(self.undo,1); self.history_bytes=self.history_bytes-#first.old-#first.new
    end
  end
  return true
end
function B:undo_edit(redo)
  local from,to=redo and self.redo or self.undo,redo and self.undo or self.redo
  local h=from[#from]; if not h then return false end
  local old,new=redo and h.old or h.new,redo and h.new or h.old
  local ok,err=self:replace(h.a,h.a+#old,new,false)
  if not ok then return nil,err end
  from[#from]=nil; to[#to+1]=h
  return true
end
return M
