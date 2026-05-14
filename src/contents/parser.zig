const std = @import("std");

pub const ParsedDocument = struct {
    title: ?[]const u8,
    author: ?[]const u8,
    published_at: ?[]const u8,
    main_text: []const u8,
    links: [][]const u8,
    image_links: [][]const u8,
};

pub fn parseHtml(html: []const u8, allocator: std.mem.Allocator) !ParsedDocument {
    var links = std.ArrayList([]const u8).init(allocator);
    var image_links = std.ArrayList([]const u8).init(allocator);
    
    var title: ?[]const u8 = null;
    var author: ?[]const u8 = null;
    var published_at: ?[]const u8 = null;
    
    var text = std.ArrayList(u8).init(allocator);
    errdefer text.deinit();
    
    var i: usize = 0;
    while (i < html.len) : (i += 1) {
        if (html[i] == '<') {
            const tag_end = std.mem.indexOfScalarPos(u8, html, i + 1, '>') orelse continue;
            const tag = html[i..tag_end + 1];
            
            if (std.ascii.startsWithIgnoreCase(tag, "<title>")) {
                const content_start = i + 7;
                const content_end = std.mem.indexOfPos(u8, html, content_start, "</title>") orelse
                    std.mem.indexOfPos(u8, html, content_start, "</TITLE>") orelse continue;
                const content = std.mem.trim(u8, html[content_start..content_end], " \t\n\r");
                title = try allocator.dupe(u8, content);
            } else if (std.mem.indexOf(u8, tag, "author") != null or
                std.mem.indexOf(u8, tag, "Author") != null) {
                if (std.ascii.startsWithIgnoreCase(tag, "<meta")) {
                    if (std.mem.indexOfScalar(u8, tag, '"')) |_| {
                        const attr_start = std.mem.indexOfScalarPos(u8, tag, 0, '"').? + 1;
                        const attr_end = std.mem.indexOfScalarPos(u8, tag, attr_start, '"') orelse continue;
                        author = try allocator.dupe(u8, tag[attr_start..attr_end]);
                    }
                }
            } else if (std.mem.indexOf(u8, tag, "published_time") != null or
                std.mem.indexOf(u8, tag, "published_at") != null) {
                if (std.mem.indexOfScalarPos(u8, tag, 0, '"')) |_| {
                    const attr_start = std.mem.indexOfScalarPos(u8, tag, 0, '"').? + 1;
                    const attr_end = std.mem.indexOfScalarPos(u8, tag, attr_start, '"') orelse continue;
                    published_at = try allocator.dupe(u8, tag[attr_start..attr_end]);
                }
            } else if (std.ascii.startsWithIgnoreCase(tag, "<a ")) {
                if (std.mem.indexOf(u8, tag, "href=\"")) |href_start| {
                    const url_start = href_start + 6;
                    const url_end = std.mem.indexOfScalarPos(u8, tag, url_start, '"') orelse continue;
                    const url = try allocator.dupe(u8, tag[url_start..url_end]);
                    try links.append(url);
                    
                    const text_start = tag_end + 1;
                    const text_end = std.mem.indexOfPos(u8, html, text_start, "</a>") orelse
                    std.mem.indexOfPos(u8, html, text_start, "</A>") orelse html.len;
                    const link_text = std.mem.trim(u8, html[text_start..text_end], " \t\n\r");
                    
                    try text.writer().print("[{s}]({s}) ", .{ link_text, url });
                }
            } else if (std.ascii.startsWithIgnoreCase(tag, "<img ")) {
                if (std.mem.indexOf(u8, tag, "src=\"")) |src_start| {
                    const url_start = src_start + 5;
                    const url_end = std.mem.indexOfScalarPos(u8, tag, url_start, '"') orelse continue;
                    const url = try allocator.dupe(u8, tag[url_start..url_end]);
                    try image_links.append(url);
                }
            } else if (std.ascii.startsWithIgnoreCase(tag, "<h1") or
                std.ascii.startsWithIgnoreCase(tag, "<h2") or
                std.ascii.startsWithIgnoreCase(tag, "<h3")) {
                try text.append('\n');
            } else if (std.ascii.startsWithIgnoreCase(tag, "<p") or
                std.ascii.startsWithIgnoreCase(tag, "<li")) {
                try text.append('\n');
            }
            
            i = tag_end;
        } else {
            try text.append(html[i]);
        }
    }
    
    const cleaned_text = try cleanText(text.items, allocator);
    
    return ParsedDocument{
        .title = title,
        .author = author,
        .published_at = published_at,
        .main_text = cleaned_text,
        .links = try links.toOwnedSlice(),
        .image_links = try image_links.toOwnedSlice(),
    };
}

fn cleanText(text: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();
    
    var prev_was_space = false;
    for (text) |c| {
        if (c == ' ' or c == '\t' or c == '\n' or c == '\r') {
            if (!prev_was_space) {
                try result.append(' ');
                prev_was_space = true;
            }
        } else {
            try result.append(c);
            prev_was_space = false;
        }
    }
    
    return try result.toOwnedSlice();
}

test "html parsing" {
    const html = "<html><head><title>Test</title></head><body><p>Hello World</p><a href=\"http://example.com\">Link</a></body></html>";
    const doc = try parseHtml(html, std.testing.allocator);
    defer {
        std.testing.allocator.free(doc.main_text);
        for (doc.links) |l| std.testing.allocator.free(l);
        for (doc.image_links) |l| std.testing.allocator.free(l);
    }
    
    try std.testing.expectEqualStrings("Test", doc.title.?);
}