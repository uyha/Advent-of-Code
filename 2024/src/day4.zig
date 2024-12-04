const std = @import("std");
const assert = std.debug.assert;
const openFile = @import("utils.zig").openFile;

fn OctoSpan(comptime length: u16) type {
    const Generator = struct {
        const Self = @This();

        const Direction = enum { E, SE, S, SW, W, NW, N, NE, ended };

        direction: Direction = .E,
        source: []const u8,
        items: [length]u8 = undefined,
        start: usize,
        height: usize,
        width: usize,

        fn get(self: *const Self, x: usize, y: usize) u8 {
            return self.source[x + y * self.width];
        }

        pub fn arm(self: *Self) ?[]const u8 {
            const x = self.start % self.width;
            const y = self.start / self.width;

            while (self.direction != .ended) {
                defer self.direction = @enumFromInt(@intFromEnum(self.direction) + 1);

                switch (self.direction) {
                    .E => {
                        if (self.width - x < length) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x + i, y);
                        }

                        return &self.items;
                    },
                    .SE => {
                        if ((self.width - x < length) or (self.height - y < length)) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x + i, y + i);
                        }

                        return &self.items;
                    },
                    .S => {
                        if (self.height - y < length) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x, y + i);
                        }
                        return &self.items;
                    },
                    .SW => {
                        if ((x < length - 1) or (self.height - y < length)) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x - i, y + i);
                        }
                        return &self.items;
                    },
                    .W => {
                        if (x < length - 1) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x - i, y);
                        }
                        return &self.items;
                    },
                    .NW => {
                        if ((x < length - 1) or (y < length - 1)) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x - i, y - i);
                        }
                        return &self.items;
                    },
                    .N => {
                        if ((y < length - 1)) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x, y - i);
                        }
                        return &self.items;
                    },
                    .NE => {
                        if ((self.width - x < length) or (y < length - 1)) {
                            continue;
                        }

                        for (0..length) |i| {
                            self.items[i] = self.get(x + i, y - i);
                        }
                        return &self.items;
                    },
                    .ended => return null,
                }
            }

            return null;
        }
    };

    return struct {
        const Self = @This();

        source: []const u8,
        width: usize,

        pub fn init(source: []const u8, width: usize) Self {
            return .{
                .source = source,
                .width = width,
            };
        }

        pub fn arms(self: *const Self, start: usize) Generator {
            return .{
                .source = self.source,
                .start = start,
                .height = self.source.len / self.width,
                .width = self.width,
            };
        }
    };
}

const Content = struct {
    const Self = @This();

    content: std.ArrayList(u8),
    width: usize,

    pub fn parse(allocator: std.mem.Allocator, file: std.fs.File) std.mem.Allocator.Error!Self {
        const file_reader = file.reader();
        var buffered_reader = std.io.bufferedReader(file_reader);
        var reader = buffered_reader.reader();

        var content = std.ArrayList(u8).init(allocator);

        var width: ?usize = null;
        var line_legnth: usize = 0;
        while (reader.readByte()) |c| {
            if (c == '\n') {
                if (width) |w| {
                    assert(w == line_legnth);
                } else {
                    width = line_legnth;
                }
                line_legnth = 0;
            } else {
                try content.append(c);
                line_legnth += 1;
            }
        } else |_| {}

        return .{ .content = content, .width = width.? };
    }

    pub fn deinit(self: *const Self) void {
        self.content.deinit();
    }
};

fn partOne(allocator: std.mem.Allocator, file: std.fs.File) !u64 {
    const xmas = "XMAS";

    const content = try Content.parse(allocator, file);
    defer content.deinit();

    const items = content.content.items;
    const width = content.width;

    const span = OctoSpan(xmas.len).init(items, width);

    var result: u64 = 0;
    for (items, 0..) |c, i| {
        if (c != 'X') {
            continue;
        }

        var generator = span.arms(i);

        while (generator.arm()) |arm| {
            if (std.mem.eql(u8, arm, xmas)) {
                result += 1;
            }
        }
    }

    return result;
}

fn square_span(comptime side: u16, source: []const u8, width: usize, start: usize) ?[side * side]u8 {
    const height = source.len / width;
    const x = start % width;
    const y = start / width;

    if ((width - x < side) or (height - y < side)) {
        return null;
    }

    var result: [side * side]u8 = undefined;

    for (0..side) |y_span| {
        for (0..side) |x_span| {
            result[x_span + y_span * side] = source[(x + x_span) + (y + y_span) * width];
        }
    }

    return result;
}

fn partTwo(allocator: std.mem.Allocator, file: std.fs.File) !u64 {
    const content = try Content.parse(allocator, file);
    defer content.deinit();

    const items = content.content.items;
    const width = content.width;

    var result: u64 = 0;
    for (items, 0..) |c, i| {
        if (c != 'M' and c != 'S') {
            continue;
        }

        if (square_span(3, items, width, i)) |span| {
            if (span[4] != 'A') {
                continue;
            }
            if ((span[0] == 'M') and
                (span[2] == 'S') and
                (span[6] == 'M') and
                (span[8] == 'S'))
            {
                result += 1;
            }
            if ((span[0] == 'M') and
                (span[2] == 'M') and
                (span[6] == 'S') and
                (span[8] == 'S'))
            {
                result += 1;
            }
            if ((span[0] == 'S') and
                (span[2] == 'M') and
                (span[6] == 'S') and
                (span[8] == 'M'))
            {
                result += 1;
            }
            if ((span[0] == 'S') and
                (span[2] == 'S') and
                (span[6] == 'M') and
                (span[8] == 'M'))
            {
                result += 1;
            }
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

    std.debug.print("{}\n", .{try partTwo(allocator, file)});
}
