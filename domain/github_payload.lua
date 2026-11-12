-- Pure GitHub Contents representation boundary; no URLs, credentials or HTTP I/O.
local Sync=require('domain.sync')
local M={}
function M.read(status,payload,path,codec)
  if not Sync.path_ok(path)then return nil,'invalid_path'end
  if type(codec)~='table'or type(codec.encode)~='function'or type(codec.decode)~='function'then return nil,'invalid_codec'end
  if status==404 then return {exists=false}end
  if status~=200 then return nil,select(2,Sync.error_state(status))end
  if type(payload)~='table'or payload.type~='file'or payload.path~=path
    or payload.name~=path:sub(11)or not Sync.hex_ok(payload.sha,40)or payload.encoding~='base64'
    or type(payload.size)~='number'or payload.size%1~=0 or payload.size<0 or payload.size>32768
    or type(payload.content)~='string'or #payload.content>45000 then return nil,'invalid_contents'end
  local encoded=payload.content:gsub('[\r\n]','')
  if #encoded>43692 or #encoded%4~=0 or encoded:find('[^A-Za-z0-9+/=]')then return nil,'invalid_base64'end
  local ok,bytes=pcall(codec.decode,encoded)
  if not ok or not Sync.text_ok(bytes)or #bytes~=payload.size then return nil,'invalid_document'end
  local roundtrip,canonical=pcall(codec.encode,bytes)
  if not roundtrip or canonical~=encoded then return nil,'invalid_base64'end
  return {exists=true,sha=payload.sha,bytes=bytes}
end
function M.write_request(scope,path,bytes,sha,codec)
  if type(codec)~='table'or type(codec.encode)~='function'then return nil,'invalid_codec'end
  if not Sync.scope_ok(scope)or not Sync.path_ok(path)or not Sync.text_ok(bytes)
    or (sha~=nil and not Sync.hex_ok(sha,40))then return nil,'invalid_write'end
  local ok,encoded=pcall(codec.encode,bytes)
  if not ok or type(encoded)~='string'or #encoded>43692 then return nil,'encode_failed'end
  return {method='PUT',repo=scope.repo,path=path,body={branch=scope.branch,
    message='inkWrite: '..(sha and 'update 'or 'create ')..path:sub(11),content=encoded,sha=sha}}
end
-- Validate the Contents response; a commit SHA never substitutes for a blob SHA.
function M.written(status,payload,path,fingerprint)
  if not Sync.path_ok(path)or not Sync.hex_ok(fingerprint,64)then return nil,'invalid_write'end
  if status~=200 and status~=201 then return nil,select(2,Sync.error_state(status))end
  local content=type(payload)=='table'and payload.content
  if type(content)~='table'or content.type~='file'or content.path~=path
    or not Sync.hex_ok(content.sha,40)then return nil,'invalid_write_response'end
  return {ok=true,status=status,path=path,sha=content.sha,fingerprint=fingerprint}
end
return M
