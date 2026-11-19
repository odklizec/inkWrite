-- Real document-save/recovery code with synthetic storage and failing SD writes.
local Docs=require('domain.documents')
local Sync=require('domain.sync')
local Mock=require('tests.support.sync_mock')
local n=0
local function check(v,message)n=n+1;assert(v,message)end
local old='Pôvodný čaj\r\n';local edited='Nový žluťoučký text\r\n'
local files={['ideas.md']=old};local private={};local public_writes=0
local fail_recovery,fail_public=false,false
local ctx={storage={},files={}}
ctx.storage.read=function(_,name)if private[name]then return private[name]end;return nil,'not_found'end
ctx.storage.write=function(_,name,bytes)if fail_recovery then return nil,'io_error'end;private[name]=bytes;return true end
ctx.storage.remove=function(_,name)private[name]=nil;return true end
ctx.files.size=function(_,name)if files[name]then return #files[name]end;return nil,'not_found'end
ctx.files.read=function(_,name,offset,length)if files[name]then return files[name]:sub(offset+1,offset+length)end;return nil,'not_found'end
ctx.files.write=function(_,name,bytes)if fail_public then return nil,'io_error'end;public_writes=public_writes+1;files[name]=bytes;return true end
local doc={name='ideas.md',base=old}
-- Sync starts disabled and cannot prevent a local save while offline.
local core=Sync.new(Mock.hash)
check(core:begin('upload',{name=doc.name,revision=1,exists=true,saved=true,bytes=old})==nil,'sync disabled by default')
check(Docs.save(ctx,doc,edited)==true,'offline local save succeeds')
check(files['ideas.md']==edited and private['recovery.txt']==nil,'exact bytes saved and matching recovery removed')
fail_recovery=true;local before=public_writes
check(Docs.save(ctx,doc,edited..' edit')==nil,'recovery failure blocks public save')
check(public_writes==before and files['ideas.md']==edited and doc.base==edited,'recovery failure preserves public file/base')
fail_recovery=false;fail_public=true
check(Docs.save(ctx,doc,edited..' edit')==nil,'SD failure reported')
local recovered=assert(Docs.load_recovery(ctx))
check(recovered.text==edited..' edit' and files['ideas.md']==edited and doc.base==edited,'newest recovery survives failed public write')
fail_public=false
check(Docs.save(ctx,doc,recovered.text)==true,'explicit retry succeeds')
files['ideas.md']='External edit\r\n'
check(Docs.save(ctx,doc,edited)==true,'external change saves local conflict copy')
check(doc.name~='ideas.md' and files['ideas.md']=='External edit\r\n' and files[doc.name]==edited,'conflict preserves both documents')
private['recovery.txt']='INKWRITE1\nideas.md\n\255'
local malformed=private['recovery.txt'];before=public_writes
check(Docs.load_recovery(ctx)==nil and private['recovery.txt']==malformed,'malformed recovery retained untouched')
files['invalid.md']='\255'
check(Docs.read(ctx,'invalid.md')==nil and files['invalid.md']=='\255','invalid public UTF-8 retained')
files['large.md']=string.rep('x',32769)
check(Docs.read(ctx,'large.md')==nil and #files['large.md']==32769,'oversized public document retained')
core:configure(true,true)
local id=core:begin('upload',{name='ideas.md',revision=2,exists=true,saved=true,bytes=files['ideas.md']})
core:failed(id,nil,'no_network')
check(core.state=='offline' and public_writes==before and private['recovery.txt']==malformed,'network failure cannot write public or recovery data')
return n
