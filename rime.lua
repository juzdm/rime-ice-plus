-- Rime Lua 扩展 https://github.com/hchunhui/librime-lua
-- 文档 https://github.com/hchunhui/librime-lua/wiki/Scripting

-- processors:

-- 以词定字，可在 default.yaml → key_binder 下配置快捷键，默认为左右中括号 [ ]
local c2e = require("c2etrigger")("Control+e", require("c2e"))
c2e_translator = c2e.translator
c2e_processor = c2e.processor

local e2c = require("e2ctrigger")("Control+h", require("e2c"))
e2c_translator = e2c.translator
e2c_processor = e2c.processor

local baidu = require("trigger")("Control+t", require("baidu"))
baidu_translator = baidu.translator
baidu_processor = baidu.processor


local english = require("english")()
english_processor = english.processor
english_segmentor = english.segmentor
english_translator = english.translator
english_filter = english.filter
english_filter0 = english.filter0