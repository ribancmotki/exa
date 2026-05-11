const std = @import("std");

pub fn GenericPool(comptime T: type) type {
    return struct {
        const Self = @This();
        const Item = struct {
            value: T,
            in_use: bool,
        };

        items: []Item,
        mutex: std.Thread.Mutex,
        cond: std.Thread.Condition,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, size: usize, initFn: anytype, initArg: anytype) !Self {
            var items = try allocator.alloc(Item, size);
            errdefer allocator.free(items);
            var created: usize = 0;
            errdefer {
                var i: usize = 0;
                while (i < created) : (i += 1) {
                    if (@hasDecl(T, "deinit")) items[i].value.deinit();
                }
            }
            for (items) |*item| {
                item.value = try initFn(initArg);
                item.in_use = false;
                created += 1;
            }
            return Self{
                .items = items,
                .mutex = .{},
                .cond = .{},
                .allocator = allocator,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.items) |*item| {
                if (@hasDecl(T, "deinit")) item.value.deinit();
            }
            self.allocator.free(self.items);
        }

        pub fn acquire(self: *Self) *T {
            self.mutex.lock();
            defer self.mutex.unlock();
            while (true) {
                for (self.items) |*item| {
                    if (!item.in_use) {
                        item.in_use = true;
                        return &item.value;
                    }
                }
                self.cond.wait(&self.mutex);
            }
        }

        pub fn release(self: *Self, ptr: *T) void {
            self.mutex.lock();
            defer self.mutex.unlock();
            for (self.items) |*item| {
                if (&item.value == ptr) {
                    item.in_use = false;
                    self.cond.signal();
                    return;
                }
            }
        }
    };
}
