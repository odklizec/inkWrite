-- Read-only measured source pages. One page of lines, bounded byte offsets only.
local Layout=require('domain.layout')
local M={}
function M.new(review,side)
 local bytes=review.file.bytes
 if side=='github'then
  if not review.remote.exists then return nil end
  bytes=review.remote.bytes
 end
 if type(bytes)~='string'then return nil end
 local buffer={size=#bytes}
 function buffer:slice(a,z)return bytes:sub(a+1,z)end
 function buffer:is_boundary(p)local b=bytes:byte(p+1);return p==0 or p==#bytes or (b and (b<128 or b>=192))end
 local r={side=side,page=1,starts={0},lines={},more=false,bytes=#bytes}
 function r:prepare(ctx,font,width,height)
  local count=math.max(1,math.min(128,height//(font.line_height+4)))
  local layout=width..':'..count
  if self.layout and self.layout~=layout then self.page=1;self.starts={0}end
  self.layout=layout
  local key=layout..':'..self.page
  if self.key==key then return end
  if ctx.budget then ctx.budget:extend()end
  self.lines=Layout.rows(buffer,font,width,self.starts[self.page],count)
  local last=self.lines[#self.lines];self.nextp=last and last.nextp or #bytes
  self.more=self.nextp<#bytes and self.nextp>self.starts[self.page]
  self.key=key
 end
 function r:turn(delta)
  if delta>0 and self.more and self.page<32769 then
   self.starts[self.page+1]=self.nextp;self.page=self.page+1;self.key=nil
  elseif delta<0 and self.page>1 then self.page=self.page-1;self.key=nil end
 end
 return r
end
return M
