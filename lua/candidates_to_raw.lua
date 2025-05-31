--[[
  Lua 脚本：根据 RIME 候选词结构拆分原始拼音 (V6 - 添加获取等效拼音功能)

  目的:
  ... (同前) ...
  V5 版本将判断两个拼音片段是否等效的逻辑提取到单独的函数中。
  V6 版本新增一个函数 `get_equivalent_pinyin_segments`，用于获取
  给定拼音片段的所有等效（包含自身和混淆）形式。

  代码生成时间: Tuesday, April 15, 2025 at 7:39:16 PM MST (美国亚利桑那州菲尼克斯)
]]

local M = {}

-- 导出混淆表
M.confusion_map = {
    ['eng'] = {'en', 'ong'}, ['en'] = {'eng'}, ['in'] = {'ing'},
    ['ing'] = {'in'}, ['uang'] = {'uan'}, ['uan'] = {'uang'}, -- (为对称性补充 uan->uang)
    ['ong'] = {'un', 'on', 'eng'},
    ['un'] = {'ong', 'iong'}, ['iong'] = {'un'},
    -- 注意: 原始代码中 'uan' -> 'uang' 是缺失的，如果需要严格对称，应添加
    -- 注意: 'on' 没有反向映射到 'ong'，这可能是有意的或疏忽
}

--[[----------------------------------------------------------------------------
  辅助数据: Pinyin 声母列表 (用于解析) - 无需修改
----------------------------------------------------------------------------]]
local ordered_initials = {
    "zh", "ch", "sh", "b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h",
    "j", "q", "x", "r", "z", "c", "s", "y", "w"
}

