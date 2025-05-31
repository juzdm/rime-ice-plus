local M = {}

-- 常量定义
local DEFAULT_STYLE = '{comment}'
local PINYIN_PATTERN = "^［(.-)］$"

-- 只对前二十个候选词镜像纠错注音，避免性能问题
local MAX_COMMENT_CAND = 20

-- 模块级配置
M.config = {
    style = DEFAULT_STYLE,
    delimiter = ' '
}

-- 拼音分析结果缓存
M.analysis_cache = {
    input = "",
    pinyin = "",
    segments = {}
}

-- 加载拼音分析工具
local function load_pinyin_analyzer()
    local module = require("candidates_to_raw")
    if type(module) ~= "table" then
        -- print("警告：拼音分析模块加载失败")
        return {
            split_pinyin = function() return {} end,
            are_segments_equivalent = function() return false end
        }
    end
    
    -- 使用正确的函数名
    return {
        split_pinyin = module.split_pinyin_comparative_optimized_v5,
        are_segments_equivalent = module.are_pinyin_segments_equivalent  -- 这里保持原名作为别名
    }
end

-- 分析候选项拼音
local function analyze_candidate_pinyin(pinyin, input_str, analyzer)
    if not (pinyin and #pinyin > 0 and input_str) then
        return nil
    end
    
    local segments = analyzer.split_pinyin(input_str, pinyin)
    return {
        pinyin = pinyin,
        segments = segments
    }
end

-- 检查拼音混淆
local function check_pinyin_confusion(segments, standard_segments, analyzer)
    local has_confusion = false
    local corrected_segments = {}
    
    for i, segment in ipairs(segments) do
        local std_segment = standard_segments[i]
        if std_segment then
            if analyzer.are_segments_equivalent(segment, std_segment) and segment ~= std_segment then
                has_confusion = true
                table.insert(corrected_segments, std_segment)
            else
                table.insert(corrected_segments, segment)
            end
        end
    end
    
    return has_confusion, table.concat(corrected_segments, " ")
end

function M.init(env)
    local config = env.engine.schema.config
    env.keep_comment = config:get_bool('translator/keep_comments')
    
    -- 初始化分隔符
    local delimiter = config:get_string('speller/delimiter')
    if delimiter and #delimiter > 0 and delimiter:sub(1,1) ~= ' ' then
        M.config.delimiter = delimiter:sub(1,1)
    end
    
    -- 初始化样式
    env.name_space = env.name_space:gsub('^*', '')
    M.config.style = config:get_string(env.name_space) or DEFAULT_STYLE
    
    -- 初始化拼音分析器
    local analyzer = load_pinyin_analyzer()
    M.split_pinyin = analyzer.split_pinyin
    M.are_segments_equivalent = analyzer.are_segments_equivalent
    
    -- 添加调试信息
    -- print("拼音分析器初始化状态：")
    -- print("split_pinyin:", type(M.split_pinyin))
    -- print("are_segments_equivalent:", type(M.are_segments_equivalent))
end

function M.func(input, env)
    local input_str = env.engine.context.input
    local first_candidate_info = nil
    local candidate_count = 0
    
    for cand in input:iter() do
        local pinyin = cand.comment:match(PINYIN_PATTERN)

        candidate_count = candidate_count + 1
        
        if pinyin and #pinyin > 0 and candidate_count <= MAX_COMMENT_CAND then
            -- 处理第一个候选项
            if not first_candidate_info then
                first_candidate_info = analyze_candidate_pinyin(pinyin, input_str, M)
                if first_candidate_info then
                    M.analysis_cache = {
                        input = input_str,
                        pinyin = first_candidate_info.pinyin,
                        segments = first_candidate_info.segments
                    }
                    
                    -- 打印分析结果
                    -- print(string.format("\n输入串: %s", input_str))
                    -- print(string.format("候选拼音: %s", pinyin))
                    -- for i, seg in ipairs(first_candidate_info.segments) do
                    --     -- print(string.format("[%d] %s", i, seg))
                    -- end
                end
            end
            
            -- 检查韵母混淆
            local segments = {}
            for seg in pinyin:gmatch("[^ ]+") do
                table.insert(segments, seg)
            end
            
            if first_candidate_info then
                local has_confusion, input_py = check_pinyin_confusion(
                    segments, 
                    first_candidate_info.segments, 
                    M
                )
                
                if has_confusion then
                    cand:get_genuine().comment = string.format("%s", 
                        pinyin)
                end
            end
        end
        
        yield(cand)
    end
end

return M