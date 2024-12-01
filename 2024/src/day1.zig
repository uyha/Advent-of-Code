const std = @import("std");

fn openFile(path: []const u8, flags: std.fs.File.OpenFlags) std.fs.File.OpenError!std.fs.File {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.openFileAbsolute(path, flags);
    }
    return std.fs.cwd().openFile(path, flags);
}

fn partOne(first_col: []i64, second_col: []i64) u64 {
    var result: u64 = 0;

    std.mem.sort(i64, first_col, {}, comptime std.sort.asc(i64));
    std.mem.sort(i64, second_col, {}, comptime std.sort.asc(i64));

    for (first_col, second_col) |f, s| {
        result += @abs(f - s);
    }

    return result;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();

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

    std.debug.print("{}\n", .{partOne(first_col.items, second_col.items)});
}
