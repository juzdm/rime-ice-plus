local simplehttp = {}

simplehttp.TIMEOUT = 5 -- 设置超时时间（这里实际无效，因为 io.popen 不支持超时设置）

-- 解析 URL 的函数
local function parse_url(url_str)
    local scheme, rest = url_str:match("^(.-)://(.+)$")
    if not scheme then
        scheme = "http" -- 默认为 http
        rest = url_str
    end

    local host, port, path = rest:match("^(.-):(%d+)(/.+)$")
    if not host then
        host, path = rest:match("^(.-)(/.+)$")
        if not host then
            host = rest
            path = "/"
        end
    else
        path = path or "/"
    end

    local query = path:match("?(.*)")
    if query then
        path = path:match("^(.-)%?")
    end

    return {
        scheme = scheme,
        host = host,
        port = tonumber(port) or (scheme == "https" and 443 or 80),
        path = path,
        query = query
    }
end

-- 构建 HTTP 请求的函数
local function create_request(method, host, path, headers, body)
    local request = method .. " " .. path .. " HTTP/1.1\r\n"
    request = request .. "Host: " .. host .. "\r\n"
    
    if not headers["User-Agent"] then
        request = request .. "User-Agent: SimpleHTTP/1.0\r\n"
    end

    if not headers["Accept"] then
        request = request .. "Accept: */*\r\n"
    end

    for k, v in pairs(headers) do
        request = request .. k .. ": " .. v .. "\r\n"
    end

    if body then
        request = request .. "Content-Length: " .. #body .. "\r\n"
        request = request .. "\r\n" .. body
    else
        request = request .. "\r\n"
    end

    return request
end

-- 使用 curl 执行 HTTP 请求并读取响应
local function http_request(url, method, headers, body)
    local request = create_request(method, url.host, url.path .. (url.query and "?" .. url.query or ""), headers, body)
    local cmd = string.format("CURL_HOME=/dev/null curl --config /dev/null -s -q -i -X %s '%s'", method, url.scheme .. "://" .. url.host .. (url.port and ":" .. url.port or "") .. url.path .. (url.query and "?" .. url.query or ""))
    
    -- 使用 io.popen 执行 curl 命令
    local handle = io.popen(cmd)
    local response = handle:read("*a")
    handle:close()
    
    -- 处理 curl 输出中的前缀
    -- response = response:gsub("^#011 reply=#011", "")
    response = response:gsub("#011", " ")

    return response
end

-- 解析响应头和响应体
local function parse_response(response)
    local header_end = response:find("\r\n\r\n")
    if not header_end then
        return nil, "Invalid response format"
    end

    local headers = response:sub(1, header_end - 1)
    local body = response:sub(header_end + 4)

    return headers, body
end

-- 发送 HTTP 请求的主函数
local function request(url_str, method, headers, body)
    local parsed_url = parse_url(url_str)
    if not parsed_url then
        return nil, "Invalid URL"
    end

    method = method or "GET"
    headers = headers or {}
    
    local response = http_request(parsed_url, method, headers, body)
    local headers, body = parse_response(response)
    
    return body, headers
end

function simplehttp.request(url_str, options)
    local method = options and options.method or "GET"
    local headers = options and options.headers or {}
    local body = options and options.body

    return request(url_str, method, headers, body)
end

return simplehttp
