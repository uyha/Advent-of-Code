const std = @import("std");
const assert = std.debug.assert;

const openFile = @import("utils.zig").openFile;

fn partOne(first_col: []i64, second_col: []i64) u64 {
    var result: u64 = 0;

    std.mem.sort(i64, first_col, {}, comptime std.sort.asc(i64));
    std.mem.sort(i64, second_col, {}, comptime std.sort.asc(i64));

    for (first_col, second_col) |f, s| {
        result += @abs(f - s);
    }

    return result;
}

fn partTwo(allocator: std.mem.Allocator, first_col: []i64, second_col: []i64) !u64 {
    var result: u64 = 0;
    var counts = std.AutoHashMap(i64, u32).init(allocator);
    defer counts.deinit();

    for (first_col) |first| {
        if (counts.contains(first)) continue;

        for (second_col) |second| {
            if (first != second) continue;
            try counts.put(first, 1 + (counts.get(first) orelse 0));
        }
    }

    for (first_col) |first| {
        result += @abs(first) * (counts.get(first) orelse 0);
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

    var first_col = std.ArrayList(i64).init(allocator);
    defer first_col.deinit();

    var second_col = std.ArrayList(i64).init(allocator);
    defer second_col.deinit();

    var split = std.mem.split(u8, content, "\n");
    while (split.next()) |line| {
        if (line.len == 0) continue;

        var columns = std.mem.split(u8, line, "   ");
        const first = try std.fmt.parseInt(i64, columns.next().?, 10);
        const second = try std.fmt.parseInt(i64, columns.next().?, 10);

        try first_col.append(first);
        try second_col.append(second);
    }

    std.debug.print("{}\n", .{try partTwo(allocator, first_col.items, second_col.items)});
}
