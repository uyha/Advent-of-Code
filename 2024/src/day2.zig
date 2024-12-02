const std = @import("std");
const assert = std.debug.assert;

const openFile = @import("utils.zig").openFile;

const ReportGenerator = struct {
    const Self = @This();
    const Allocator = std.mem.Allocator;

    line_iter: std.mem.TokenIterator(u8, .scalar),
    allocator: Allocator,

    pub fn init(allocator: Allocator, content: []const u8) Self {
        return Self{
            .allocator = allocator,
            .line_iter = std.mem.tokenizeScalar(u8, content, '\n'),
        };
    }

    pub fn next(self: *Self) Allocator.Error!?std.ArrayList(u32) {
        const line = self.line_iter.next() orelse return null;

        var result = std.ArrayList(u32).init(self.allocator);
        var levels = std.mem.tokenizeScalar(u8, line, ' ');

        while (levels.next()) |level| {
            try result.append(std.fmt.parseInt(u32, level, 10) catch @panic("Malformed input"));
        }

        return result;
    }
};

fn safe(levels: []const u32) bool {
    if (levels.len == 1) {
        return false;
    }

    var increase: ?bool = null;

    for (levels[0 .. levels.len - 1], levels[1..]) |current, next| {
        const diff = if (current > next) current - next else next - current;
        // No need to check current == next since this condition already implies
        // that
        if (diff < 1 or diff > 3) {
            return false;
        }

        if (increase) |inc| {
            if (inc != (current < next)) {
                return false;
            }
        } else {
            increase = current < next;
        }
    }

    return true;
}

fn partOne(generator: *ReportGenerator) !u32 {
    var result: u32 = 0;

    while (try generator.next()) |levels| {
        defer levels.deinit();

        if (safe(levels.items)) {
            result += 1;
        }
    }

    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer assert(!gpa.detectLeaks());

    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        try std.io.getStdErr().writer().print("Expected path to the data\n", .{});
    }

    const file = try openFile(args[1], .{});
    defer file.close();

    const file_stat = try file.stat();
    const content = try file.readToEndAlloc(allocator, file_stat.size);
    defer allocator.free(content);

    var generator = ReportGenerator.init(allocator, content);
    std.debug.print("{}\n", .{try partOne(&generator)});
}
