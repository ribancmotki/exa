const std = @import("std");

pub const PGconn = opaque {};
pub const PGresult = opaque {};
pub const Oid = u32;

pub const ExecStatusType = enum(c_int) {
    PGRES_EMPTY_QUERY = 0,
    PGRES_COMMAND_OK = 1,
    PGRES_TUPLES_OK = 2,
    PGRES_COPY_OUT = 3,
    PGRES_COPY_IN = 4,
    PGRES_BAD_RESPONSE = 5,
    PGRES_NONFATAL_ERROR = 6,
    PGRES_FATAL_ERROR = 7,
};

const ConnStatusType = enum(c_int) {
    CONNECTION_OK = 0,
    CONNECTION_BAD = 1,
    _,
};

extern fn PQconnectdb(conninfo: [*:0]const u8) ?*PGconn;
extern fn PQstatus(conn: ?*PGconn) ConnStatusType;
extern fn PQerrorMessage(conn: ?*PGconn) [*:0]const u8;
extern fn PQexec(conn: ?*PGconn, query: [*:0]const u8) ?*PGresult;
extern fn PQexecParams(
    conn: ?*PGconn,
    command: [*:0]const u8,
    nParams: c_int,
    paramTypes: ?[*]const Oid,
    paramValues: ?[*]const ?[*:0]const u8,
    paramLengths: ?[*]const c_int,
    paramFormats: ?[*]const c_int,
    resultFormat: c_int,
) ?*PGresult;
extern fn PQclear(result: ?*PGresult) void;
extern fn PQnfields(result: ?*PGresult) c_int;
extern fn PQntuples(result: ?*PGresult) c_int;
extern fn PQfname(result: ?*PGresult, col_index: c_int) [*:0]const u8;
extern fn PQgetvalue(result: ?*PGresult, row: c_int, col: c_int) [*:0]u8;
extern fn PQgetlength(result: ?*PGresult, row: c_int, col: c_int) c_int;
extern fn PQgetisnull(result: ?*PGresult, row: c_int, col: c_int) c_int;
extern fn PQresultStatus(result: ?*PGresult) ExecStatusType;
extern fn PQfinish(conn: ?*PGconn) void;
extern fn PQescapeStringConn(conn: ?*PGconn, to: [*]u8, from: [*]const u8, length: usize, error_: ?*c_int) usize;

