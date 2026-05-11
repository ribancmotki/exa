const std = @import("std");

pub const ErrorTag = enum {
    INVALID_API_KEY,
    NO_MORE_CREDITS,
    API_KEY_BUDGET_EXCEEDED,
    TEAM_BUDGET_EXCEEDED,
    ACCESS_DENIED,
    FEATURE_DISABLED,
    ROBOTS_FILTER_FAILED,
    PROHIBITED_CONTENT,
    CONTENT_FILTER_ERROR,
    INVALID_REQUEST_BODY,
    INVALID_REQUEST,
    INVALID_URLS,
    INVALID_NUM_RESULTS,
    INVALID_FLAGS,
    INVALID_JSON_SCHEMA,
    NUM_RESULTS_EXCEEDED,
    NO_CONTENT_FOUND,
    FETCH_DOCUMENT_ERROR,
    UNABLE_TO_GENERATE_RESPONSE,
    DEFAULT_ERROR,
    INTERNAL_ERROR,
};

pub const AppError = struct {
    tag: ErrorTag,
    message: []const u8,
    request_id: ?[]const u8,

    pub fn httpStatus(self: *const AppError) u16 {
        return switch (self.tag) {
            .INVALID_API_KEY => 401,
            .NO_MORE_CREDITS, .API_KEY_BUDGET_EXCEEDED, .TEAM_BUDGET_EXCEEDED => 402,
            .ACCESS_DENIED, .FEATURE_DISABLED => 403,
            .INVALID_REQUEST_BODY, .INVALID_REQUEST, .INVALID_URLS, .INVALID_NUM_RESULTS,
            .INVALID_FLAGS, .INVALID_JSON_SCHEMA, .NUM_RESULTS_EXCEEDED, .CONTENT_FILTER_ERROR => 400,
            .ROBOTS_FILTER_FAILED, .PROHIBITED_CONTENT => 451,
            .NO_CONTENT_FOUND => 404,
            .FETCH_DOCUMENT_ERROR, .UNABLE_TO_GENERATE_RESPONSE => 422,
            .DEFAULT_ERROR, .INTERNAL_ERROR => 500,
        };
    }

    pub fn toJson(self: *const AppError, allocator: std.mem.Allocator) ![]const u8 {
        var buf = std.ArrayList(u8).init(allocator);
        errdefer buf.deinit();
        const writer = buf.writer();
        try writer.print("{{\"requestId\":\"{s}\",\"error\":\"{s}\",\"tag\":\"{s}\"}}", .{
            self.request_id orelse "",
            self.message,
            @tagName(self.tag),
        });
        return buf.toOwnedSlice();
    }
};

pub const AppErrorSet = error{
    InvalidApiKey,
    InsufficientCredits,
    ApiKeyBudgetExceeded,
    TeamBudgetExceeded,
    AccessDenied,
    FeatureDisabled,
    RobotsFilterFailed,
    ProhibitedContent,
    ContentFilterError,
    InvalidRequestBody,
    InvalidRequest,
    InvalidUrls,
    InvalidNumResults,
    InvalidFlags,
    InvalidJsonSchema,
    NumResultsExceeded,
    NoContentFound,
    FetchDocumentError,
    UnableToGenerateResponse,
    DefaultError,
    InternalError,
    DatabaseError,
    CacheError,
    NetworkError,
    Timeout,
    NotFound,
    AlreadyExists,
    ParseError,
    MissingRequiredEnvVar,
    ConfigParseError,
    ConnectionFailed,
    QueryFailed,
    NoRows,
    InvalidUuidLength,
    InvalidUuidFormat,
    InvalidHexCharacter,
    InvalidHexLength,
    InvalidUrl,
    InvalidResponse,
    WriteFailed,
    ReadFailed,
    NoAddressesFound,
    CompressionError,
};

pub fn toAppError(err: anyerror, request_id: ?[]const u8) AppError {
    const tag: ErrorTag = switch (err) {
        error.InvalidApiKey => .INVALID_API_KEY,
        error.InsufficientCredits => .NO_MORE_CREDITS,
        error.ApiKeyBudgetExceeded => .API_KEY_BUDGET_EXCEEDED,
        error.TeamBudgetExceeded => .TEAM_BUDGET_EXCEEDED,
        error.AccessDenied => .ACCESS_DENIED,
        error.FeatureDisabled => .FEATURE_DISABLED,
        error.RobotsFilterFailed => .ROBOTS_FILTER_FAILED,
        error.ProhibitedContent => .PROHIBITED_CONTENT,
        error.ContentFilterError => .CONTENT_FILTER_ERROR,
        error.InvalidRequestBody, error.ParseError => .INVALID_REQUEST_BODY,
        error.InvalidRequest => .INVALID_REQUEST,
        error.InvalidUrls => .INVALID_URLS,
        error.InvalidNumResults => .INVALID_NUM_RESULTS,
        error.InvalidFlags => .INVALID_FLAGS,
        error.InvalidJsonSchema => .INVALID_JSON_SCHEMA,
        error.NumResultsExceeded => .NUM_RESULTS_EXCEEDED,
        error.NoContentFound, error.NotFound, error.NoRows => .NO_CONTENT_FOUND,
        error.FetchDocumentError, error.NetworkError, error.Timeout => .FETCH_DOCUMENT_ERROR,
        error.UnableToGenerateResponse => .UNABLE_TO_GENERATE_RESPONSE,
        else => .INTERNAL_ERROR,
    };

    const message: []const u8 = switch (err) {
        error.InvalidApiKey => "Invalid or revoked API key",
        error.InsufficientCredits => "Insufficient credits",
        error.ApiKeyBudgetExceeded => "API key budget exceeded",
        error.TeamBudgetExceeded => "Team budget exceeded",
        error.AccessDenied => "Access denied",
        error.FeatureDisabled => "Feature disabled",
        error.RobotsFilterFailed => "Blocked by robots.txt",
        error.ProhibitedContent => "Prohibited content",
        error.ContentFilterError => "Content filter error",
        error.InvalidRequestBody, error.ParseError => "Invalid request body",
        error.InvalidRequest => "Invalid request",
        error.InvalidUrls => "Invalid URLs",
        error.InvalidNumResults => "Invalid number of results",
        error.InvalidFlags => "Invalid flags",
        error.InvalidJsonSchema => "Invalid JSON schema",
        error.NumResultsExceeded => "Number of results exceeded",
        error.NoContentFound, error.NotFound, error.NoRows => "Not found",
        error.NetworkError => "Network error",
        error.Timeout => "Request timeout",
        error.FetchDocumentError => "Failed to fetch document",
        error.UnableToGenerateResponse => "Unable to generate response",
        error.DatabaseError => "Database error",
        error.CacheError => "Cache error",
        else => "Internal server error",
    };

    return AppError{
        .tag = tag,
        .message = message,
        .request_id = request_id,
    };
}
