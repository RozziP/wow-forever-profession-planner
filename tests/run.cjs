const fs = require('node:fs');
const path = require('node:path');
const { lauxlib, lua, lualib, to_jsstring, to_luastring } = require('fengari');
const luaparse = require('luaparse');

const addonName = 'ForeverProfessionPlanner';
const addonDirectory = path.resolve(__dirname, '..', 'addon', addonName);

function checkLua(file) {
  try {
    luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
  } catch (error) {
    throw new Error(file + ' — ' + error.message);
  }
}

function runLua(state, file) {
  const status = lauxlib.luaL_loadfile(state, to_luastring(file)) ||
    lua.lua_pcall(state, 0, 0, 0);
  if (status !== lua.LUA_OK) throw new Error(to_jsstring(lua.lua_tostring(state, -1)));
}

function runSuite(name, addonFiles) {
  const state = lauxlib.luaL_newstate();
  try {
    lualib.luaL_openlibs(state);
    lua.lua_createtable(state, addonFiles.length, 0);
    for (const [index, file] of addonFiles.entries()) {
      lua.lua_pushstring(state, to_luastring(file));
      lua.lua_rawseti(state, -2, index + 1);
    }
    lua.lua_setglobal(state, to_luastring('FPT_ADDON_FILES'));

    runLua(state, path.join(__dirname, 'wow-mock.lua'));
    runLua(state, path.join(__dirname, name));
  } finally {
    lua.lua_close(state);
  }
}

try {
  const manifest = fs.readFileSync(path.join(addonDirectory, addonName + '.toc'), 'utf8');
  const addonFiles = manifest.split(/\r?\n/)
    .map(line => line.trim())
    .filter(line => line && !line.startsWith('#'))
    .map(line => path.join(addonDirectory, line.replaceAll('\\', '/')));
  if (!addonFiles.length) throw new Error('The addon TOC has no load entries.');
  for (const file of addonFiles) checkLua(file);
  console.log('PASS Lua 5.1 syntax for ' + addonFiles.length + ' TOC entries');
  for (const name of ['quotes.lua', 'planner.lua', 'cost-display.lua']) runSuite(name, addonFiles);
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
}