pub const Connection = struct {
    pg_conn: *PGconn,

    pub fn connect(dsn: []const u8) !Connection {
        var dsn_buf: [4096]u8 = undefined;
        if (dsn.len >= dsn_buf.len) return error.ConnectionFailed;
        @memcpy(dsn_buf[0..dsn.len], dsn);
        dsn_buf[dsn.len] = 0;
        const conn = PQconnectdb(@ptrCast(dsn_buf[0..dsn.len :0].ptr)) orelse {
            return error.ConnectionFailed;
        };
        if (PQstatus(conn) != .CONNECTION_OK) {
            std.log.err("PostgreSQL connection failed: {s}", .{std.mem.span(PQerrorMessage(conn))});
            PQfinish(conn);
            return error.ConnectionFailed;
        }
        return Connection{ .pg_conn = conn };
    }

    pub fn deinit(self: *Connection) void {
        PQfinish(self.pg_conn);
    }

    pub fn exec(self: *Connection, sql: []const u8, params: []const []const u8) !*PGresult {
        if (params.len == 0) {
            var sql_buf: [65536]u8 = undefined;
            if (sql.len >= sql_buf.len) return error.QueryFailed;
            @memcpy(sql_buf[0..sql.len], sql);
            sql_buf[sql.len] = 0;
            const r = PQexec(self.pg_conn, @ptrCast(sql_buf[0..sql.len :0].ptr)) orelse return error.QueryFailed;
            return r;
        }

        var null_term_params = try std.heap.page_allocator.alloc([*:0]const u8, params.len);
        defer std.heap.page_allocator.free(null_term_params);
        var param_bufs = try std.heap.page_allocator.alloc([]u8, params.len);
        defer {
            for (param_bufs) |buf| std.heap.page_allocator.free(buf);
            std.heap.page_allocator.free(param_bufs);
        }

        for (params, 0..) |p, i| {
            const buf = try std.heap.page_allocator.alloc(u8, p.len + 1);
            @memcpy(buf[0..p.len], p);
            buf[p.len] = 0;
            param_bufs[i] = buf;
            null_term_params[i] = @ptrCast(buf.ptr);
        }

        var sql_buf: [65536]u8 = undefined;
        if (sql.len >= sql_buf.len) return error.QueryFailed;
        @memcpy(sql_buf[0..sql.len], sql);
        sql_buf[sql.len] = 0;

        const r = PQexecParams(
            self.pg_conn,
            @ptrCast(sql_buf[0..sql.len :0].ptr),
            @intCast(params.len),
            null,
            @ptrCast(null_term_params.ptr),
            null,
            null,
            0,
        ) orelse return error.QueryFailed;
        return r;
    }

    pub fn execCommand(self: *Connection, sql: []const u8, params: []const []const u8) !void {
        const result = try self.exec(sql, params);
        defer PQclear(result);
        const status = PQresultStatus(result);
        switch (status) {
            .PGRES_COMMAND_OK, .PGRES_TUPLES_OK => {},
            else => {
                std.log.err("PostgreSQL command failed: {s}", .{std.mem.span(PQerrorMessage(self.pg_conn))});
                return error.QueryFailed;
            },
        }
    }

    pub fn query(self: *Connection, sql: []const u8, params: []const []const u8) !ResultSet {
        const result = try self.exec(sql, params);
        const status = PQresultStatus(result);
        switch (status) {
            .PGRES_TUPLES_OK, .PGRES_COMMAND_OK => {},
            else => {
                PQclear(result);
                std.log.err("PostgreSQL query failed: {s}", .{std.mem.span(PQerrorMessage(self.pg_conn))});
                return error.QueryFailed;
            },
        }
        return ResultSet{ .result = result };
    }

    pub fn queryRow(self: *Connection, sql: []const u8, params: []const []const u8) !?Row {
        var rs = try self.query(sql, params);
        if (!rs.next()) {
            rs.deinit();
            return null;
        }
        const r = rs.rowAt();
        rs.result_freed = true;
        return r;
    }

    pub fn begin(self: *Connection) !void {
        try self.execCommand("BEGIN", &.{});
    }

    pub fn commit(self: *Connection) !void {
        try self.execCommand("COMMIT", &.{});
    }

    pub fn rollback(self: *Connection) void {
        self.execCommand("ROLLBACK", &.{}) catch {};
    }
};

pub const ResultSet = struct {
    result: *PGresult,
    row_index: i32 = 0,
    result_freed: bool = false,

    pub fn next(self: *ResultSet) bool {
        const n = PQntuples(self.result);
        if (self.row_index >= n) return false;
        const r = self.row_index;
        self.row_index += 1;
        _ = r;
        return true;
    }

    pub fn rowAt(self: *ResultSet) Row {
        return Row{
            .result = self.result,
            .row_index = self.row_index - 1,
        };
    }

    pub fn numRows(self: *const ResultSet) i32 {
        return PQntuples(self.result);
    }

    pub fn deinit(self: *ResultSet) void {
        if (!self.result_freed) {
            PQclear(self.result);
            self.result_freed = true;
        }
    }
};

