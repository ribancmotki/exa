const std = @import("std");
const app_state = @import("../app_state.zig");
const common = @import("../types/common.zig");
const protocol = @import("./protocol.zig");
const tools = @import("./tools.zig");

pub fn handleMcp(req: *common.HttpRequest, state: *app_state.AppState, allocator: std.mem.Allocator) !common.HttpResponse {
    const body = req.body;

    if (body.len == 0) {
        return jsonResponse(200, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Parse error\"}}", allocator);
    }

    const rpc_req = protocol.parseRequest(body, allocator) catch |err| {
        std.log.warn("MCP parse error: {}", .{err});
        return jsonResponse(200, "{\"jsonrpc\":\"2.0\",\"id\":null,\"error\":{\"code\":-32700,\"message\":\"Parse error\"}}", allocator);
    };

    if (std.mem.eql(u8, rpc_req.method, "initialize")) {
        const result = try buildInitializeResult(allocator);
        const resp_body = try protocol.buildSuccess(rpc_req.id, result, allocator);
        return jsonResponse(200, resp_body, allocator);
    }

    if (std.mem.eql(u8, rpc_req.method, "tools/list")) {
        const tool_list = try tools.listTools(allocator);
        var result_obj = std.json.ObjectMap.init(allocator);
        try result_obj.put("tools", tool_list);
        const result = std.json.Value{ .object = result_obj };
        const resp_body = try protocol.buildSuccess(rpc_req.id, result, allocator);
        return jsonResponse(200, resp_body, allocator);
    }

    if (std.mem.eql(u8, rpc_req.method, "tools/call")) {
        const params = rpc_req.params orelse return jsonResponse(200,
            try protocol.buildError(rpc_req.id, -32602, "Missing params", allocator), allocator);
        const params_obj = if (params == .object) params.object else return jsonResponse(200,
            try protocol.buildError(rpc_req.id, -32602, "Invalid params", allocator), allocator);
        const tool_name_val = params_obj.get("name") orelse return jsonResponse(200,
            try protocol.buildError(rpc_req.id, -32602, "Missing name", allocator), allocator);
        const tool_name = if (tool_name_val == .string) tool_name_val.string else return jsonResponse(200,
            try protocol.buildError(rpc_req.id, -32602, "Invalid name", allocator), allocator);
        const tool_params = params_obj.get("arguments") orelse std.json.Value{ .null = {} };

        const tool_result = tools.dispatch(tool_name, tool_params, null, state, allocator) catch |err| {
            const err_msg = try std.fmt.allocPrint(allocator, "Tool error: {s}", .{@errorName(err)});
            return jsonResponse(200, try protocol.buildError(rpc_req.id, -32603, err_msg, allocator), allocator);
        };

        var content_arr = std.json.Array.init(allocator);
        var content_obj = std.json.ObjectMap.init(allocator);
        try content_obj.put("type", std.json.Value{ .string = "text" });
        var text_buf = std.ArrayList(u8).init(allocator);
        try std.json.stringify(tool_result, .{}, text_buf.writer());
        try content_obj.put("text", std.json.Value{ .string = try text_buf.toOwnedSlice() });
        try content_arr.append(std.json.Value{ .object = content_obj });

        var result_obj = std.json.ObjectMap.init(allocator);
        try result_obj.put("content", std.json.Value{ .array = content_arr });
        try result_obj.put("isError", std.json.Value{ .bool = false });

        const resp_body = try protocol.buildSuccess(rpc_req.id, std.json.Value{ .object = result_obj }, allocator);
        return jsonResponse(200, resp_body, allocator);
    }

    if (std.mem.eql(u8, rpc_req.method, "notifications/initialized")) {
        return jsonResponse(200, "", allocator);
    }

    const err_body = try protocol.buildError(rpc_req.id, -32601, "Method not found", allocator);
    return jsonResponse(200, err_body, allocator);
}

fn buildInitializeResult(allocator: std.mem.Allocator) !std.json.Value {
    var obj = std.json.ObjectMap.init(allocator);
    try obj.put("protocolVersion", std.json.Value{ .string = "2024-11-05" });
    var caps = std.json.ObjectMap.init(allocator);
    var tool_caps = std.json.ObjectMap.init(allocator);
    try tool_caps.put("listChanged", std.json.Value{ .bool = false });
    try caps.put("tools", std.json.Value{ .object = tool_caps });
    try obj.put("capabilities", std.json.Value{ .object = caps });
    var server_info = std.json.ObjectMap.init(allocator);
    try server_info.put("name", std.json.Value{ .string = "search-platform-mcp" });
    try server_info.put("version", std.json.Value{ .string = "0.1.0" });
    try obj.put("serverInfo", std.json.Value{ .object = server_info });
    return std.json.Value{ .object = obj };
}

fn jsonResponse(status: u16, body: []const u8, allocator: std.mem.Allocator) !common.HttpResponse {
    var headers = std.StringHashMap([]const u8).init(allocator);
    try headers.put("content-type", "application/json");
    return common.HttpResponse{
        .status = status,
        .headers = headers,
        .body = body,
    };
}
