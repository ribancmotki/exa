const std = @import("std");

pub const redisContext = opaque {};

pub const redisReply = extern struct {
    type: c_int,
    integer: c_longlong,
    dval: f64,
    len: usize,
    str: ?[*:0]u8,
    vtype: [4]u8,
    elements: usize,
    element: ?[*]?*redisReply,
};

pub const REDIS_REPLY_STRING: c_int = 1;
pub const REDIS_REPLY_ARRAY: c_int = 2;
pub const REDIS_REPLY_INTEGER: c_int = 3;
pub const REDIS_REPLY_NIL: c_int = 4;
pub const REDIS_REPLY_STATUS: c_int = 5;
pub const REDIS_REPLY_ERROR: c_int = 6;

extern fn redisConnect(ip: [*:0]const u8, port: c_int) ?*redisContext;
extern fn redisConnectWithTimeout(ip: [*:0]const u8, port: c_int, tv: extern struct { tv_sec: c_long, tv_usec: c_long }) ?*redisContext;
extern fn redisFree(c: ?*redisContext) void;
extern fn redisCommand(c: ?*redisContext, format: [*:0]const u8, ...) ?*redisReply;
extern fn freeReplyObject(reply: ?*anyopaque) void;
extern fn redisGetReply(c: ?*redisContext, reply: *?*redisReply) c_int;
extern fn redisAppendCommand(c: ?*redisContext, format: [*:0]const u8, ...) c_int;

fn parseUrl(url: []const u8, host_buf: []u8, port_out: *u16, password_buf: []u8, password_len: *usize) !usize {
    var rest = url;
    if (std.mem.startsWith(u8, rest, "redis://")) {
        rest = rest[8..];
    }
    password_len.* = 0;
    if (std.mem.indexOfScalar(u8, rest, '@')) |at_idx| {
        const auth = rest[0..at_idx];
        if (std.mem.indexOfScalar(u8, auth, ':')) |colon_idx| {
            const pwd = auth[colon_idx + 1..];
            const copy_len = @min(pwd.len, password_buf.len - 1);
            @memcpy(password_buf[0..copy_len], pwd[0..copy_len]);
            password_buf[copy_len] = 0;
            password_len.* = copy_len;
        }
        rest = rest[at_idx + 1..];
    }
    const slash_idx = std.mem.indexOfScalar(u8, rest, '/');
    const host_port_end = slash_idx orelse rest.len;
    const host_port = rest[0..host_port_end];
    if (std.mem.lastIndexOfScalar(u8, host_port, ':')) |colon_idx| {
        const port_str = host_port[colon_idx + 1..];
        port_out.* = std.fmt.parseInt(u16, port_str, 10) catch 6379;
        const host_len = @min(colon_idx, host_buf.len - 1);
        @memcpy(host_buf[0..host_len], host_port[0..host_len]);
        host_buf[host_len] = 0;
        return host_len;
    } else {
        const host_len = @min(host_port.len, host_buf.len - 1);
        @memcpy(host_buf[0..host_len], host_port[0..host_len]);
        host_buf[host_len] = 0;
        port_out.* = 6379;
        return host_len;
    }
}

fn executeCommand(ctx: *redisContext, fmt: [*:0]const u8, args: anytype) ?*redisReply {
    _ = args;
    return @call(.auto, redisCommand, .{ ctx, fmt });
}

