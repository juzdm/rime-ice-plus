--[[
  获取分词信息的处理器
  用于调试和开发时查看分词结果
  仅仅用于调试目的
--]]

local function processor(key, env)
    -- 获取当前环境中的上下文
    local context = env.engine.context
    if not context then
        print("错误: 无法获取上下文")
        return 2
    end

    -- 获取当前输入的字符串
    local input = context.input
    if not input then
        print("错误: 无法获取输入")
        return 2
    end

    print("\n=== 输入处理信息 ===")
    print("当前输入:", input)

    -- 获取 composition 对象
    local composition = context.composition
    if composition then
        -- 尝试获取 segmentation
        if composition.GetSegmentation then
            print("\n--- 使用 GetSegmentation 方法 ---")
            local segs = composition:GetSegmentation()
            if segs then
                print("分词数量:", segs:size())
                for i = 0, segs:size() - 1 do
                    local seg = segs:at(i)
                    if seg then
                        print(string.format("分词[%d]: %s", i + 1, seg:get_prompt()))
                    end
                end
            end
        end

        -- 尝试使用 select_candidates
        if composition.select_candidates then
            print("\n--- 使用 select_candidates ---")
            local candidates = composition:select_candidates()
            if candidates then
                print("候选项数量:", #candidates)
                for i, cand in ipairs(candidates) do
                    print(string.format("候选[%d]: %s", i, cand.text))
                end
            end
        end

        -- 尝试获取预编辑文本并手动分析
        local preedit = composition.preedit
        if preedit and preedit.text then
            print("\n--- 预编辑文本分析 ---")
            local text = preedit.text
            print("预编辑文本:", text)
            
            -- 尝试按空格分割
            local parts = {}
            for part in text:gmatch("%S+") do
                table.insert(parts, part)
            end
            print("分割结果:", table.concat(parts, "|"))
        end
    end

    print("===============")
    return 2
end

return processor