local server = require "resty.websocket.server"
local cjson = require "cjson.safe"
local ffi = require "ffi"
local slamInterface = ffi.load("libslamInterface.so")

if pcall(function () return slamInterface.FFIInterface end) then
    -- do nothing
else
ffi.cdef[[
    char* FFIInterface(const char* data);
]]
end

local function receive_text(wb)
    local data, typ, err = wb:recv_frame()
    if not data then
        ngx.log(ngx.ERR, "failed to receive a frame: ", err)
        return ngx.exit(444)
    end
    if typ == "text" then
        --ngx.log(ngx.INFO, "received a text frame: ", data);
        return data
    else
        ngx.log(ngx.ERR, "failed to receive a text, ", "the type is: ", typ)
        return nil
    end                                                                         
end

local function delay_ms(ms)
    local time1 = get_current_time()
    while ((get_current_time() - time1) < 0.001 * ms)
    do
        --pass
    end
    return
end



local wb, err = server:new{
    --timeout = 30,  -- in milliseconds
    max_payload_len = 200*1024,
}
if not wb then
    ngx.log(ngx.ERR, "failed to new websocket: ", err)
    return ngx.exit(444)
end

while true
do
    local data = receive_text(wb)
    local c_result = slamInterface.FFIInterface(data)
    local receive_json = cjson.decode(data)
    ngx.log(ngx.INFO, "receive data is: ", data)
    ngx.log(ngx.INFO, "type is: ", receive_json.type)
    ngx.log(ngx.INFO, "pts_obj ", receive_json.pts_obj)
    ngx.log(ngx.INFO, "pts_img ", receive_json.pts_img) 
    ngx.log(ngx.INFO, "c_result ", ffi.string(c_result))   
    local obj = 
    {
        type = "RESULT",
        matrix = "0.999998,0.000596079,0.00178472,-0.00488085;-0.000597109,1,0.000576504,-0.00236156;-0.00178437,-0.000577568,0.999998,-0.0075835;0,0,0,1;",
        inliers = 20
    }
    local str = cjson.encode(obj)
    local bytes, err = wb:send_text(ffi.string(c_result))
end
if not bytes then
    ngx.log(ngx.ERR, "failed to send a text frame: ", err)
    return ngx.exit(444)
end

local bytes, err = wb:send_close(1000, "enough, enough!")
if not bytes then
    ngx.log(ngx.ERR, "failed to send the close frame: ", err)
    return
end

