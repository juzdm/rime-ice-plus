local json = require("json")
local http = require("simplehttp")

local function escape(s)
   return (string.gsub(s, "([^A-Za-z0-9_])", function(c)
       return string.format("%%%02x", string.byte(c))
   end))
end

local function make_url(input)
   local sl = "zh_CN"
   local tl = "en"
   return 'http://translate.googleapis.com/translate_a/single?client=gtx&sl='.. sl ..'&tl='.. tl ..'&dt=t&q='.. escape(input)
end

local function translator(input, seg, env)
   local string = env.focus_text
   local reply = http.request(make_url(string))
   local data = json.decode(reply)

   print("c2e url", make_url(string))
   print("c2e reply", reply)

   for i, v in ipairs(data) do
      -- get the output string
      local output = v[1][1]

      print("c2e output", output)

      local c = Candidate("translate", seg.start, seg._end, output, "🇺🇸")
      c.quality = 100
      -- add to Candidate
      yield(c)
   end
end

return translator
