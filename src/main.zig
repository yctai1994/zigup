const std = @import("std");
const Io = std.Io;

const zigup = @import("zigup");

/// Returns owned response bytes that remain valid after this function returns.
/// The caller frees them with allocator.free; the allocator's backing storage
/// must remain valid until then. Borrows io and environ for this call.
pub fn fetchIndex(
    allocator: std.mem.Allocator,
    io: std.Io,
    environ: *const std.process.Environ.Map,
) ![]u8 {
    // Local arena bookkeeping owns allocator-backed proxy objects, hostnames,
    // and optional authentication strings when proxy settings are present.
    var proxy_arena = std.heap.ArenaAllocator.init(allocator);
    defer proxy_arena.deinit();

    // The local client owns allocator-backed connection/request resources and
    // borrows proxy data from proxy_arena. Defers run in reverse order, so the
    // client is destroyed before the arena releases the borrowed proxy data.
    var client: std.http.Client = .{ .allocator = allocator, .io = io };
    defer client.deinit();
    try client.initDefaultProxies(proxy_arena.allocator(), environ);

    // First use of a buffered HTTP response; revisit reuse at a second occurrence.
    // This local writer owns a separate allocator-backed byte buffer.
    // On failure, deinit releases any bytes still owned by the writer.
    var body: std.Io.Writer.Allocating = .init(allocator);
    defer body.deinit();
    const result = try client.fetch(.{
        .location = .{ .url = "https://ziglang.org/download/index.json" },
        .response_writer = &body.writer,
    });
    if (result.status != .ok) return error.UnexpectedHttpStatus;
    // On success, transfer the buffer to the caller and empty the writer.
    // The deferred body.deinit() leaves the returned bytes valid.
    return body.toOwnedSlice();
}

pub fn main(init: std.process.Init) !void {
    // Prints to stderr, unbuffered, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // This is appropriate for anything that lives as long as the process.
    const arena: std.mem.Allocator = init.arena.allocator();

    // Accessing command line arguments:
    const args = try init.minimal.args.toSlice(arena);
    for (args) |arg| {
        std.log.info("arg: {s}", .{arg});
    }

    // In order to do I/O operations need an `Io` instance.
    const io = init.io;

    // Stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;

    try zigup.printAnotherMessage(stdout_writer);

    try stdout_writer.flush(); // Don't forget to flush!
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    try std.testing.fuzz({}, testOne, .{});
}

fn testOne(context: void, smith: *std.testing.Smith) !void {
    _ = context;
    // Try running `zig build test --fuzz` and see if it manages to fail this test case!

    const gpa = std.testing.allocator;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(gpa);
    while (!smith.eos()) switch (smith.value(enum { add_data, dup_data })) {
        .add_data => {
            const slice = try list.addManyAsSlice(gpa, smith.value(u4));
            smith.bytes(slice);
        },
        .dup_data => {
            if (list.items.len == 0) continue;
            if (list.items.len > std.math.maxInt(u32)) return error.SkipZigTest;
            const len = smith.valueRangeAtMost(u32, 1, @min(32, list.items.len));
            const off = smith.valueRangeAtMost(u32, 0, @intCast(list.items.len - len));
            try list.appendSlice(gpa, list.items[off..][0..len]);
            try std.testing.expectEqualSlices(
                u8,
                list.items[off..][0..len],
                list.items[list.items.len - len ..],
            );
        },
    };
}