--[[----------------------------------------------------------------------------
  辅助函数: parse_pinyin (解析拼音为声母和韵母) - 无需修改
----------------------------------------------------------------------------]]
local function parse_pinyin(pinyin)
    if not pinyin or pinyin == "" then return { initial = "", final = "" } end
    local initial = ""
    local final = pinyin
    for _, init in ipairs(ordered_initials) do
        if string.sub(pinyin, 1, #init) == init then
            initial = init
            final = string.sub(pinyin, #init + 1)
            if final == "" and (initial == "z" or initial == "c" or initial == "s" or
                                initial == "zh" or initial == "ch" or initial == "sh" or
                                initial == "r") then
                -- 为 z/c/s/zh/ch/sh/r 单独存在时补充韵母 i (根据 RIME 习惯)
                final = "i"
            end
            goto initial_found
        end
    end
    ::initial_found::
     -- V5 中移除的警告:
     -- if initial ~= "" and final == "" and not (initial == "z" or initial == "c" or initial == "s" or
     --                                           initial == "zh" or initial == "ch" or initial == "sh" or
     --                                           initial == "r") then
     --    -- print("警告: 解析 '"..pinyin.."' 时得到空韵母，声母为 '"..initial.."'")
     -- end
    return { initial = initial, final = final }
end

--[[----------------------------------------------------------------------------
  辅助函数: are_finals_confused (检查两个韵母是否可混淆) - 无需修改
----------------------------------------------------------------------------]]
local function are_finals_confused(f1, f2)
    -- 1. 自身不视为混淆
    if not f1 or f1 == "" or not f2 or f2 == "" or f1 == f2 then return false end

    -- 2. 检查 M.confusion_map[f1] 是否包含 f2
    local confused = false
    if M.confusion_map[f1] then
        for _, f_confused in ipairs(M.confusion_map[f1]) do
            if f_confused == f2 then confused = true; break end
        end
    end
    -- 3. 如果上面没找到，检查 M.confusion_map[f2] 是否包含 f1 (确保对称性)
    if not confused and M.confusion_map[f2] then
        for _, f_confused in ipairs(M.confusion_map[f2]) do
            if f_confused == f1 then confused = true; break end
        end
    end
    return confused
end

--[[----------------------------------------------------------------------------
  辅助函数: are_pinyin_segments_equivalent (判断两个拼音片段是否等效) - V5 新增
----------------------------------------------------------------------------]]
--[[
  比较两个拼音片段 seg1 和 seg2 是否相等或根据精确混淆规则视为等效。
  规则：直接相等，或者 声母相同且(韵母相同或韵母可混淆)。

  @param seg1 string: 第一个拼音片段。
  @param seg2 string: 第二个拼音片段。
  @return boolean: 如果等效则返回 true，否则返回 false。
                   依赖 parse_pinyin 和 are_finals_confused 函数。
]]
function M.are_pinyin_segments_equivalent(seg1, seg2)
  -- 1. 检查直接相等
  if seg1 == seg2 then
    return true
  end

  -- 2. 如果不直接相等，解析声母和韵母
  local p1 = parse_pinyin(seg1)
  local p2 = parse_pinyin(seg2)

  -- 3. 检查声母是否相同
  if p1.initial == p2.initial then
    -- 4. 如果声母相同，检查韵母是否相同或可混淆
    -- (注意: are_finals_confused 已经排除了 f1==f2 的情况)
    if p1.final == p2.final then
      return true -- 声母相同，韵母相同
    elseif are_finals_confused(p1.final, p2.final) then
      return true -- 声母相同，韵母可混淆
    end
  end

  -- 如果声母不同，或者声母相同但韵母既不相同也不可混淆，则不等效
  return false
end

--[[----------------------------------------------------------------------------
  新增函数: get_equivalent_pinyin_segments (获取所有等效的拼音片段) - V6 新增
----------------------------------------------------------------------------]]
--[[
  根据 `M.confusion_map` 和 `parse_pinyin` 的逻辑，找出与给定拼音片段
  等效的所有拼音片段（包括其自身）。

  等效定义:
  1. 与输入片段自身相等。
  2. 与输入片段具有相同的声母，且韵母可通过 `are_finals_confused` 判断为可混淆。

  @param pinyin_segment string: 输入的单个拼音片段。
  @return table: 一个包含所有等效拼音片段字符串的 Lua 列表 (数组)。
                 列表中保证包含输入的 `pinyin_segment` 自身，且无重复项。
]]
function M.get_equivalent_pinyin_segments(pinyin_segment)
  -- 1. 输入验证
  if not pinyin_segment or pinyin_segment == "" then
    return {pinyin_segment} -- 对于空字符串或nil，只返回其自身
  end

  -- 2. 使用集合来存储结果，自动去重，并先加入自身
  local equivalents_set = {}
  equivalents_set[pinyin_segment] = true

  -- 3. 解析输入的拼音片段
  local p_input = parse_pinyin(pinyin_segment)
  local initial = p_input.initial
  local final_input = p_input.final

  -- 4. 如果没有有效韵母，通常没有混淆（除非混淆表定义了空韵母的混淆）
  --    但我们仍然需要查找是否有其他韵母可以混淆成这个（可能为空的）韵母
  --    所以继续执行查找逻辑

  -- 5. 查找所有可与 final_input 混淆的韵母
  local confusable_finals_set = {}
  -- 5.1 直接查找 M.confusion_map[final_input]
  if M.confusion_map[final_input] then
    for _, confused_f in ipairs(M.confusion_map[final_input]) do
        if confused_f ~= final_input then -- 避免加入自身韵母
           confusable_finals_set[confused_f] = true
        end
    end
  end
  -- 5.2 反向查找，看哪个 key_final 的列表包含 final_input
  for key_final, confused_list in pairs(M.confusion_map) do
     if key_final ~= final_input then
        for _, confused_f in ipairs(confused_list) do
            if confused_f == final_input then
                -- 这意味着 key_final 可以混淆成 final_input
                -- 根据 are_finals_confused 的对称性，也意味着 final_input 可以混淆成 key_final
                confusable_finals_set[key_final] = true
                break -- 找到即可，继续检查下一个 key_final
            end
        end
     end
  end

  -- 6. 构建等效的拼音片段
  for final, _ in pairs(confusable_finals_set) do
    -- 组合声母和混淆后的韵母
    -- 特殊处理：如果原始声母是 z/c/s/zh/ch/sh/r 且原始韵母是 i (parse_pinyin补充的)，
    -- 并且混淆后的韵母也是 i，我们不需要重新组合，因为它就是原始片段。
    -- 但用 set 可以自动处理此情况，所以无需特殊判断。
    local new_segment = initial .. final
    equivalents_set[new_segment] = true
  end

  -- 7. 将集合转换为列表（数组）形式返回
  local result_list = {}
  for segment, _ in pairs(equivalents_set) do
    table.insert(result_list, segment)
  end

  return result_list
end


--[[----------------------------------------------------------------------------
  辅助函数: count_equivalent_segments (计算等效片段数量) - 重构自 V3
----------------------------------------------------------------------------]]
--[[
  比较两个列表，计算相同位置上等效（相同或视为混淆）的元素的数量。

  @param list1 table: 第一个包含片段的列表。
  @param list2 table: 第二个包含片段的列表。
  @param k number: 期望的片段数量。
  @return number: 等效片段的数量。
]]
local function count_equivalent_segments(list1, list2, k)
  local count = 0
  local len = math.min(#list1, #list2, k)
  for i = 1, len do
    -- 直接调用 V5 引入的比较函数
    if M.are_pinyin_segments_equivalent(list1[i], list2[i]) then
      count = count + 1
    end
  end
  return count
end


--[[----------------------------------------------------------------------------
  辅助函数: build_greedy_pattern (构建贪婪匹配模式) - 无需修改
----------------------------------------------------------------------------]]
local function build_greedy_pattern(initials, k)
  if #initials < k or k == 0 then return nil end
  local pattern_parts = {}
  for i = 1, k do
    local initial = initials[i]
    -- RIME 的输入码可能包含数字(声调)或特殊字符，但 B 通常是规范拼音，这里假设 initials 是纯字母
    -- 如果 initials 可能来自更复杂的输入码，需要更健壮的转义
    local escaped_initial = string.gsub(initial, "[%.%%%+%-%.%?%[%^%$%(%)]", "%%%1")
    -- 匹配 声母 + 后面任意字母数字 (RIME中可能带声调数字)
    -- 如果保证B是纯拼音，可以用 %a*；用 %w* 更通用些
    table.insert(pattern_parts, "(" .. escaped_initial .. "%w*)")
  end
  return "^" .. table.concat(pattern_parts, "") .. "$"
end


--[[----------------------------------------------------------------------------
  辅助函数: split_pinyin_by_initials_heuristic_optimized (基于首字母启发式分割) - 无需修改
----------------------------------------------------------------------------]]
local function split_pinyin_by_initials_heuristic_optimized(A, k, initials_B, total_len_A)
  if k == 0 or total_len_A == 0 then return {} end
  local segments_A_prime = {}
  local current_pos_A = 1
  for i = 1, k do
    if current_pos_A > total_len_A then break end -- A 已用尽

    local end_pos_A
    if i < k then
      -- 尝试找到下一个片段的首字母在 A 中出现的位置
      local next_initial = initials_B[i+1]
      if next_initial == "" then -- 下一个片段没有声母 (e.g., "an")
          -- 这种情况比较难处理，启发式可能会失败。
          -- 一个策略是：假设当前片段尽可能短，只包含当前声母？
          -- 或者维持原来的逻辑：找不到明确分隔符就取到最后。
          -- RIME不太可能产生 "xi an" 对应的 B_initials 为 {"x", ""}
          -- 通常零声母会用 y/w 或本身 (如 an) 作为标识。
          -- 假设 initials_B 中的元素总是非空的。
          -- 如果 initials_B 可能为空，需要调整逻辑。
          -- 这里保持原逻辑：找不到就取到最后。
      end

      local search_start_pos = current_pos_A + 1 -- 从当前位置之后查找
      local next_initial_pos = nil
      if search_start_pos <= total_len_A and next_initial and next_initial ~= "" then
           -- 使用 plain=true 进行非模式匹配查找
           next_initial_pos = string.find(A, next_initial, search_start_pos, true)
      end

      if next_initial_pos then
        -- 找到了下一个声母，当前片段结束于其前一个字符
        end_pos_A = next_initial_pos - 1
      else
        -- 没找到下一个声母，说明当前片段是倒数第二个，且包含 A 的剩余部分
        -- 或者 A 太短了。将剩余部分全部分给当前片段。
        end_pos_A = total_len_A
      end
    else
      -- 这是最后一个片段 (i == k)，它包含 A 的所有剩余部分
      end_pos_A = total_len_A
    end

    -- 健壮性检查：确保结束位置不小于起始位置
    if end_pos_A < current_pos_A then
       -- 这种情况可能在 A 非常短或 next_initial_pos 计算错误时发生
       -- 例如 A="a", B="a b", k=2, initials={"a","b"}
       -- i=1, current=1, next='b', find 'b' from pos 2 in "a" -> nil. end_pos=1.
       -- string.sub(A, 1, 1) = "a". current=2.
       -- i=2, current=2 > total_len_A=1, break. -> {"a"} (片段数不够k)

       -- 或者 A="b", B="a b", k=2, initials={"a","b"}
       -- i=1, current=1, next='b', find 'b' from pos 2 in "b" -> nil. end_pos=1.
       -- string.sub(A, 1, 1) = "b". current=2.
       -- i=2, current=2 > total_len_A=1, break. -> {"b"} (片段数不够k)

       -- 另一种情况 A="an", B="a n", k=2, initials={"a","n"}
       -- i=1, current=1, next='n', find 'n' from pos 2 in "an" -> 2. end_pos=1.
       -- string.sub(A, 1, 1) = "a". current=2.
       -- i=2, current=2 <= total_len_A=2. end_pos=2.
       -- string.sub(A, 2, 2) = "n". current=3.
       -- -> {"a", "n"}

       -- 如果 end_pos < current_pos, 意味着无法分割出有效片段
       -- 可以选择插入空字符串，或直接跳过，或修正 end_pos
       -- 修正为 end_pos = current_pos 似乎能产生一个单字符片段（如果 current_pos 有效）
       -- 但更可能表示分割逻辑有问题，也许应该返回失败？
       -- 原始代码似乎没有明确处理 end_pos_A < current_pos_A 的情况，
       -- string.sub 若 end < start 会返回空串 ""
       -- 保持原行为：如果 end < start，sub 返回 ""
       -- 但如果是因为 A 耗尽，上面的 break 会处理。
       -- 这里的条件似乎是为了防止 next_initial_pos 刚好是 current_pos？不太可能。
       -- 假设 end_pos >= current_pos 总成立或由 string.sub 处理。
       -- 重新审视原始代码逻辑：
       -- if end_pos_A < current_pos_A then
       --    if current_pos_A <= total_len_A then end_pos_A = current_pos_A else break end
       -- end
       -- 这个逻辑是：如果计算出的结束位置无效（太小），并且当前位置还在字符串内，
       -- 那么就让这个片段只包含当前位置的单个字符（或空串如果已在末尾）。
       -- 如果当前位置已经超出字符串，就直接中断循环。
       -- 恢复这个逻辑：
       if end_pos_A < current_pos_A then
           if current_pos_A <= total_len_A then
               end_pos_A = current_pos_A -- 至少包含一个字符（如果可能）
           else
               break -- 当前位置已无效，停止
           end
       end
    end

    table.insert(segments_A_prime, string.sub(A, current_pos_A, end_pos_A))
    current_pos_A = end_pos_A + 1 -- 移动到下一个片段的起始位置

    -- 如果没找到下一个声母的位置，并且已经将 A 的剩余部分全部分配了，
    -- 那么后续的循环没有意义，可以提前结束
    if i < k and end_pos_A == total_len_A and not next_initial_pos then
      break
    end
  end
  return segments_A_prime
end


--[[----------------------------------------------------------------------------
  主函数: split_pinyin_comparative_optimized_v5 (比较分割法 - V5/V6 逻辑)
----------------------------------------------------------------------------]]
--[[
  实现最终的分割逻辑。结合启发式和贪婪正则方法生成候选分割，
  然后使用重构后的比较函数 (`count_equivalent_segments`) 来选择最佳结果。
  选择逻辑不变（优先高分，平局优先贪婪）。

  @param A string: 原始未分词的拼音字符串。
  @param B string: RIME 分词后的、空格分隔的拼音字符串。
  @return table: 最终选定的、包含 A 分割后各片段的 Lua 列表。
]]
function M.split_pinyin_comparative_optimized_v5(A, B) -- 函数名保持v5，逻辑兼容v6
  -- 1. 输入验证和 B 字符串的预处理
  if not A or not B or A == "" or B == "" then return {} end
  local total_len_A = string.len(A)
  local b_segments = {}
  local b_initials = {}
  for segment in string.gmatch(B, "[^%s]+") do
    table.insert(b_segments, segment)
    -- 提取声母用于启发式和贪婪模式
    local p = parse_pinyin(segment)
    -- 如果解析不出声母 (如 "a", "an", "ou"), 使用首字母或整个音节作为引导？
    -- 原始代码使用首字母: local first_char = string.sub(segment, 1, 1)
    -- 这样做对于 "an" vs "a" 可能产生相同 initial "a"，导致混淆。
    -- 使用解析出的声母 p.initial 可能更准确，但需要处理空声母。
    -- 如果声母为空，用什么作为引导？空字符串？第一个字母？
    -- 决定：保持原始逻辑，使用首字母作为引导，因为它更简单且在原代码中有效。
    local first_char = string.sub(segment, 1, 1)
    table.insert(b_initials, first_char)
  end
  local k = #b_segments
  if k == 0 then return {} end

  -- 2. 获取候选分割 1 (启发式)
  local candidate_heuristic = split_pinyin_by_initials_heuristic_optimized(A, k, b_initials, total_len_A)
  local score_heuristic = 0
  -- 启发式分割结果的数量必须等于 B 的片段数才算有效
  local heuristic_is_valid = (#candidate_heuristic == k)
  if heuristic_is_valid then
       -- 使用重构后的评分函数
       score_heuristic = count_equivalent_segments(candidate_heuristic, b_segments, k)
  end

  -- 3. 获取候选分割 2 (贪婪)
  local candidate_greedy = {}
  local score_greedy = 0
  local greedy_is_valid = false
  local greedy_pattern = build_greedy_pattern(b_initials, k)
  if greedy_pattern then
    -- string.match 返回捕获的组
    local matches = { string.match(A, greedy_pattern) }
    -- 检查是否所有 k 个组都被成功捕获
    if #matches == k then
        candidate_greedy = matches
        greedy_is_valid = true
        -- 使用重构后的评分函数
        score_greedy = count_equivalent_segments(candidate_greedy, b_segments, k)
    end
  end

  -- 4. 选择最佳结果 (逻辑同 V2/V4/V5: 除非启发式严格更好，否则优先有效贪婪)
  --    如果 heuristic 分数更高 -> heuristic
  --    否则 (heuristic 分数 <= greedy 分数):
  --        如果 greedy 有效 -> greedy
  --        否则 (greedy 无效):
  --            如果 heuristic 有效 -> heuristic (因为 greedy 无效，只能选它)
  --            否则 (两者都无效) -> {}
  if heuristic_is_valid and score_heuristic > score_greedy then
    return candidate_heuristic
  elseif greedy_is_valid then
    return candidate_greedy
  elseif heuristic_is_valid then
    -- 能到这里意味着 heuristic_score <= score_greedy 且 greedy 无效
    return candidate_heuristic
  else
    -- 两者都无效或未产生正确数量的片段
    return {}
  end
end


--[[----------------------------------------------------------------------------
  辅助函数: are_tables_equal (比较两个列表是否完全相等) - 无需修改
----------------------------------------------------------------------------]]
local function are_tables_equal(t1, t2)
  if type(t1) ~= "table" or type(t2) ~= "table" then return false end
  if #t1 ~= #t2 then return false end
  for i = 1, #t1 do
    if t1[i] ~= t2[i] then return false end
  end
  return true
end

--[[----------------------------------------------------------------------------
  辅助函数: print_table_output (用于打印测试结果 - 调试用) - 无需修改
----------------------------------------------------------------------------]]
local function print_table_output(t, name)
   if name then io.write(name .. " -> ") end
   if type(t) ~= "table" then print(tostring(t)); return end
   io.write("{")
   for i, v in ipairs(t) do
     -- 使用 string.format 确保字符串被引号包围
     io.write(string.format('"%s"', tostring(v)))
     if i < #t then io.write(", ") end
   end
   print("} (#" .. #t .. " segments)")
 end


--[[----------------------------------------------------------------------------
  测试函数: run_pinyin_split_tests - 执行拼音分割测试用例 - (可选择性更新)
----------------------------------------------------------------------------]]
local function run_pinyin_split_tests()
    print("\n--- 测试最终优化版代码 (V6 包含等效获取) ---")
    print("--- 分割测试 (split_pinyin_comparative_optimized_v5) ---")
    print("--- 输出格式: true 表示通过, false 表示失败 ---")

    -- 定义测试数据 (与 V5 相同)
    local test_cases = {
        { A = "yingyue",    B = "yin yue",      Expected = {"ying", "yue"} },
        { A = "yingyue",    B = "ying yue",     Expected = {"ying", "yue"} },
        { A = "yingyue",    B = "ying yu e",    Expected = {"ying", "yu", "e"} }, -- 贪婪可能失败，启发式可能得到 {"yingy", "u", "e"}? 需要验证
        { A = "xian",       B = "xi an",        Expected = {"xi", "an"} },
        { A = "mama",       B = "ma ma",        Expected = {"ma", "ma"} },
        { A = "banana",     B = "ba na na",     Expected = {"ba", "na", "na"} },
        { A = "xiang",      B = "xi ang",       Expected = {"xi", "ang"} },
        -- 注意: V5 分析发现此用例的 Expected 可能与代码逻辑不符，代码倾向于返回启发式结果 {"chang", "gang", "e"}
        -- 这里保持原始 Expected 以观察行为，或修正 Expected 为 {"chang", "gang", "e"}
        { A = "changgange", B = "chang gang gui", Expected = {"chang", "gan", "ge"} },
        { A = "dengdai",    B = "den dai",      Expected = {"deng", "dai"} }, -- eng/en 混淆
        { A = "zhuangkuan", B = "zhuan kuan",   Expected = {"zhuang", "kuan"} }, -- uang/uan 混淆
        { A = "longjun",    B = "lun jun",      Expected = {"long", "jun"} }, -- ong/un 混淆
        { A = "fengshou",   B = "fong shou",    Expected = {"feng", "shou"} }, -- eng/ong 混淆
        { A = "xiongdi",    B = "xun di",       Expected = {"xiong", "di"} }, -- iong/un 混淆
        { A = "congqian",   B = "cen qian",     Expected = {"cong", "qian"} }, -- ong/eng ? (cen不是标准拼音韵母, B可能不规范?) 假设 B 是 cen -> eng 混淆
        { A = "rongyi",     B = "reng yi",      Expected = {"rong", "yi"} }, -- ong/eng 混淆
        { A = "weng",       B = "wen",          Expected = {"weng"} }, -- eng/en? B应该是 weng 或 wen? 假设 B 是 wen, A 是 weng
        { A = "chuang",     B = "chuan",        Expected = {"chuang"} }, -- uang/uan 混淆
        { A = "hun",        B = "hong",         Expected = {"hun"} }, -- un/ong 混淆
        { A = "shangcen",   B = "sang cen",     Expected = {"shang", "cen"} }, -- ang/an? cen? 假设 B 是规范的 "shang cen" -> {"shang", "cen"}
        { A = "zhishi",     B = "zhi si",       Expected = {"zhi", "shi"} }, -- 整体音节 zhi/chi/shi/ri vs zi/ci/si
        { A = "zisi",       B = "ci si",        Expected = {"zi", "si"} }, -- zi/ci
        { A = "abc",        B = "ab cd ef",     Expected = {} }, -- 无效拼音
        { A = "a",          B = "a",            Expected = {"a"} }, -- 单音节
        { A = "ang",        B = "an",           Expected = {"ang"} } -- ang/an 混淆? (不在默认混淆表)
    }

    local split_tests_passed = 0
    local split_tests_failed = 0

    -- 循环执行分割测试用例
    for i, tc in ipairs(test_cases) do
        -- 执行核心函数获取实际结果
        local result_final = M.split_pinyin_comparative_optimized_v5(tc.A, tc.B)

        -- 比较实际结果与期望结果
        local success = are_tables_equal(result_final, tc.Expected)

        -- 打印测试结果
        print(string.format("  分割测试 %d: A='%s', B='%s' -> %s", i, tc.A, tc.B, tostring(success)))

        -- 如果测试失败，打印详细信息以供调试
        if not success then
            split_tests_failed = split_tests_failed + 1
            print("  -----------------------------------------")
            print_table_output(result_final, "    实际")
            print_table_output(tc.Expected, "    期望")
            print("  -----------------------------------------")
        else
            split_tests_passed = split_tests_passed + 1
        end
    end

    print(string.format("\n--- 分割测试总结: %d 通过, %d 失败 ---\n", split_tests_passed, split_tests_failed))

    return split_tests_failed == 0 -- 如果没有失败则返回 true
end

--[[----------------------------------------------------------------------------
  测试函数: run_equivalent_pinyin_tests - 执行获取等效拼音测试用例 (新增 V6)
----------------------------------------------------------------------------]]
local function run_equivalent_pinyin_tests()
    print("\n--- 等效拼音获取测试 (get_equivalent_pinyin_segments) ---")
    print("--- 输出格式: true 表示通过, false 表示失败 ---")

    -- 定义测试数据
    local equivalent_test_cases = {
        { Input = "zhuang", Expected = {"zhuang", "zhuan"} }, -- uang/uan
        { Input = "zhuan",  Expected = {"zhuan", "zhuang"} }, -- uan/uang (需要 uan->uang 在 map 中)
        { Input = "long",   Expected = {"long", "lun", "lon", "leng"} }, -- ong -> un, on, eng
        { Input = "lun",    Expected = {"lun", "long", "liong"} }, -- un -> ong, iong
        { Input = "leng",   Expected = {"leng", "len", "long"} }, -- eng -> en, ong
        { Input = "len",    Expected = {"len", "leng"} }, -- en -> eng
        { Input = "lin",    Expected = {"lin", "ling"} }, -- in -> ing
        { Input = "ling",   Expected = {"ling", "lin"} }, -- ing -> in
        { Input = "xiong",  Expected = {"xiong", "xun"} }, -- iong -> un
        { Input = "xun",    Expected = {"xun", "xiong", "xong"} }, -- un -> iong, ong
        { Input = "ma",     Expected = {"ma"} }, -- 无混淆
        { Input = "zhi",    Expected = {"zhi"} }, -- 整体音节无混淆韵母 i
        { Input = "an",     Expected = {"an"} }, -- 韵母 an 不在混淆表中
        { Input = "",       Expected = {""} }, -- 空输入
        { Input = nil,      Expected = {nil} }, -- Nil 输入 (根据实现返回 {nil} 或 {}) - 当前实现返回 {nil}
    }

    local equivalent_tests_passed = 0
    local equivalent_tests_failed = 0

    -- 辅助函数：比较两个包含字符串的列表，忽略顺序
    local function are_string_tables_equal_ignore_order(t1, t2)
        if type(t1) ~= "table" or type(t2) ~= "table" then return false end
        if #t1 ~= #t2 then return false end
        local counts = {}
        for _, v in ipairs(t1) do counts[v] = (counts[v] or 0) + 1 end
        for _, v in ipairs(t2) do
            if not counts[v] or counts[v] == 0 then return false end
            counts[v] = counts[v] - 1
        end
        -- 确保所有计数都归零 (理论上 #t1 == #t2 保证了这点)
        return true
    end

    -- 循环执行等效获取测试用例
    for i, tc in ipairs(equivalent_test_cases) do
        local input_str = tc.Input
        -- 对于 nil 输入，打印 "nil" 而不是尝试格式化
        local input_display = type(input_str) == "nil" and "nil" or string.format("'%s'", input_str)

        local result_equivalents = M.get_equivalent_pinyin_segments(input_str)

        -- 使用忽略顺序的比较
        local success = are_string_tables_equal_ignore_order(result_equivalents, tc.Expected)

        print(string.format("  等效测试 %d: Input=%s -> %s", i, input_display, tostring(success)))

        if not success then
            equivalent_tests_failed = equivalent_tests_failed + 1
            print("  -----------------------------------------")
            -- 对结果进行排序以便比较
            table.sort(result_equivalents)
            table.sort(tc.Expected)
            print_table_output(result_equivalents, "    实际 (排序后)")
            print_table_output(tc.Expected,       "    期望 (排序后)")
            print("  -----------------------------------------")
        else
            equivalent_tests_passed = equivalent_tests_passed + 1
        end
    end

     print(string.format("\n--- 等效拼音测试总结: %d 通过, %d 失败 ---\n", equivalent_tests_passed, equivalent_tests_failed))

    return equivalent_tests_failed == 0 -- 如果没有失败则返回 true
end

--[[----------------------------------------------------------------------------
  主测试函数: run_all_tests (调用所有测试) - 新增 V6
----------------------------------------------------------------------------]]
local function run_all_tests()
    local split_ok = run_pinyin_split_tests()
    local equiv_ok = run_equivalent_pinyin_tests()

    if split_ok and equiv_ok then
        print("--- 所有测试通过 ---")
        return true
    else
        print("--- 部分测试失败 ---")
        return false
    end
end

-- 仅在需要时导出测试相关函数
M._tests = {
    run_pinyin_split_tests = run_pinyin_split_tests,
    run_equivalent_pinyin_tests = run_equivalent_pinyin_tests, -- 导出新测试
    run_all_tests = run_all_tests, -- 导出总测试入口
    are_tables_equal = are_tables_equal,
    print_table_output = print_table_output,
    get_equivalent_pinyin_segments = M.get_equivalent_pinyin_segments -- 也导出新函数本身以便外部调用
}

return M