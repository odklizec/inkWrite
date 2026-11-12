// Every suite gets a fresh Lua VM. Existing regression files are unmodified.
const fs=require('node:fs');
const path=require('node:path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require(process.env.INKWRITE_FENGARI || 'fengari');
const root=path.resolve(__dirname,'..');
const probeDir=path.join(root,'tools/github-sync-probe');
const suites=process.argv.includes('--probe')?[]:fs.readdirSync(__dirname).filter(n=>n.endsWith('.lua')).sort().map(n=>'tests/'+n);
suites.push('tools/github-sync-probe/test.lua');
let failures=0,total=0;
for(const suite of suites) {
  const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
  function execute(source) {
    lua.lua_settop(L,0);
    if(lauxlib.luaL_dostring(L,to_luastring(source)))throw Error(to_jsstring(lua.lua_tostring(L,-1)));
  }
  try {
    const modules=['keyboard',...fs.readdirSync(path.join(root,'domain')).filter(n=>n.endsWith('.lua')).map(n=>'domain.'+n.slice(0,-4))];
    for(const name of modules)execute(`package.preload[${JSON.stringify(name)}]=function(...)\n${fs.readFileSync(path.join(root,name.replaceAll('.','/')+'.lua'),'utf8')}\nend`);
    execute(`package.preload.probe=function(...)\n${fs.readFileSync(path.join(probeDir,'probe.lua'),'utf8')}\nend`);
    // Compile the standalone entry too; it must not run inside the editor tests.
    const status=lauxlib.luaL_loadstring(L,to_luastring(fs.readFileSync(path.join(probeDir,'index.lua'),'utf8')));
    if(status)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
    execute(fs.readFileSync(path.join(root,suite),'utf8'));
    const assertions=lua.lua_isnumber(L,-1)?lua.lua_tointeger(L,-1):0;
    total+=assertions;
    console.log(`PASS ${suite}: ${assertions} assertions`);
  } catch(e) {failures++;console.log(`FAIL ${suite}: ${e.message}`);}
  finally {lua.lua_close(L);}
}
console.log(`${suites.length-failures}/${suites.length} suites passed; ${total} assertions in completed suites; ${failures} failures`);
process.exitCode=failures?1:0;
