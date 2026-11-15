const std = @import("std");
const fetchIndex = @import("zigup_main").fetchIndex;

test "fetch official index using current proxy environment" {
    const allocator = std.testing.allocator;
    var environ = try std.testing.environ.createMap(allocator);
    defer environ.deinit();
    const body = try fetchIndex(allocator, std.testing.io, &environ);
    defer allocator.free(body);

    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, body, .{});
    defer parsed.deinit();
    try std.testing.expect(parsed.value == .object);
    const master = parsed.value.object.get("master") orelse return error.MissingMaster;
    try std.testing.expect(master == .object);
    const version = master.object.get("version") orelse return error.MissingVersion;
    try std.testing.expect(version == .string);
    try std.testing.expect(version.string.len > 0);
    std.debug.print("Fetched {d} bytes; master version: {s}\n", .{ body.len, version.string });
}
