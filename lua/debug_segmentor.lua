--[[
  分词器调试组件
  用于查看分词结果
  仅仅用于调试目的
--]]

local function segmentor(segmentation, env)
    -- 获取整个输入串
    local input = segmentation.input
    if not input then 
        print("无输入字符串")
        return true 
    end
    
    print("\n=== 分词器调试信息 ===")
    print("输入字符串:", input)
    print("输入长度:", string.len(input))
    
    -- 打印分词器状态
    print("\n--- 分词器状态 ---")
    local start_pos = type(segmentation.start) == "number" and segmentation.start or 0
    local end_pos = type(segmentation._end) == "number" and segmentation._end or string.len(input)
    
    print("当前位置:", start_pos)
    print("结束位置:", end_pos)
    print("当前分段类型:", segmentation.type or "unknown")
    
    -- 尝试获取分词信息
    if start_pos < end_pos then
        -- 创建一个有效的文本片段
        local text = string.sub(input, start_pos + 1, end_pos)
        if text and #text > 0 then
            print("\n--- 当前分段信息 ---")
            print(string.format("范围: [%d, %d]", start_pos, end_pos))
            print("文本:", text)
            
            -- 标记此段为有效分词
            segmentation.pending = true
            -- 更新下一个分词的起始位置
            segmentation.start = end_pos
        end
    end
    
    print("===============")
    return true
end

return segmentor
