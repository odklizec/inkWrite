// Test-only standard primitives. Never packaged as executable XTApp code.
const crypto=require('node:crypto');
module.exports=function install(L,{lua,to_luastring,to_jsstring}) {
  const str=s=>lua.lua_pushstring(L,to_luastring(s));
  const nullMarker={};
  function value(index,depth=0,seen=new Set()) {
    if(depth>32)throw Error('depth');
    switch(lua.lua_type(L,index)) {
      case lua.LUA_TLIGHTUSERDATA:if(lua.lua_touserdata(L,index)===nullMarker)return null;throw Error('userdata');
      case lua.LUA_TBOOLEAN:return !!lua.lua_toboolean(L,index);
      case lua.LUA_TNUMBER:{const n=lua.lua_tonumber(L,index);if(!Number.isFinite(n))throw Error('number');return n;}
      case lua.LUA_TSTRING:return to_jsstring(lua.lua_tolstring(L,index));
      case lua.LUA_TTABLE:{
        const absolute=lua.lua_absindex(L,index),ptr=lua.lua_topointer(L,index);
        if(seen.has(ptr))throw Error('cycle');seen.add(ptr);
        const entries=[];lua.lua_pushnil(L);
        while(lua.lua_next(L,absolute)) {
          const keyType=lua.lua_type(L,-2);
          if(keyType!==lua.LUA_TSTRING&&keyType!==lua.LUA_TNUMBER)throw Error('key');
          entries.push([keyType===lua.LUA_TNUMBER?lua.lua_tonumber(L,-2):to_jsstring(lua.lua_tolstring(L,-2)),value(-1,depth+1,seen)]);
          lua.lua_pop(L,1);
        }
        seen.delete(ptr);
        if(entries.every(([k])=>Number.isInteger(k)&&k>=1&&k<=entries.length)) {
          const result=[];for(const [k,v]of entries)result[k-1]=v;return result;
        }
        if(entries.some(([k])=>typeof k!=='string'))throw Error('mixed keys');
        return Object.fromEntries(entries.sort(([a],[b])=>a<b?-1:a>b?1:0));
      }
      default:throw Error('unsupported');
    }
  }
  function push(v) {
    if(v===null){lua.lua_pushlightuserdata(L,nullMarker);return;}
    if(typeof v==='string'){str(v);return;}
    if(typeof v==='number'){lua.lua_pushnumber(L,v);return;}
    if(typeof v==='boolean'){lua.lua_pushboolean(L,v);return;}
    lua.lua_newtable(L);
    if(Array.isArray(v))for(let i=0;i<v.length;i++){push(v[i]);lua.lua_rawseti(L,-2,i+1);}
    else for(const [k,x]of Object.entries(v)){push(x);lua.lua_setfield(L,-2,to_luastring(k));}
  }
  const bytes=()=>Buffer.from(lua.lua_tolstring(L,1));
  const methods={
    sha256:()=>str(crypto.createHash('sha256').update(bytes()).digest('hex')),
    encode:()=>str(JSON.stringify(value(1))),
    decode:()=>push(JSON.parse(to_jsstring(lua.lua_tolstring(L,1)))),
    base64_encode:()=>str(bytes().toString('base64')),
    base64_decode:()=>{const b=Buffer.from(to_jsstring(lua.lua_tolstring(L,1)),'base64');lua.lua_pushlstring(L,b,b.length);},
  };
  lua.lua_getglobal(L,to_luastring('package'));lua.lua_getfield(L,-1,to_luastring('loaded'));lua.lua_newtable(L);
  lua.lua_pushlightuserdata(L,nullMarker);lua.lua_setfield(L,-2,to_luastring('null'));
  for(const [name,fn]of Object.entries(methods)) {
    lua.lua_pushcfunction(L,()=>{const top=lua.lua_gettop(L);try{fn();return 1;}catch{lua.lua_settop(L,top);lua.lua_pushnil(L);str('invalid_argument');return 2;}});
    lua.lua_setfield(L,-2,to_luastring(name));
  }
  lua.lua_setfield(L,-2,to_luastring('test_native'));lua.lua_pop(L,2);
};
