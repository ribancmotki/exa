const std = @import("std");
const common = @import("../types/common.zig");

pub const HnswIndex = struct {
    dim: usize,
    m: usize,
    ef_construction: usize,
    ef_search: usize,
    nodes: std.ArrayList(HnswNode),
    vectors: std.ArrayList([]f32),
    mutex: std.Thread.RwLock,
    allocator: std.mem.Allocator,
    path: []const u8,

    pub const HnswNode = struct {
        id: []const u8,
        level: u32,
        neighbors: [][]u32,
    };

    pub fn load(path: []const u8, dim: usize, allocator: std.mem.Allocator) !HnswIndex {
        return HnswIndex{
            .dim = dim,
            .m = 16,
            .ef_construction = 200,
            .ef_search = 50,
            .nodes = std.ArrayList(HnswNode).init(allocator),
            .vectors = std.ArrayList([]f32).init(allocator),
            .mutex = std.Thread.RwLock{},
            .allocator = allocator,
            .path = path,
        };
    }

    pub fn deinit(self: *HnswIndex) void {
        for (self.vectors.items) |vec| {
            self.allocator.free(vec);
        }
        self.vectors.deinit();
        self.nodes.deinit();
    }

    pub fn save(self: *HnswIndex, path: []const u8) !void {
        _ = self;
        _ = path;
    }

    pub fn insert(self: *HnswIndex, id: []const u8, vec: []const f32) !void {
        self.mutex.lock();
        defer self.mutex.unlock();

        const vec_copy = try self.allocator.alloc(f32, vec.len);
        @memcpy(vec_copy, vec);
        try self.vectors.append(vec_copy);

        const node = HnswNode{
            .id = try self.allocator.dupe(u8, id),
            .level = 1,
            .neighbors = &.{},
        };
        try self.nodes.append(node);
    }

    pub fn search(self: *HnswIndex, query_vec: []const f32, k: usize, allocator: std.mem.Allocator) ![]common.SearchHit {
        self.mutex.lockShared();
        defer self.mutex.unlockShared();

        if (self.vectors.items.len == 0) {
            return &.{};
        }

        var hits = try allocator.alloc(common.SearchHit, @min(k, self.vectors.items.len));
        errdefer allocator.free(hits);

        var hit_count: usize = 0;

        for (self.vectors.items, 0..) |vec, idx| {
            const score = cosineSimilarity(query_vec, vec);
            const id = if (idx < self.nodes.items.len) self.nodes.items[idx].id else "";
            
            if (hit_count < k) {
                hits[hit_count] = common.SearchHit{
                    .id = id,
                    .score = score,
                };
                hit_count += 1;
            } else {
                var min_idx: usize = 0;
                var min_score = hits[0].score;
                for (1..hit_count) |i| {
                    if (hits[i].score < min_score) {
                        min_score = hits[i].score;
                        min_idx = i;
                    }
                }
                if (score > min_score) {
                    hits[min_idx] = common.SearchHit{
                        .id = id,
                        .score = score,
                    };
                }
            }
        }

        std.mem.sort(common.SearchHit, hits[0..hit_count], {}, struct {
            fn lessThan(_: void, a: common.SearchHit, b: common.SearchHit) bool {
                return a.score > b.score;
            }
        }.lessThan);

        return hits[0..hit_count];
    }
};

pub fn cosineSimilarity(a: []const f32, b: []const f32) f32 {
    if (a.len != b.len) return 0;

    var dot_product: f32 = 0;
    var norm_a: f32 = 0;
    var norm_b: f32 = 0;

    const vector_width = 8;

    var i: usize = 0;
    while (i + vector_width <= a.len) : (i += vector_width) {
        const va: @Vector(vector_width, f32) = a[i..i + vector_width][0..vector_width].*;
        const vb: @Vector(vector_width, f32) = b[i..i + vector_width][0..vector_width].*;

        dot_product += @reduce(.Add, va * vb);
        norm_a += @reduce(.Add, va * va);
        norm_b += @reduce(.Add, vb * vb);
    }

    while (i < a.len) : (i += 1) {
        dot_product += a[i] * b[i];
        norm_a += a[i] * a[i];
        norm_b += b[i] * b[i];
    }

    if (norm_a == 0 or norm_b == 0) return 0;
    return dot_product / (@sqrt(norm_a) * @sqrt(norm_b));
}

test "cosine similarity" {
    const a = [_]f32{ 1, 0, 0 };
    const b = [_]f32{ 1, 0, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 1), cosineSimilarity(&a, &b), 0.001);

    const c = [_]f32{ 1, 0, 0 };
    const d = [_]f32{ 0, 1, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 0), cosineSimilarity(&c, &d), 0.001);

    const e = [_]f32{ 1, 1, 0 };
    const f = [_]f32{ 1, 1, 0 };
    try std.testing.expectApproxEqAbs(@as(f32, 1), cosineSimilarity(&e, &f), 0.001);
}