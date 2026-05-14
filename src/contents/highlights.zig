const std = @import("std");

pub fn extract(
    text: []const u8,
    query: ?[]const u8,
    max_chars: usize,
    allocator: std.mem.Allocator,
) ![][]const u8 {
    const sentences = try tokenizeSentences(text, allocator);
    defer {
        for (sentences) |s| allocator.free(s);
        allocator.free(sentences);
    }
    
    const ScoredSentence = struct { text: []const u8, score: f32 };
    var scored_sentences = try allocator.alloc(ScoredSentence, sentences.len);
    defer allocator.free(scored_sentences);
    
    for (sentences, 0..) |sentence, i| {
        const s = if (query) |q|
            try scoreSentence(sentence, q, allocator)
        else
            @as(f32, @floatFromInt(sentences.len - i)) * @as(f32, @floatFromInt(sentence.len));
        
        scored_sentences[i] = .{ .text = sentence, .score = s };
    }
    
    std.mem.sort(ScoredSentence, scored_sentences, {}, struct {
        fn lessThan(_: void, a: ScoredSentence, b: ScoredSentence) bool {
            return a.score > b.score;
        }
    }.lessThan);
    
    var result = std.ArrayList([]const u8).init(allocator);
    var total_len: usize = 0;
    
    for (scored_sentences) |s| {
        if (total_len + s.text.len + 2 > max_chars) break;
        try result.append(try allocator.dupe(u8, s.text));
        total_len += s.text.len + 2;
    }
    
    return try result.toOwnedSlice();
}

fn tokenizeSentences(text: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var sentences = std.ArrayList([]const u8).init(allocator);
    errdefer sentences.deinit();
    
    var start: usize = 0;
    for (text, 0..) |c, i| {
        if (c == '.' or c == '!' or c == '?') {
            if (i + 1 < text.len and (text[i + 1] == ' ' or text[i + 1] == '\n')) {
                const sentence = std.mem.trim(u8, text[start..i], " \t\n\r");
                if (sentence.len > 10) {
                    try sentences.append(try allocator.dupe(u8, sentence));
                }
                start = i + 1;
            }
        }
    }
    
    return try sentences.toOwnedSlice();
}

fn scoreSentence(sentence: []const u8, query: []const u8, allocator: std.mem.Allocator) !f32 {
    const sentence_tokens = try tokenize(sentence, allocator);
    defer {
        for (sentence_tokens) |t| allocator.free(t);
        allocator.free(sentence_tokens);
    }
    
    const query_tokens = try tokenize(query, allocator);
    defer {
        for (query_tokens) |t| allocator.free(t);
        allocator.free(query_tokens);
    }
    
    var overlap: f32 = 0;
    for (sentence_tokens) |st| {
        for (query_tokens) |qt| {
            if (std.mem.eql(u8, st, qt)) {
                overlap += 1;
                break;
            }
        }
    }
    
    if (query_tokens.len == 0) return 0;
    return overlap / @as(f32, @floatFromInt(query_tokens.len));
}

fn tokenize(text: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var tokens = std.ArrayList([]const u8).init(allocator);
    errdefer tokens.deinit();
    
    var word_start: ?usize = null;
    for (text, 0..) |c, i| {
        if (std.ascii.isAlphanumeric(c)) {
            if (word_start == null) word_start = i;
        } else {
            if (word_start) |start| {
                const word = text[start..i];
                try tokens.append(try std.ascii.allocLowerString(allocator, word));
                word_start = null;
            }
        }
    }
    
    if (word_start) |start| {
        const word = text[start..];
        try tokens.append(try std.ascii.allocLowerString(allocator, word));
    }
    
    return try tokens.toOwnedSlice();
}

pub fn score(text: []const u8, query: []const u8, allocator: std.mem.Allocator) !f32 {
    return try scoreSentence(text, query, allocator);
}