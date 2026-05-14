const std = @import("std");

test "html parser basic" {
    const parser = @import("../src/contents/parser.zig");
    const html = "<html><head><title>Hello</title></head><body><p>World</p></body></html>";
    const doc = try parser.parseHtml(html, std.testing.allocator);
    defer {
        std.testing.allocator.free(doc.main_text);
        for (doc.links) |l| std.testing.allocator.free(l);
        std.testing.allocator.free(doc.links);
        for (doc.image_links) |l| std.testing.allocator.free(l);
        std.testing.allocator.free(doc.image_links);
        if (doc.title) |t| std.testing.allocator.free(t);
    }
    try std.testing.expect(doc.title != null);
}

test "highlights extract empty" {
    const highlights = @import("../src/contents/highlights.zig");
    const result = try highlights.extract("", null, 1000, std.testing.allocator);
    defer {
        for (result) |r| std.testing.allocator.free(r);
        std.testing.allocator.free(result);
    }
    try std.testing.expect(result.len == 0);
}
