local Native=require('test_native')
local M={OLD=string.rep('a',40),NEW=string.rep('b',40),RACE=string.rep('c',40)}
function M.file(name,bytes,sha)
  return {type='file',name=name,path='documents/'..name,sha=sha or M.OLD,size=#bytes,encoding='base64',content=Native.base64_encode(bytes)}
end
function M.written(path,sha)return {content={type='file',path=path,sha=sha or M.NEW},commit={sha=string.rep('d',40)}}end
M.errors={[401]={message='Bad credentials'},[403]={message='Forbidden'},[409]={message='Conflict'},[422]={message='Validation failed'},[429]={message='Rate limit'},[500]={message='Server error'}}
return M
