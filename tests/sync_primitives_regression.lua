local Primitives=require('domain.sync_primitives')
local Native=require('test_native')
local Payload=require('domain.github_payload')
local n=0
local function check(v,msg)n=n+1;assert(v,msg)end
local ctx={hash={},hex={},base64={}}
ctx.hash.sha256=function(_,bytes)return (Native.sha256(bytes):gsub('..',function(pair)return string.char(tonumber(pair,16))end))end
ctx.hex.encode=function(_,bytes)return (bytes:gsub('.',function(c)return string.format('%02x',c:byte())end))end
ctx.base64.encode=function(_,bytes)return Native.base64_encode(bytes)end
ctx.base64.decode=function(_,bytes)return Native.base64_decode(bytes)end
local p=assert(Primitives.new(ctx))
check(p.hash('abc')=='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','raw digest encoded once to lowercase hex')
for _,bytes in ipairs({'','a','ab','abc','Čaj žluťoučký\r\n',string.rep('x',32768)})do
 check(p.codec.decode(p.codec.encode(bytes))==bytes,'host codec preserves exact bytes')
 local req=assert(Payload.write_request({repo='example/docs',branch='main'},'documents/ideas.md',bytes,nil,p.codec))
 check(Native.base64_decode(req.body.content)==bytes,'host primitives work at payload boundary')
end
check(p.hash(string.rep('x',65537))==nil,'bounded metadata hash input')
check(p.codec.encode(string.rep('x',32769))==nil,'bounded encoding input')
check(p.codec.decode(string.rep('x',43693))==nil,'bounded decoding input')
check(Primitives.new({})==nil,'missing primitives fail closed')
ctx.hash.sha256=function()error('private exception')end
check(p.hash('x')==nil,'hash exception contained')
ctx.hash.sha256=function()return 'short'end
check(p.hash('x')==nil,'wrong raw digest rejected')
ctx.hash.sha256=function()return string.rep('x',32)end
ctx.hex.encode=function()return string.rep('A',64)end
check(p.hash('x')==nil,'unexpected hex encoding rejected')
ctx.base64.decode=function()return string.rep('x',32769)end
check(p.codec.decode('eA==')==nil,'oversized decoded output rejected')
ctx.base64.encode=function()error('private exception')end
check(p.codec.encode('x')==nil,'codec exception contained')
return n
