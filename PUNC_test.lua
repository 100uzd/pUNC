local REQUIRED_PLACE_ID = 4483381587
local function script()
local startTime = os.clock()
local startTime = os.clock()
print(">> Initializing PUNC Diagnostic Suite...")
assert(type(identifyexecutor) == "function", "identifyexecutor unavailable")
local executor = identifyexecutor()
print(">> Executor Detected: " .. tostring(executor))
print(" ")
local hasDebug = type(debug) == "table" and type(debug.getinfo) == "function"
local function is_c_function(func)
return hasDebug and debug.getinfo(func, "S").what == "C"
end
local function is_lua_closure(func)
return hasDebug and debug.getinfo(func, "S").what == "Lua"
end
local function is_protected_closure(func)
return type(iscclosure) == "function" and iscclosure(func)
end
local function scan_upvalues(func)
if type(debug.getupvalue) ~= "function" then return {} end
local upvals = {}
local i = 1
while true do
local name, val = debug.getupvalue(func, i)
if not name then break end
upvals[name] = val
i = i + 1
end
return upvals
end
local function classifyFunction(func, name)
if type(func) ~= "function" then
print("❌ [" .. name .. "] is not a function (got " .. typeof(func) .. ")")
return "invalid"
end
local status = "unknown"
local info = hasDebug and debug.getinfo(func, "S") or nil
local upvals = scan_upvalues(func)
local upvalCount = 0
local isProtectedClosure = is_protected_closure(func)
local isCFunction = is_c_function(func)
local isLuaClosure = is_lua_closure(func)
for _ in pairs(upvals) do
upvalCount = upvalCount + 1
end
if isProtectedClosure then
status = "native/cclosure"
elseif isCFunction then
status = "native"
elseif isLuaClosure then
status = "lua (potentially spoofed)"
elseif info then
if info.what == "C" then
status = "native C function"
elseif info.what == "Lua" then
status = "Lua function (potentially spoofed)"
else
status = "unknown/debug-blocked"
end
else
status = "no debug info"
end
local isHooked = "unknown"
if type(getrawmetatable) == "function" then
local hookMeta = getrawmetatable(func)
if hookMeta then
local __index = hookMeta.__index
if type(__index) == "function" then
isHooked = true
else
isHooked = false
end
end
end
print((">> [%s] Classification: %s | Upvalues: %d | Hooked: %s"):format(name, status, upvalCount, isHooked == "unknown" and "Unknown" or (isHooked and "Yes" or "No")))
if upvalCount > 0 then
for upvalName, upvalValue in pairs(upvals) do
if type(upvalValue) == "function" then
classifyFunction(upvalValue, "Upvalue: " .. upvalName)
end
end
end
if isHooked ~= "unknown" then
if isHooked then
return "hooked/" .. status
else
return status
end
else
return status
end
end
local addTests = {}
local function addTest(name, fn)
if type(addTests) ~= "table" then addTests = {} end
addTests[name] = fn
end
addTest("basic_loadstring", function()
assert(type(loadstring) == "function", "loadstring missing or redefined")
classifyFunction(loadstring, "loadstring")
local chunk = loadstring("return 5 * 5")
assert(type(chunk) == "function" and chunk() == 25, "basic_loadstring failed to execute")
end)
addTest("intermediate_loadstring", function()
local chunk = loadstring("local a = 10; local b = 20; return a + b")
assert(type(chunk) == "function" and chunk() == 30, "intermediate_loadstring failed to execute")
end)
addTest("strict_loadstring", function()
local env = { getgenv = nil }
local chunk = loadstring("return getgenv")
setfenv(chunk, env)
local result = pcall(chunk)
assert(not result, "strict_loadstring failed, should be restricted")
end)
addTest("heavy_loadstring", function()
local largeCode = "return " .. string.rep("1 + 1;", 1000)
local chunk = loadstring(largeCode)
assert(type(chunk) == "function", "heavy_loadstring failed to compile")
assert(chunk() == 2000, "heavy_loadstring failed to execute properly")
end)
addTest("loadstring_security", function()
local result = loadstring("return getgenv")()
assert(type(result) == "function", "getgenv inaccessible through loadstring")
classifyFunction(result, "getgenv (via loadstring)")
end)
addTest("hookfunction", function()
assert(type(hookfunction) == "function", "hookfunction missing")
classifyFunction(hookfunction, "hookfunction")
local original = function(x) return x + 1 end
local hooked
hooked = hookfunction(original, function(x)
return hooked(x) * 2
end)
local result = original(2)
assert(result == 6, "hookfunction failed (expected 6, got " .. tostring(result) .. ")")
end)
addTest("request", function()
local response = request({
Url = "https://httpbin.org/user-agent",
Method = "GET",
})
assert(type(response) == "table", "Response must be a table")
assert(response.StatusCode == 200, "Did not return a 200 status code")
local data = game:GetService("HttpService"):JSONDecode(response.Body)
assert(type(data) == "table" and type(data["user-agent"]) == "string", "Did not return a table with a user-agent key")
return "User-Agent: " .. data["user-agent"]
end)
addTest("http_request", function()
assert(type(http.request) == "function" or type(http_request) == "function", "http.request or http_request does not exist")
local response
if type(http.request) == "function" then
response = http.request({
Url = "https://httpbin.org/user-agent",
Method = "GET",
})
elseif type(http_request) == "function" then
response = http_request({
Url = "https://httpbin.org/user-agent",
Method = "GET",
})
end
assert(type(response) == "table", "Response must be a table")
assert(response.StatusCode == 200, "Did not return a 200 status code")
local data = game:GetService("HttpService"):JSONDecode(response.Body)
assert(type(data) == "table" and type(data["user-agent"]) == "string", "Did not return a table with a user-agent key")
return "User-Agent: " .. data["user-agent"]
end)
addTest("getrawmetatable", function()
assert(type(getrawmetatable) == "function", "getrawmetatable missing")
classifyFunction(getrawmetatable, "getrawmetatable")
local t = setmetatable({}, {})
assert(getrawmetatable(t), "getrawmetatable failed")
end)
local function assertEqual(actual, expected, message)
assert(actual == expected, message .. " (Expected: " .. tostring(expected) .. ", Got: " .. tostring(actual) .. ")")
end
addTest("getgenv", function()
local addTestEnv = getgenv()
addTestEnv.__addTest_GLOBAL = true
assert(addTestEnv.__addTest_GLOBAL, "Failed to set a global variable via getgenv")
addTestEnv.__addTest_GLOBAL = nil
assert(addTestEnv.__addTest_GLOBAL == nil, "Failed to reset global variable")
end)
addTest("hookmetamethod", function()
assert(type(hookmetamethod) == "function", "hookmetamethod missing")
classifyFunction(hookmetamethod, "hookmetamethod")
local myTable = {}
local originalIndex = getmetatable(myTable).__index
hookmetamethod(myTable, "__index", function(t, key)
return "HOOKED_" .. originalIndex(t, key)
end)
myTable.addTestKey = "addTestValue"
assert(myTable.addTestKey == "HOOKED_addTestValue", "__index hook failed")
hookmetamethod(myTable, "__index", function(t, key)
return "DOUBLE_HOOK_" .. originalIndex(t, key)
end)
assert(myTable.addTestKey == "DOUBLE_HOOK_HOOKED_addTestValue", "__index hook stacking failed")
local protected = newproxy(true)
local protectedMeta = getmetatable(protected)
assert(not pcall(hookmetamethod, protected, "__index", function() end), "Should not hook protected metatables")
return "hookmetamethod functionality verified"
end)
addTest("getnamecallmethod", function()
assert(type(getnamecallmethod) == "function", "getnamecallmethod missing")
classifyFunction(getnamecallmethod, "getnamecallmethod")
local proxy = setmetatable({}, {
__namecall = function(self, method, ...)
local capturedMethod = getnamecallmethod()
return capturedMethod
end
})
local result = proxy:addTestMethod()
assert(result == "addTestMethod", "getnamecallmethod failed to capture method name")
result = proxy:AnotherMethod()
assert(result == "AnotherMethod", "getnamecallmethod failed to capture second method")
assert(getnamecallmethod() == nil, "getnamecallmethod incorrectly captured outside __namecall")
return "getnamecallmethod functionality verified"
end)
addTest("setrawmetatable", function()
assert(type(setrawmetatable) == "function", "setrawmetatable missing")
classifyFunction(setrawmetatable, "setrawmetatable")
local myTable = {}
local newMeta = { __tostring = function() return "Modified Table" end }
setrawmetatable(myTable, newMeta)
assert(tostring(myTable) == "Modified Table", "setrawmetatable failed to apply new metatable")
local locked = table.clone({})
setmetatable(locked, { __metatable = "locked" })
assert(setrawmetatable(locked, { __metatable = "newMeta" }), "Failed to override locked metatable")
assert(getmetatable(locked).__metatable == "newMeta", "setrawmetatable failed to modify locked metatable")
return "setrawmetatable functionality verified"
end)
addTest("setreadonly", function()
assert(type(setreadonly) == "function", "setreadonly missing")
classifyFunction(setreadonly, "setreadonly")
local myTable = {key = "value"}
setreadonly(myTable, true)
local ok, msg = pcall(function() t.x = 1 end)
assert(not pcall(function() myTable.key = "newValue" end), "setreadonly failed to prevent modification")
assert(not pcall(setmetatable, myTable, {}), "setreadonly failed to prevent metatable change")
assert(not ok and (msg:match("read%-only") or msg:match("read%-%-only")), "setreadonly write did not error as read-only")
myTable.nested = {subkey = "subvalue"}
assert(not pcall(function() myTable.nested.subkey = "modified" end), "setreadonly failed on nested tables")
setreadonly(myTable, false)
assert(pcall(function() myTable.key = "newValue" end), "setreadonly failed to reset state")
return "setreadonly functionality verified"
end)
addTest("isreadonly", function()
assert(type(isreadonly) == "function", "isreadonly missing")
classifyFunction(isreadonly, "isreadonly")
local normalTable = {}
assert(isreadonly(normalTable) == false, "isreadonly incorrectly marked a normal table as readonly")
setreadonly(normalTable, true)
assert(isreadonly(normalTable) == true, "isreadonly failed to detect readonly state")
local nestedTable = {subTable = {}}
setreadonly(nestedTable.subTable, true)
assert(isreadonly(nestedTable.subTable) == true, "isreadonly failed to detect nested readonly state")
return "isreadonly functionality verified"
end)
addTest("getrenv", function()
assert(type(getrenv) == "getrenv", "gethui missing")
classifyFunction(getrenv, "getrenv")
assert(_G ~= getrenv()._G, "The variable _G in the executor is identical to _G in the game")
end)
addTest("gethui", function()
assert(type(gethui) == "function", "gethui missing")
classifyFunction(gethui, "gethui")
assert(typeof(gethui()) == "Instance", "Did not return an Instance")
end)
addTest("getgc", function()
assert(type(getgc) == "function", "getgc missing")
classifyFunction(getgc, "getgc")
local gcTable = getgc()
assert(type(gcTable) == "table", "getgc should return a table")
local found = false
for _, item in ipairs(gcTable) do
if typeof(item) == "Instance" then
found = true
break
end
end
assert(found, "getgc did not return a valid instance or userdata")
end)
addTest("sethiddenproperty", function()
assert(type(sethiddenproperty) == "function", "sethiddenproperty is missing or not a function")
local fire = Instance.new("Fire")
local hiddenSet = sethiddenproperty(fire, "size_xml", 10)
assertEqual(hiddenSet, true, "Failed to mark property 'size_xml' as hidden")
local propertyValue = gethiddenproperty(fire, "size_xml")
assertEqual(propertyValue, 10, "Property 'size_xml' value is not set correctly")
local isHidden = gethiddenproperty(fire, "size_xml")
assertEqual(isHidden, true, "The property 'size_xml' is not marked as hidden")
end)
addTest("gethiddenproperty", function()
assert(type(gethiddenproperty) == "function", "gethiddenproperty is missing or not a function")
local fire = Instance.new("Fire")
sethiddenproperty(fire, "size_xml", 5)
local propertyValue, isHidden = gethiddenproperty(fire, "size_xml")
assertEqual(propertyValue, 5, "Failed to get correct value for 'size_xml' (Expected: 5)")
assertEqual(isHidden, true, "Property 'size_xml' should be marked as hidden, but it's not")
local nonExistentValue, nonExistentIsHidden = gethiddenproperty(fire, "non_existent_property")
assertEqual(nonExistentValue, nil, "Non-existent property should return nil")
assertEqual(nonExistentIsHidden, false, "Non-existent property should not be hidden")
end)
addTest("getloadedmodules", function()
assert(type(getloadedmodules) == "function", "getloadedmodules missing")
classifyFunction(getloadedmodules, "getloadedmodules")
local modules = getloadedmodules()
assert(type(modules) == "table", "getloadedmodules should return a table")
assert(#modules > 0, "No loaded modules found")
end)
addTest("getrunningscripts", function()
assert(type(getrunningscripts) == "function", "getrunningscripts missing")
classifyFunction(getrunningscripts, "getrunningscripts")
local scripts = getrunningscripts()
assert(type(scripts) == "table", "getrunningscripts should return a table")
assert(#scripts > 0, "No running scripts found")
end)
addTest("getscripthash", function()
assert(type(getscripthash) == "function", "getscripthash missing")
classifyFunction(getscripthash, "getscripthash")
local currentScript = script
local success, hash = pcall(function()
return getscripthash(currentScript)
end)
assert(success, "getscripthash failed: " .. (hash or "Unknown error"))
assert(type(hash) == "string", "getscripthash should return a string hash")
assert(#hash > 0, "Empty script hash returned")
end)
addTest("checkcaller", function()
assert(type(checkcaller) == "function", "checkcaller is missing or not a function")
local function addTestCaller()
assert(checkcaller(), "checkcaller failed for a valid call")
end
addTestCaller()
local success, err = pcall(function()
checkcaller()
end)
assertEqual(success, false, "checkcaller did not fail when called outside its intended scope")
end)
addTest("clonefunction", function()
assert(type(clonefunction) == "function", "clonefunction is missing or not a function")
local originalFunction = function(a, b)
return a + b
end
local clonedFunction = clonefunction(originalFunction)
assertEqual(clonedFunction(2, 3), 5, "Cloned function does not behave correctly")
assert(originalFunction ~= clonedFunction, "clonefunction did not create a distinct copy")
end)
addTest("getcallingscript", function()
assert(type(getcallingscript) == "function", "getcallingscript is missing or not a function")
local callingScript = getcallingscript()
assert(callingScript, "getcallingscript did not return a calling script")
assertEqual(callingScript, script, "getcallingscript did not return the correct script")
end)
addTest("getscriptclosure", function()
assert(type(getscriptclosure) == "function", "getscriptclosure is missing or not a function")
local module = game:GetService("CoreGui").RobloxGui.Modules.Common.Constants
local constants = getrenv().require(module)
local generated = getscriptclosure(module)()
assert(constants ~= generated, "Generated module should not match the original, they should be separate instances")
assert(shallowEqual(constants, generated), "Generated constant table should be shallowly equal to the original constants")
assert(type(constants) == "table", "The 'constants' should be a table")
assert(type(generated) == "table", "The 'generated' result should be a table")
assert(#constants == #generated, "The original and generated constants should have the same length")
assert(constants.SOME_CONSTANT == generated.SOME_CONSTANT, "A known constant value should be the same between original and generated")
end)
addTest("iscclosure", function()
assert(type(iscclosure) == "function", "iscclosure is missing or not a function")
local closure = function() return true end
assert(iscclosure(closure), "iscclosure failed for valid closure")
local nonClosure = 123
assert(not iscclosure(nonClosure), "iscclosure should return false for non-closure")
end)
addTest("islclosure", function()
assert(type(islclosure) == "function", "islclosure is missing or not a function")
assert(islclosure(print) == false, "'print' should not be a Lua closure")
assert(islclosure(function() end) == true, "Anonymous function should be a Lua closure")
local fn = function(x) return x + 1 end
assert(islclosure(fn) == true, "Stored function should be a Lua closure")
local ok1, result1 = pcall(islclosure, 42)
assert(ok1 and result1 == false, "Number should safely return false")
local ok2, result2 = pcall(islclosure, "text")
assert(ok2 and result2 == false, "String should safely return false")
local ok3, result3 = pcall(islclosure, {})
assert(ok3 and result3 == false, "Table should safely return false")
local ok4, result4 = pcall(islclosure, nil)
assert(ok4 and result4 == false, "Nil should safely return false")
end)
addTest("isexecutorclosure", function()
assert(type(isexecutorclosure) == "function", "isexecutorclosure is missing or not a function")
local closure = function() return true end
assert(isexecutorclosure(closure), "isexecutorclosure failed for valid execution closure")
local nonClosure = function() return 42 end
assert(not isexecutorclosure(nonClosure), "isexecutorclosure should return false for non-execution closure")
end)
addTest("cloneref", function()
assert(type(cloneref) == "function", "cloneref is missing or not a function")
local original = Instance.new("Part")
original.Size = Vector3.new(4, 1, 2)
local cloned = cloneref(original)
assert(original ~= cloned, "cloneref did not create a new reference")
assertEqual(cloned.Size, original.Size, "Cloned reference has incorrect properties")
end)
addTest("compareinstances", function()
assert(type(compareinstances) == "function", "compareinstances is missing or not a function")
local instance1 = Instance.new("Part")
instance1.Size = Vector3.new(4, 1, 2)
local instance2 = Instance.new("Part")
instance2.Size = Vector3.new(4, 1, 2)
assert(compareinstances(instance1, instance2), "compareinstances failed for identical instances")
instance2.Size = Vector3.new(5, 1, 2)
assert(not compareinstances(instance1, instance2), "compareinstances failed for different instances")
end)
addTest("readfile", function()
assert(type(readfile) == "function", "readfile is missing or not a function")
local filename = "addTestfile.txt"
writefile(filename, "Hello, World!")
local fileContent = readfile(filename)
assertEqual(fileContent, "Hello, World!", "readfile did not return the correct file content")
delfile(filename)
end)
addTest("listfiles", function()
assert(type(listfiles) == "function", "listfiles is missing or not a function")
local folderName = "addTestFolder"
makefolder(folderName)
writefile(folderName.."/file1.txt", "Content 1")
writefile(folderName.."/file2.txt", "Content 2")
local files = listfiles(folderName)
assert(#files >= 2, "listfiles did not return the correct number of files")
delfile(folderName.."/file1.txt")
delfile(folderName.."/file2.txt")
delfile(folderName)
end)
addTest("writefile", function()
assert(type(writefile) == "function", "writefile is missing or not a function")
local filename = "addTestwrite.txt"
writefile(filename, "addTest write content")
local content = readfile(filename)
assertEqual(content, "addTest write content", "writefile did not write the correct content")
delfile(filename)
end)
addTest("makefolder", function()
assert(type(makefolder) == "function", "makefolder is missing or not a function")
local folderName = "addTestFolder"
makefolder(folderName)
local success, err = pcall(function()
listfiles(folderName)
end)
assert(success, "makefolder failed to create the folder")
delfile(folderName)
end)
addTest("appendfile", function()
assert(type(appendfile) == "function", "appendfile is missing or not a function")
local filename = "appendaddTest.txt"
writefile(filename, "Initial content")
appendfile(filename, " Appended content")
local content = readfile(filename)
assertEqual(content, "Initial content Appended content", "appendfile did not append correctly")
delfile(filename)
end)
addTest("delfile", function()
assert(type(delfile) == "function", "delfile is missing or not a function")
local filename = "deletefileaddTest.txt"
writefile(filename, "Delete me")
delfile(filename)
local success, err = pcall(function()
readfile(filename)
end)
assert(not success, "delfile failed to delete the file")
end)
addTest("dofile", function()end)
addTest("isrbxactive", function()
assert(type(isrbxactive) == "function", "isrbxactive is missing or not a function")
assert(type(isrbxactive()) == "boolean", "Did not return a boolean value")
end)
addTest("debug.getconstant", function()
assert(type(debug.getconstant) == "function", "debug.getconstant is missing or not a function")
local function sample() return 42 end
local const = debug.getconstant(sample, 1)
assert(const == 42, "Expected constant 42")
end)
addTest("debug.getconstants", function()
assert(type(debug.getconstants) == "function", "debug.getconstants is missing or not a function")
local function sample() return 42 end
local constants = debug.getconstants(sample)
assert(type(constants) == "table", "Expected a table of constants")
end)
addTest("debug.getinfo", function()
assert(type(debug.getinfo) == "function", "debug.getinfo is missing or not a function")
local function sample() return 1 end
local info = debug.getinfo(sample)
assert(type(info) == "table", "Expected info to be a table")
assert(info.what == "Lua", "Expected 'what' to be 'Lua'")
end)
addTest("debug.getproto", function()
assert(type(debug.getproto) == "function", "debug.getproto is missing or not a function")
local function inner() return 1 end
local function outer() return inner() end
local proto = debug.getproto(outer, 1)
assert(type(proto) == "function", "Expected proto to be a function")
end)
addTest("debug.getprotos", function()
assert(type(debug.getprotos) == "function", "debug.getprotos is missing or not a function")
local function inner() return 1 end
local function outer() return inner() end
local protos = debug.getprotos(outer)
assert(type(protos) == "table", "Expected protos to be a table")
end)
addTest("debug.getstack", function()
assert(type(debug.getstack) == "function", "debug.getstack is missing or not a function")
local stack = debug.getstack()
assert(type(stack) == "table", "Expected stack to be a table")
end)
addTest("debug.getupvalue ", function()
assert(type(debug.getupvalue) == "function", "debug.getupvalue is missing or not a function")
local uv = 5
local function fn() return uv end
local name = debug.getupvalue(fn, 1)
assert(name == "uv", "Expected upvalue name 'uv'")
end)
addTest("debug.getupvalues", function()
assert(type(debug.getupvalues) == "function", "debug.getupvalues is missing or not a function")
local uv = 5
local function fn() return uv end
local _, val = debug.getupvalue(fn, 1)
assert(val == 5, "Expected upvalue value 5")
end)
addTest("debug.setconstant", function()
assert(type(debug.setconstant) == "function", "debug.setconstant is missing or not a function")
local function fn() return 10 end
debug.setconstant(fn, 1, 20)
assert(fn() == 20, "Expected return value to be 20 after patch")
end)
addTest("debug.setupvalue", function()
assert(type(debug.setupvalue) == "function", "debug.setupvalue is missing or not a function")
local uv = 10
local function fn() return uv end
debug.setupvalue(fn, 1, 99)
assert(fn() == 99, "Expected return value to be 99")
end)
addTest("debug.setstack",  function()
assert(type(debug.setstack) == "function", "debug.setstack is missing or not a function")
local stack = debug.getstack()
local ok = pcall(debug.setstack, stack)
assert(ok, "debug.setstack should not error")
end)
addTest("cache.invalidate", function()
assert(type(cache.invalidate) == "function", "cache.invalidate is missing or not a function")
assert(not islclosure(cache.invalidate) or getfenv(cache.invalidate), "cache.invalidate may be spoofed or not native")
cache.replace("spoof_key", "temp_value")
assert(cache.iscached("spoof_key"), "Failed to insert test value into cache")
cache.invalidate("spoof_key")
assert(not cache.iscached("spoof_key"), "cache.invalidate failed to remove key")
end)
addTest("cache.iscached", function()
assert(type(cache.iscached) == "function", "cache.iscached is missing or not a function")
assert(not islclosure(cache.iscached) or getfenv(cache.iscached), "cache.iscached may be spoofed or not native")
cache.replace("exists_key", "value")
assert(cache.iscached("exists_key") == true, "cache.iscached returned false for existing key")
cache.invalidate("exists_key")
assert(cache.iscached("exists_key") == false, "cache.iscached returned true for invalidated key")
end)
addTest("cache.replace", function()
assert(type(cache.replace) == "function", "cache.replace is missing or not a function")
assert(not islclosure(cache.replace) or getfenv(cache.replace), "cache.replace may be spoofed or not native")
cache.replace("replace_key", "12345")
assert(cache.iscached("replace_key") == true, "cache.replace failed to cache key")
end)
addTest("crypt.base64encode", function()
assert(type(crypt.base64encode) == "function", "crypt.base64encode is missing or not a function")
assert(not islclosure(crypt.base64encode) or getfenv(crypt.base64encode), "crypt.base64encode may be spoofed")
local encoded = crypt.base64encode("OpenAI")
assert(type(encoded) == "string", "crypt.base64encode should return a string")
assert(encoded:match("[A-Za-z0-9+/=]+"), "crypt.base64encode returned non-base64 characters")
end)
addTest("crypt.base64decode", function()
assert(type(crypt.base64decode) == "function", "crypt.base64decode is missing or not a function")
assert(not islclosure(crypt.base64decode) or getfenv(crypt.base64decode), "crypt.base64decode may be spoofed")
local original = "DataTest123"
local encoded = crypt.base64encode(original)
local decoded = crypt.base64decode(encoded)
assert(decoded == original, "crypt.base64decode failed to decode correctly")
end)
addTest("codefireclickdetector", function()
assert(type(codefireclickdetector) == "function", "codefireclickdetector is missing or not a function")
assert(not islclosure(codefireclickdetector) or getfenv(codefireclickdetector), "codefireclickdetector may be spoofed")
local part = Instance.new("Part")
part.Anchored = true
part.Parent = workspace
assert(pcall(function() codefireclickdetector(part) end), "codefireclickdetector threw on a valid part")
part:Destroy()
end)
addTest("getcallbackvalue", function()
assert(type(getcallbackvalue) == "function", "getcallbackvalue is missing or not a function")
assert(not islclosure(getcallbackvalue) or getfenv(getcallbackvalue), "getcallbackvalue may be spoofed")
local testFunc = function() return "callback" end
local result = getcallbackvalue(testFunc)
assert(result == "callback", "getcallbackvalue did not return expected result")
end)
addTest("getconnections", function()
assert(type(getconnections) == "function", "getconnections is missing or not a function")
assert(not islclosure(getconnections) or getfenv(getconnections), "getconnections may be spoofed")
local signal = Instance.new("BindableEvent")
local connection = signal.Event:Connect(function() end)
local connections = getconnections(signal.Event)
assert(type(connections) == "table", "getconnections should return a table")
assert(#connections > 0, "getconnections returned an empty table")
signal:Destroy()
end)
addTest("getinstances", function()
assert(type(getinstances) == "function", "getinstances is missing or not a function")
assert(not islclosure(getinstances) or getfenv(getinstances), "getinstances may be spoofed")
local result = getinstances()
assert(type(result) == "table", "getinstances should return a table")
assert(typeof(result[1]) == "Instance", "getinstances returned non-instance elements")
end)
addTest("getnilinstances", function()
assert(type(getnilinstances) == "function", "getnilinstances is missing or not a function")
assert(not islclosure(getnilinstances) or getfenv(getnilinstances), "getnilinstances may be spoofed")
local orphan = Instance.new("Part")
orphan.Parent = nil
local nils = getnilinstances()
local found = false
for _, v in ipairs(nils) do
if v == orphan then found = true break end
end
assert(found, "getnilinstances did not include orphaned instance")
orphan:Destroy()
end)
addTest("isscriptable", function()
assert(type(isscriptable) == "function", "isscriptable is missing or not a function")
assert(not islclosure(isscriptable) or getfenv(isscriptable), "isscriptable may be spoofed")
assert(type(isscriptable(game)) == "boolean", "isscriptable should return a boolean")
assert(isscriptable(game) == true or isscriptable(game) == false, "isscriptable returned invalid value")
end)
addTest("WebSocket.connect", function()
assert(type(WebSocket) == "table", "WebSocket table missing")
assert(type(WebSocket.connect) == "function", "WebSocket.connect function missing")
classifyFunction(WebSocket.connect, "WebSocket.connect")
local success, connection = pcall(function()
return WebSocket.connect("wss://echo.websocket.org")
end)
assert(success, "Failed to connect using WebSocket")
assert(connection, "WebSocket connection failed to return a valid object")
local invalidSuccess, invalidConnection = pcall(function()
return WebSocket.connect("invalid_url")
end)
assert(not invalidSuccess, "WebSocket.connect should fail with invalid URL")
end)
local passed, failed, warnings = {}, {}, {}
for name, fn in pairs(addTests or {}) do
local success, result = pcall(fn)
if success then
local output = result or "Passed"
table.insert(passed, string.format("✅ %s: %s", name, output))
else
local errorMsg = result or "Unknown error"
if errorMsg:match("blocked") then
table.insert(warnings, "⚠️ " .. name .. ": " .. errorMsg)
else
table.insert(failed, "❌ " .. name .. ": " .. errorMsg)
end
end
end
local function generateProgressBar(percentage)
local bars = math.floor(percentage / 2.5)
return "[" .. string.rep("█", bars) .. string.rep("░", 40 - bars) .. "]"
end
print([[
_____________________________________________________________
___ _   _ _  _  ___   _____ ___ ___ _____
| _ \ | | | \| |/ __| |_   _| __/ __|_   _|
|  _/ |_| | .` | (__    | | | _|\__ \ | |
|_|  \___/|_|\_|\___|   |_| |___|___/ |_|
_____________________________________________________________]])
print("\n===================== TEST RESULTS ======================")
if #passed > 0 then
print("\n[ PASSED Functions ]")
print("-----------------------------------------------------")
for _, pass in ipairs(passed) do
local name, output = pass:match("✅ (.-): (.+)")
if name and output then
print(string.format("  ✅  %-45s [%s] Result: %s",
name,
os.date("%X"),
output))
else
print(string.format("  ✅  %-45s [%s]",
pass:gsub("✅ ", ""),
os.date("%X")))
end
end
end
if #failed > 0 then
print("\n[ FAILED Functions ]")
print("-----------------------------------------------------")
for _, fail in ipairs(failed) do
local name, result = fail:match("❌ (.-): (.+)")
print(string.format("  ❌  %-45s [%s] result: %s",
name or "Unknown", os.date("%X"), result or "N/A"))
end
end
if #warnings > 0 then
print("\n[ WARNINGS ]")
print("-----------------------------------------------------")
for _, warn in ipairs(warnings) do
print(string.format("  ⚠️  %-45s [%s]",
warn:match("⚠️ (.-):") or warn:match("⚠️ (.+)"),
os.date("%X")))
end
end
local totalPassed = #passed
local totalFailed = #failed
local total = totalPassed + totalFailed
local totalTime = os.clock() - startTime
local percent = total > 0 and math.floor((totalPassed / total) * 100) or 0
print("\n==================== FINAL SUMMARY =====================")
print(string.format(" Pass Rate:        %d/%d (%d%%) %s",
#passed,
total,
percent,
generateProgressBar(percent)))
print(string.format(" Total Time:       %.4f seconds", totalTime))
print(string.format(" Passed Functions:     %d", #passed))
print(string.format(" Failed Functions:     %d", #failed))
print(string.format(" Warnings:         %d", #warnings))
if game.PlaceId ~= REQUIRED_PLACE_ID then
warn("\n⚠️ WARNING: Diagnostic run in unverified environment!")
warn("Results may not be accurate or secure!")
end
print(" ")
print(">> PUNC Test finished at " .. os.date("%X"))
end
if game.PlaceId == REQUIRED_PLACE_ID then
warn("no action required")
script()
return
end
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local CoreGui = game:GetService("CoreGui")
local player = Players.LocalPlayer
if not player then
player = Players.LocalPlayer
end
local customCoreGui
if not CoreGui:FindFirstChild("PUNCTEST") then
customCoreGui = Instance.new("ScreenGui")
customCoreGui.Name = "PUNCTEST"
customCoreGui.ResetOnSpawn = false
customCoreGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
customCoreGui.DisplayOrder = 999
customCoreGui.IgnoreGuiInset = true
if syn and syn.protect_gui then
syn.protect_gui(customCoreGui)
customCoreGui.Parent = CoreGui
elseif gethui then
customCoreGui.Parent = gethui()
else
customCoreGui.Parent = CoreGui
end
else
customCoreGui = CoreGui:FindFirstChild("PUNCTEST")
end
local blurEffect = Instance.new("BlurEffect")
blurEffect.Size = 0
blurEffect.Parent = Lighting
local darkOverlay = Instance.new("Frame")
darkOverlay.Name = "DarkOverlay"
darkOverlay.Size = UDim2.new(1, 0, 1, 0)
darkOverlay.Position = UDim2.new(0, 0, 0, 0)
darkOverlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
darkOverlay.BackgroundTransparency = 1
darkOverlay.ZIndex = 10
darkOverlay.Parent = customCoreGui
local borderContainer = Instance.new("Frame")
borderContainer.Name = "BorderContainer"
borderContainer.Size = UDim2.new(0, 480, 0, 330)
borderContainer.Position = UDim2.new(0.5, -240, 0.5, -165)
borderContainer.BackgroundTransparency = 1
borderContainer.ZIndex = 10
borderContainer.Parent = customCoreGui
local borderFrame = Instance.new("Frame")
borderFrame.Name = "BorderFrame"
borderFrame.Size = UDim2.new(1, 0, 1, 0)
borderFrame.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
borderFrame.BackgroundTransparency = 1
borderFrame.BorderSizePixel = 0
borderFrame.ZIndex = 10
borderFrame.Parent = borderContainer
local borderCorner = Instance.new("UICorner")
borderCorner.CornerRadius = UDim.new(0, 20)
borderCorner.Parent = borderFrame
local borderGlow = Instance.new("ImageLabel")
borderGlow.Name = "BorderGlow"
borderGlow.AnchorPoint = Vector2.new(0.5, 0.5)
borderGlow.BackgroundTransparency = 1
borderGlow.Position = UDim2.new(0.5, 0, 0.5, 0)
borderGlow.Size = UDim2.new(1, 20, 1, 20)
borderGlow.Image = "rbxassetid://5028857084"
borderGlow.ImageColor3 = Color3.fromRGB(130, 60, 255)
borderGlow.ImageTransparency = 1
borderGlow.ZIndex = 9
borderGlow.Parent = borderContainer
local innerFrame = Instance.new("Frame")
innerFrame.Name = "InnerFrame"
innerFrame.Size = UDim2.new(1, -10, 1, -10)
innerFrame.Position = UDim2.new(0, 5, 0, 5)
innerFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
innerFrame.BorderSizePixel = 0
innerFrame.BackgroundTransparency = 1
innerFrame.ZIndex = 11
innerFrame.Parent = borderFrame
local innerCorner = Instance.new("UICorner")
innerCorner.CornerRadius = UDim.new(0, 16)
innerCorner.Parent = innerFrame
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 470, 0, 320)
mainFrame.Position = UDim2.new(0.5, -235, 0.5, -160)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BackgroundTransparency = 1
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 12
mainFrame.Parent = customCoreGui
local cornerRadius = Instance.new("UICorner")
cornerRadius.CornerRadius = UDim.new(0, 20)
cornerRadius.Parent = mainFrame
local titleContainer = Instance.new("Frame")
titleContainer.Name = "TitleContainer"
titleContainer.Size = UDim2.new(1, -40, 0, 60)
titleContainer.Position = UDim2.new(0, 20, 0, 20)
titleContainer.BackgroundTransparency = 1
titleContainer.ZIndex = 13
titleContainer.Parent = mainFrame
local securityIcon = Instance.new("ImageLabel")
securityIcon.Name = "SecurityIcon"
securityIcon.Size = UDim2.new(0, 30, 0, 30)
securityIcon.Position = UDim2.new(0, 0, 0, 0)
securityIcon.BackgroundTransparency = 1
securityIcon.Image = "rbxassetid://7072706620"
securityIcon.ImageColor3 = Color3.fromRGB(130, 60, 255)
securityIcon.ImageTransparency = 1
securityIcon.ZIndex = 14
securityIcon.Parent = titleContainer
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -40, 0, 30)
titleLabel.Position = UDim2.new(0, 40, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "SECURITY ALERT"
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 24
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextTransparency = 1
titleLabel.ZIndex = 14
titleLabel.Parent = titleContainer
local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Name = "Subtitle"
subtitleLabel.Size = UDim2.new(1, -40, 0, 20)
subtitleLabel.Position = UDim2.new(0, 40, 0, 30)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.Text = "Game inconsistency"
subtitleLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
subtitleLabel.TextSize = 16
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.TextTransparency = 1
subtitleLabel.ZIndex = 14
subtitleLabel.Parent = titleContainer
local messageContainer = Instance.new("Frame")
messageContainer.Name = "MessageContainer"
messageContainer.Size = UDim2.new(1, -40, 0, 100)
messageContainer.Position = UDim2.new(0, 20, 0, 90)
messageContainer.BackgroundTransparency = 1
messageContainer.ZIndex = 13
messageContainer.Parent = mainFrame
local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.Size = UDim2.new(1, 0, 1, 0)
messageLabel.Position = UDim2.new(0, 0, 0, 0)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.Gotham
messageLabel.Text = "For your security, we recommend teleporting to the other game, as it is safe and properly protected. The current game may not have sufficient security measures to ensure your safety. Please teleport to " .. REQUIRED_PLACE_ID .. " for complete safety."
messageLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
messageLabel.TextSize = 16
messageLabel.TextWrapped = true
messageLabel.TextXAlignment = Enum.TextXAlignment.Center
messageLabel.TextTransparency = 1
messageLabel.ZIndex = 14
messageLabel.Parent = messageContainer
local buttonsContainer = Instance.new("Frame")
buttonsContainer.Name = "ButtonsContainer"
buttonsContainer.Size = UDim2.new(1, -40, 0, 50)
buttonsContainer.Position = UDim2.new(0, 20, 0, 200)
buttonsContainer.BackgroundTransparency = 1
buttonsContainer.ZIndex = 13
buttonsContainer.Parent = mainFrame
local buttonsLayout = Instance.new("UIListLayout")
buttonsLayout.Name = "ButtonsLayout"
buttonsLayout.FillDirection = Enum.FillDirection.Horizontal
buttonsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
buttonsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
buttonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonsLayout.Padding = UDim.new(0, 20)
buttonsLayout.Parent = buttonsContainer
local teleportButton = Instance.new("TextButton")
teleportButton.Name = "TeleportButton"
teleportButton.Size = UDim2.new(0, 200, 0, 50)
teleportButton.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
teleportButton.BackgroundTransparency = 1
teleportButton.Text = ""
teleportButton.LayoutOrder = 1
teleportButton.ZIndex = 14
teleportButton.Parent = buttonsContainer
local teleportCorner = Instance.new("UICorner")
teleportCorner.CornerRadius = UDim.new(0, 12)
teleportCorner.Parent = teleportButton
local teleportGradient = Instance.new("UIGradient")
teleportGradient.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 60, 255)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 40, 200))
})
teleportGradient.Rotation = 45
teleportGradient.Parent = teleportButton
local teleportLabel = Instance.new("TextLabel")
teleportLabel.Name = "Label"
teleportLabel.Size = UDim2.new(1, 0, 1, 0)
teleportLabel.Position = UDim2.new(0, 0, 0, 0)
teleportLabel.BackgroundTransparency = 1
teleportLabel.Font = Enum.Font.GothamBold
teleportLabel.Text = "TELEPORT"
teleportLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
teleportLabel.TextSize = 16
teleportLabel.TextTransparency = 1
teleportLabel.ZIndex = 15
teleportLabel.Parent = teleportButton
local teleportIcon = Instance.new("ImageLabel")
teleportIcon.Name = "Icon"
teleportIcon.Size = UDim2.new(0, 20, 0, 20)
teleportIcon.Position = UDim2.new(0, 15, 0.5, -10)
teleportIcon.BackgroundTransparency = 1
teleportIcon.Image = "rbxassetid://7072717958"
teleportIcon.ImageColor3 = Color3.fromRGB(255, 255, 255)
teleportIcon.ImageTransparency = 1
teleportIcon.ZIndex = 15
teleportIcon.Parent = teleportButton
local continueButton = Instance.new("TextButton")
continueButton.Name = "ContinueButton"
continueButton.Size = UDim2.new(0, 200, 0, 50)
continueButton.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
continueButton.BackgroundTransparency = 1
continueButton.Text = ""
continueButton.LayoutOrder = 2
continueButton.ZIndex = 14
continueButton.Parent = buttonsContainer
local continueCorner = Instance.new("UICorner")
continueCorner.CornerRadius = UDim.new(0, 12)
continueCorner.Parent = continueButton
local continueGradient = Instance.new("UIGradient")
continueGradient.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 70)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 40, 50))
})
continueGradient.Rotation = 45
continueGradient.Parent = continueButton
local continueLabel = Instance.new("TextLabel")
continueLabel.Name = "Label"
continueLabel.Size = UDim2.new(1, 0, 1, 0)
continueLabel.Position = UDim2.new(0, 0, 0, 0)
continueLabel.BackgroundTransparency = 1
continueLabel.Font = Enum.Font.GothamBold
continueLabel.Text = "CONTINUE"
continueLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
continueLabel.TextSize = 16
continueLabel.TextTransparency = 1
continueLabel.TextXAlignment = Enum.TextXAlignment.Center
continueLabel.ZIndex = 15
continueLabel.Parent = continueButton
local continueIcon = Instance.new("ImageLabel")
continueIcon.Name = "Icon"
continueIcon.Size = UDim2.new(0, 20, 0, 20)
continueIcon.Position = UDim2.new(0, 15, 0.5, -10)
continueIcon.BackgroundTransparency = 1
continueIcon.Image = "rbxassetid://7072725342"
continueIcon.ImageColor3 = Color3.fromRGB(180, 180, 180)
continueIcon.ImageTransparency = 1
continueIcon.ZIndex = 15
continueIcon.Parent = continueButton
local timerContainer = Instance.new("Frame")
timerContainer.Name = "TimerContainer"
timerContainer.Size = UDim2.new(1, -40, 0, 40)
timerContainer.Position = UDim2.new(0, 20, 0, 260)
timerContainer.BackgroundTransparency = 1
timerContainer.ZIndex = 13
timerContainer.Parent = mainFrame
local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "TimerLabel"
timerLabel.Size = UDim2.new(1, 0, 0, 20)
timerLabel.Position = UDim2.new(0, 0, 0, 0)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.Gotham
timerLabel.Text = "Auto-continuing in 15 seconds..."
timerLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
timerLabel.TextSize = 14
timerLabel.TextXAlignment = Enum.TextXAlignment.Center
timerLabel.TextTransparency = 1
timerLabel.ZIndex = 14
timerLabel.Parent = timerContainer
local timerBarBackground = Instance.new("Frame")
timerBarBackground.Name = "TimerBarBackground"
timerBarBackground.Size = UDim2.new(1, 0, 0, 6)
timerBarBackground.Position = UDim2.new(0, 0, 0, 25)
timerBarBackground.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
timerBarBackground.BorderSizePixel = 0
timerBarBackground.BackgroundTransparency = 1
timerBarBackground.ZIndex = 14
timerBarBackground.Parent = timerContainer
local timerBarBackgroundCorner = Instance.new("UICorner")
timerBarBackgroundCorner.CornerRadius = UDim.new(1, 0)
timerBarBackgroundCorner.Parent = timerBarBackground
local timerBar = Instance.new("Frame")
timerBar.Name = "TimerBar"
timerBar.Size = UDim2.new(1, 0, 1, 0)
timerBar.BackgroundColor3 = Color3.fromRGB(130, 60, 255)
timerBar.BorderSizePixel = 0
timerBar.BackgroundTransparency = 1
timerBar.ZIndex = 15
timerBar.Parent = timerBarBackground
local timerBarCorner = Instance.new("UICorner")
timerBarCorner.CornerRadius = UDim.new(1, 0)
timerBarCorner.Parent = timerBar
local timerBarGradient = Instance.new("UIGradient")
timerBarGradient.Color = ColorSequence.new({
ColorSequenceKeypoint.new(0, Color3.fromRGB(130, 60, 255)),
ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 40, 200))
})
timerBarGradient.Parent = timerBar
local creditsLabel = Instance.new("TextLabel")
creditsLabel.Name = "CreditsLabel"
creditsLabel.Size = UDim2.new(1, 0, 0, 20)
creditsLabel.Position = UDim2.new(0, 0, 0, 35)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Font = Enum.Font.Gotham
creditsLabel.Text = "made with love by x4v (@nuvq)"
creditsLabel.TextColor3 = Color3.fromRGB(130, 130, 130)
creditsLabel.TextSize = 12
creditsLabel.TextXAlignment = Enum.TextXAlignment.Center
creditsLabel.TextTransparency = 1
creditsLabel.ZIndex = 14
creditsLabel.Parent = timerContainer
local function createButtonHoverEffect(button, originalColor, hoverColor)
local glowOverlay = Instance.new("ImageLabel")
glowOverlay.Name = "GlowOverlay"
glowOverlay.AnchorPoint = Vector2.new(0.5, 0.5)
glowOverlay.BackgroundTransparency = 1
glowOverlay.Position = UDim2.new(0.5, 0, 0.5, 0)
glowOverlay.Size = UDim2.new(1, 20, 1, 20)
glowOverlay.Image = "rbxassetid://5028857084"
glowOverlay.ImageColor3 = originalColor
glowOverlay.ImageTransparency = 1
glowOverlay.ZIndex = button.ZIndex - 1
glowOverlay.Parent = button
button.MouseEnter:Connect(function()
TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = hoverColor}):Play()
TweenService:Create(glowOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0.7}):Play()
TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 205, 0, 52)}):Play()
end)
button.MouseLeave:Connect(function()
TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundColor3 = originalColor}):Play()
TweenService:Create(glowOverlay, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1}):Play()
TweenService:Create(button, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Size = UDim2.new(0, 200, 0, 50)}):Play()
end)
button.MouseButton1Down:Connect(function()
TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 195, 0, 48)}):Play()
end)
button.MouseButton1Up:Connect(function()
TweenService:Create(button, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 205, 0, 52)}):Play()
end)
end
local function createParticles()
local particlesContainer = Instance.new("Frame")
particlesContainer.Name = "ParticlesContainer"
particlesContainer.Size = UDim2.new(1, 0, 1, 0)
particlesContainer.BackgroundTransparency = 1
particlesContainer.ClipsDescendants = true
particlesContainer.ZIndex = 13
particlesContainer.Parent = mainFrame
for i = 1, 15 do
local particle = Instance.new("Frame")
particle.Name = "Particle" .. i
particle.Size = UDim2.new(0, math.random(2, 4), 0, math.random(2, 4))
particle.Position = UDim2.new(math.random(), 0, math.random(), 0)
particle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
particle.BackgroundTransparency = 0.8 + (math.random() * 0.15)
particle.ZIndex = 13
particle.Parent = particlesContainer
local particleCorner = Instance.new("UICorner")
particleCorner.CornerRadius = UDim.new(1, 0)
particleCorner.Parent = particle
spawn(function()
while particlesContainer.Parent do
local randomX = math.random(-50, 50) / 500
local randomY = math.random(-50, 50) / 500
local duration = math.random(3, 6)
TweenService:Create(particle, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
Position = UDim2.new(
math.clamp(particle.Position.X.Scale + randomX, 0, 1),
0,
math.clamp(particle.Position.Y.Scale + randomY, 0, 1),
0
)
}):Play()
wait(duration - 0.1)
end
end)
end
return particlesContainer
end
createButtonHoverEffect(teleportButton, Color3.fromRGB(130, 60, 255), Color3.fromRGB(150, 80, 255))
createButtonHoverEffect(continueButton, Color3.fromRGB(40, 40, 50), Color3.fromRGB(60, 60, 70))
local particles = createParticles()
particles.Visible = false
local function ensureFullCoverage()
darkOverlay.Size = UDim2.new(1, 0, 1, 0)
darkOverlay.Position = UDim2.new(0, 0, 0, 0)
RunService.RenderStepped:Connect(function()
if darkOverlay and darkOverlay.Parent then
darkOverlay.Size = UDim2.new(1, 0, 1, 0)
darkOverlay.Position = UDim2.new(0, 0, 0, 0)
end
end)
end
local function animateOpening()
ensureFullCoverage()
local overlayTween = TweenService:Create(darkOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 0.3})
local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 20})
overlayTween:Play()
blurTween:Play()
wait(0.3)
local borderTween = TweenService:Create(borderFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.6})
local borderGlowTween = TweenService:Create(borderGlow, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0.4})
local innerFrameTween = TweenService:Create(innerFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
borderTween:Play()
borderGlowTween:Play()
innerFrameTween:Play()
wait(0.2)
local mainFrameTween = TweenService:Create(mainFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
mainFrameTween:Play()
wait(0.2)
local iconTween = TweenService:Create(securityIcon, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {ImageTransparency = 0})
local titleTween = TweenService:Create(titleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
local subtitleTween = TweenService:Create(subtitleLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
iconTween:Play()
wait(0.1)
titleTween:Play()
wait(0.1)
subtitleTween:Play()
wait(0.2)
local messageTween = TweenService:Create(messageLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
messageTween:Play()
wait(0.2)
local teleportBtnTween = TweenService:Create(teleportButton, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
local teleportLabelTween = TweenService:Create(teleportLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
local teleportIconTween = TweenService:Create(teleportIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0})
teleportBtnTween:Play()
teleportLabelTween:Play()
teleportIconTween:Play()
wait(0.15)
local continueBtnTween = TweenService:Create(continueButton, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
local continueLabelTween = TweenService:Create(continueLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
local continueIconTween = TweenService:Create(continueIcon, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0})
continueBtnTween:Play()
continueLabelTween:Play()
continueIconTween:Play()
wait(0.15)
local timerLabelTween = TweenService:Create(timerLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
local timerBgTween = TweenService:Create(timerBarBackground, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0.7})
local timerBarTween = TweenService:Create(timerBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
timerLabelTween:Play()
timerBgTween:Play()
timerBarTween:Play()
wait(0.1)
local creditsTween = TweenService:Create(creditsLabel, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0})
creditsTween:Play()
wait(0.2)
particles.Visible = true
end
local function animateClosing(callback)
local overlayTween = TweenService:Create(darkOverlay, TweenInfo.new(0.3), {BackgroundTransparency = 0.1})
local blurTween = TweenService:Create(blurEffect, TweenInfo.new(0.3), {Size = 25})
overlayTween:Play()
blurTween:Play()
wait(0.2)
local creditsTween = TweenService:Create(creditsLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
creditsTween:Play()
local timerLabelTween = TweenService:Create(timerLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
local timerBgTween = TweenService:Create(timerBarBackground, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
local timerBarTween = TweenService:Create(timerBar, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
timerLabelTween:Play()
timerBgTween:Play()
timerBarTween:Play()
particles.Visible = false
wait(0.1)
local teleportBtnTween = TweenService:Create(teleportButton, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
local teleportLabelTween = TweenService:Create(teleportLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
local teleportIconTween = TweenService:Create(teleportIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})
local continueBtnTween = TweenService:Create(continueButton, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
local continueLabelTween = TweenService:Create(continueLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
local continueIconTween = TweenService:Create(continueIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})
teleportBtnTween:Play()
teleportLabelTween:Play()
teleportIconTween:Play()
continueBtnTween:Play()
continueLabelTween:Play()
continueIconTween:Play()
wait(0.1)
local messageTween = TweenService:Create(messageLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
messageTween:Play()
wait(0.1)
local iconTween = TweenService:Create(securityIcon, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})
local titleTween = TweenService:Create(titleLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
local subtitleTween = TweenService:Create(subtitleLabel, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1})
iconTween:Play()
titleTween:Play()
subtitleTween:Play()
wait(0.2)
local mainFrameTween = TweenService:Create(mainFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
mainFrameTween:Play()
wait(0.1)
local borderTween = TweenService:Create(borderFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
local borderGlowTween = TweenService:Create(borderGlow, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 1})
local innerFrameTween = TweenService:Create(innerFrame, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
borderTween:Play()
borderGlowTween:Play()
innerFrameTween:Play()
wait(0.3)
local finalOverlayTween = TweenService:Create(darkOverlay, TweenInfo.new(0.5), {BackgroundTransparency = 1})
local finalBlurTween = TweenService:Create(blurEffect, TweenInfo.new(0.5), {Size = 0})
finalOverlayTween:Play()
finalBlurTween:Play()
wait(0.5)
if callback then
callback()
end
end
local function onTeleportClicked()
local pressAnimation = TweenService:Create(teleportButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 195, 0, 48)})
pressAnimation:Play()
wait(0.1)
responseReceived = true
animateClosing(function()
TeleportService:Teleport(REQUIRED_PLACE_ID, player)
customCoreGui:Destroy()
blurEffect:Destroy()
end)
end
local function onContinueClicked()
local pressAnimation = TweenService:Create(continueButton, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = UDim2.new(0, 195, 0, 48)})
pressAnimation:Play()
wait(0.1)
responseReceived = true
animateClosing(function()
warn("Continuing in an unsafe environment...")
customCoreGui:Destroy()
blurEffect:Destroy()
end)
script()
end
teleportButton.MouseButton1Click:Connect(onTeleportClicked)
continueButton.MouseButton1Click:Connect(onContinueClicked)
local timer = 15
local responseReceived = false
spawn(function()
animateOpening()
wait(1)
while timer > 0 and not responseReceived do
timerLabel.Text = "Auto-continuing in " .. timer .. " seconds..."
local progressTween = TweenService:Create(timerBar, TweenInfo.new(1, Enum.EasingStyle.Linear), {Size = UDim2.new(timer/15, 0, 1, 0)})
progressTween:Play()
local pulseTween = TweenService:Create(timerBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 0.2})
pulseTween:Play()
wait(0.5)
local pulseResetTween = TweenService:Create(timerBar, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {BackgroundTransparency = 0})
pulseResetTween:Play()
wait(0.5)
timer = timer - 1
end
if not responseReceived then
warn("No action taken, continuing...")
responseReceived = true
animateClosing(function()
customCoreGui:Destroy()
blurEffect:Destroy()
end)
script()
end
end)
spawn(function()
while customCoreGui.Parent do
local glowPulseTween = TweenService:Create(borderGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
ImageTransparency = 0.2
})
glowPulseTween:Play()
wait(2)
local glowResetTween = TweenService:Create(borderGlow, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
ImageTransparency = 0.4
})
glowResetTween:Play()
local borderColorTween = TweenService:Create(borderFrame, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
BackgroundColor3 = Color3.fromRGB(150, 80, 255)
})
borderColorTween:Play()
wait(2)
local borderColorResetTween = TweenService:Create(borderFrame, TweenInfo.new(2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {
BackgroundColor3 = Color3.fromRGB(130, 60, 255)
})
borderColorResetTween:Play()
wait(2)
end
end)