pub const Client = struct {
    ctx: *redisContext,

    pub fn connect(url: []const u8) !Client {
        var host_buf: [256]u8 = undefined;
        var port: u16 = 6379;
        var password_buf: [512]u8 = undefined;
        var password_len: usize = 0;
        _ = try parseUrl(url, &host_buf, &port, &password_buf, &password_len);

        const ctx = redisConnect(@ptrCast(&host_buf), @intCast(port)) orelse {
            return error.ConnectionFailed;
        };

        if (password_len > 0) {
            const reply = redisCommand(ctx, "AUTH %s", @as([*:0]const u8, @ptrCast(&password_buf)));
            if (reply) |r| freeReplyObject(r);
        }

        return Client{ .ctx = ctx };
    }

    pub fn deinit(self: *Client) void {
        redisFree(self.ctx);
    }

    pub fn get(self: *Client, key: []const u8, allocator: std.mem.Allocator) !?[]const u8 {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "GET %s", @as([*:0]const u8, @ptrCast(&key_buf))) orelse return error.CacheError;
        defer freeReplyObject(reply);
        if (reply.type == REDIS_REPLY_NIL or reply.type == REDIS_REPLY_ERROR) return null;
        if (reply.type != REDIS_REPLY_STRING and reply.type != REDIS_REPLY_STATUS) return null;
        const str = reply.str orelse return null;
        const len = reply.len;
        return try allocator.dupe(u8, str[0..len]);
    }

    pub fn set(self: *Client, key: []const u8, value: []const u8, ttl_seconds: ?u64) !void {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        var val_buf = try std.heap.page_allocator.alloc(u8, value.len + 1);
        defer std.heap.page_allocator.free(val_buf);
        @memcpy(val_buf[0..value.len], value);
        val_buf[value.len] = 0;

        if (ttl_seconds) |ttl| {
            const reply = redisCommand(self.ctx, "SETEX %s %d %s", @as([*:0]const u8, @ptrCast(&key_buf)), @as(c_int, @intCast(ttl)), @as([*:0]u8, @ptrCast(val_buf.ptr))) orelse return error.CacheError;
            defer freeReplyObject(reply);
        } else {
            const reply = redisCommand(self.ctx, "SET %s %s", @as([*:0]const u8, @ptrCast(&key_buf)), @as([*:0]u8, @ptrCast(val_buf.ptr))) orelse return error.CacheError;
            defer freeReplyObject(reply);
        }
    }

    pub fn del(self: *Client, key: []const u8) !void {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "DEL %s", @as([*:0]const u8, @ptrCast(&key_buf))) orelse return error.CacheError;
        defer freeReplyObject(reply);
    }

    pub fn incrby(self: *Client, key: []const u8, amount: i64) !i64 {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "INCRBY %s %lld", @as([*:0]const u8, @ptrCast(&key_buf)), @as(c_longlong, amount)) orelse return error.CacheError;
        defer freeReplyObject(reply);
        if (reply.type == REDIS_REPLY_INTEGER) return @as(i64, reply.integer);
        return error.CacheError;
    }

    pub fn expire(self: *Client, key: []const u8, ttl_seconds: u64) !void {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "EXPIRE %s %d", @as([*:0]const u8, @ptrCast(&key_buf)), @as(c_int, @intCast(ttl_seconds))) orelse return error.CacheError;
        defer freeReplyObject(reply);
    }

    pub fn setNx(self: *Client, key: []const u8, value: []const u8, ttl_seconds: u64) !bool {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        var val_buf = try std.heap.page_allocator.alloc(u8, value.len + 1);
        defer std.heap.page_allocator.free(val_buf);
        @memcpy(val_buf[0..value.len], value);
        val_buf[value.len] = 0;
        const reply = redisCommand(self.ctx, "SET %s %s NX EX %d", @as([*:0]const u8, @ptrCast(&key_buf)), @as([*:0]u8, @ptrCast(val_buf.ptr)), @as(c_int, @intCast(ttl_seconds))) orelse return error.CacheError;
        defer freeReplyObject(reply);
        if (reply.type == REDIS_REPLY_STATUS) {
            const status = reply.str orelse return false;
            return std.mem.eql(u8, std.mem.span(status), "OK");
        }
        return false;
    }

    pub fn exists(self: *Client, key: []const u8) !bool {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "EXISTS %s", @as([*:0]const u8, @ptrCast(&key_buf))) orelse return error.CacheError;
        defer freeReplyObject(reply);
        if (reply.type == REDIS_REPLY_INTEGER) return reply.integer > 0;
        return false;
    }

    pub fn ttl(self: *Client, key: []const u8) !i64 {
        var key_buf: [4096]u8 = undefined;
        if (key.len >= key_buf.len) return error.CacheError;
        @memcpy(key_buf[0..key.len], key);
        key_buf[key.len] = 0;
        const reply = redisCommand(self.ctx, "TTL %s", @as([*:0]const u8, @ptrCast(&key_buf))) orelse return error.CacheError;
        defer freeReplyObject(reply);
        if (reply.type == REDIS_REPLY_INTEGER) return @as(i64, reply.integer);
        return -1;
    }
};

pub const Pool = struct {
    clients: []*Client,
    available: std.ArrayList(*Client),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    allocator: std.mem.Allocator,
    size: usize,

    pub fn init(allocator: std.mem.Allocator, url: []const u8, size: usize) !*Pool {
        const self = try allocator.create(Pool);
        errdefer allocator.destroy(self);

        self.clients = try allocator.alloc(*Client, size);
        errdefer allocator.free(self.clients);

        self.available = std.ArrayList(*Client).init(allocator);
        errdefer self.available.deinit();
        try self.available.ensureTotalCapacity(size);

        self.mutex = .{};
        self.cond = .{};
        self.allocator = allocator;
        self.size = size;

        var created: usize = 0;
        errdefer {
            for (self.clients[0..created]) |c| {
                c.deinit();
                allocator.destroy(c);
            }
        }

        for (self.clients) |*slot| {
            const c = try allocator.create(Client);
            errdefer allocator.destroy(c);
            c.* = try Client.connect(url);
            slot.* = c;
            try self.available.append(c);
            created += 1;
        }

        return self;
    }

    pub fn deinit(self: *Pool) void {
        for (self.clients) |c| {
            c.deinit();
            self.allocator.destroy(c);
        }
        self.allocator.free(self.clients);
        self.available.deinit();
        self.allocator.destroy(self);
    }

    pub fn acquire(self: *Pool) *Client {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.available.items.len == 0) {
            self.cond.wait(&self.mutex);
        }
        return self.available.pop();
    }

    pub fn release(self: *Pool, client: *Client) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.available.append(client) catch {};
        self.cond.signal();
    }
};