pub const Row = struct {
    result: *PGresult,
    row_index: i32,

    pub fn getString(self: *const Row, col: i32) ?[]const u8 {
        if (PQgetisnull(self.result, self.row_index, col) == 1) return null;
        const ptr = PQgetvalue(self.result, self.row_index, col);
        const len = @as(usize, @intCast(PQgetlength(self.result, self.row_index, col)));
        return ptr[0..len];
    }

    pub fn getInt(self: *const Row, col: i32) ?i32 {
        const s = self.getString(col) orelse return null;
        return std.fmt.parseInt(i32, s, 10) catch null;
    }

    pub fn getInt64(self: *const Row, col: i32) ?i64 {
        const s = self.getString(col) orelse return null;
        return std.fmt.parseInt(i64, s, 10) catch null;
    }

    pub fn getUint64(self: *const Row, col: i32) ?u64 {
        const s = self.getString(col) orelse return null;
        return std.fmt.parseInt(u64, s, 10) catch null;
    }

    pub fn getBool(self: *const Row, col: i32) ?bool {
        const s = self.getString(col) orelse return null;
        return std.mem.eql(u8, s, "t") or std.mem.eql(u8, s, "true") or std.mem.eql(u8, s, "1");
    }

    pub fn getFloat(self: *const Row, col: i32) ?f32 {
        const s = self.getString(col) orelse return null;
        return std.fmt.parseFloat(f32, s) catch null;
    }

    pub fn getFloat64(self: *const Row, col: i32) ?f64 {
        const s = self.getString(col) orelse return null;
        return std.fmt.parseFloat(f64, s) catch null;
    }

    pub fn getBytes(self: *const Row, col: i32) ?[]const u8 {
        return self.getString(col);
    }

    pub fn isNull(self: *const Row, col: i32) bool {
        return PQgetisnull(self.result, self.row_index, col) == 1;
    }

    pub fn getJson(self: *const Row, col: i32, allocator: std.mem.Allocator) !?std.json.Value {
        const s = self.getString(col) orelse return null;
        const parsed = try std.json.parseFromSlice(std.json.Value, allocator, s, .{ .allocate = .alloc_always });
        return parsed.value;
    }

    pub fn fieldName(self: *const Row, col: i32) []const u8 {
        return std.mem.span(PQfname(self.result, col));
    }

    pub fn numCols(self: *const Row) i32 {
        return PQnfields(self.result);
    }
};

pub const Pool = struct {
    connections: []*Connection,
    available: std.ArrayList(*Connection),
    mutex: std.Thread.Mutex,
    cond: std.Thread.Condition,
    allocator: std.mem.Allocator,
    size: usize,

    pub fn init(allocator: std.mem.Allocator, dsn: []const u8, size: usize) !*Pool {
        const self = try allocator.create(Pool);
        errdefer allocator.destroy(self);

        self.connections = try allocator.alloc(*Connection, size);
        errdefer allocator.free(self.connections);

        self.available = std.ArrayList(*Connection).init(allocator);
        errdefer self.available.deinit();
        try self.available.ensureTotalCapacity(size);

        self.mutex = .{};
        self.cond = .{};
        self.allocator = allocator;
        self.size = size;

        var created: usize = 0;
        errdefer {
            for (self.connections[0..created]) |conn| {
                conn.deinit();
                allocator.destroy(conn);
            }
        }

        for (self.connections) |*slot| {
            const conn = try allocator.create(Connection);
            errdefer allocator.destroy(conn);
            conn.* = try Connection.connect(dsn);
            slot.* = conn;
            try self.available.append(conn);
            created += 1;
        }

        return self;
    }

    pub fn deinit(self: *Pool) void {
        for (self.connections) |conn| {
            conn.deinit();
            self.allocator.destroy(conn);
        }
        self.allocator.free(self.connections);
        self.available.deinit();
        self.allocator.destroy(self);
    }

    pub fn acquire(self: *Pool) *Connection {
        self.mutex.lock();
        defer self.mutex.unlock();
        while (self.available.items.len == 0) {
            self.cond.wait(&self.mutex);
        }
        return self.available.pop();
    }

    pub fn release(self: *Pool, conn: *Connection) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        self.available.append(conn) catch {};
        self.cond.signal();
    }
};
