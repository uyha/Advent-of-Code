const std = @import("std");
const assert = std.debug.assert;
const openFile = @import("utils.zig").openFile;

const Coord = struct {
    y: usize,
    x: usize,
};

const Map = struct {
    const Self = @This();
    source: []const u8,
    width: usize,

    pub fn toCoord(self: *const Self, index: usize) Coord {
        return .{
            .y = index / self.width,
            .x = index % self.width,
        };
    }

    pub fn toIndex(self: *const Self, coord: Coord) usize {
        return coord.x + coord.y * self.width;
    }

    pub fn get(self: *const Self, coord: Coord) u8 {
        return self.source[self.toIndex(coord)];
    }

    pub fn inBound(self: *const Self, coord: Coord) bool {
        return self.toIndex(coord) < self.source.len;
    }
};

const Content = struct {
    const Self = @This();

    content: std.ArrayList(u8),
    map: Map,

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

        var result: Self = .{ .content = content, .map = undefined };

        result.map = .{ .source = result.content.items, .width = width.? };

        return result;
    }

    pub fn deinit(self: *const Self) void {
        self.content.deinit();
    }
};

const Guard = struct {
    const Self = @This();
    const Direction = enum { up, right, down, left };

    position: Coord,
    facing: Direction = .up,

    pub fn turn(self: *Self) void {
        switch (self.facing) {
            .up => self.facing = .right,
            .right => self.facing = .down,
            .down => self.facing = .left,
            .left => self.facing = .up,
        }
    }

    pub fn aheadCoord(self: *const Self) ?Coord {
        var result = self.position;
        switch (self.facing) {
            .up => if (result.y == 0) {
                return null;
            } else {
                result.y -= 1;
            },
            .right => result.x += 1,
            .down => result.y += 1,
            .left => if (result.x == 0) {
                return null;
            } else {
                result.x -= 1;
            },
        }

        return result;
    }

    pub fn moveAhead(self: *Self) void {
        switch (self.facing) {
            .up => self.position.y -= 1,
            .right => self.position.x += 1,
            .down => self.position.y += 1,
            .left => self.position.x -= 1,
        }
    }
};

fn Set(T: type) type {
    return std.AutoArrayHashMap(T, void);
}

fn partOne(allocator: std.mem.Allocator, file: std.fs.File) !u64 {
    const content = try Content.parse(allocator, file);
    defer content.deinit();

    const map = content.map;

    const start = map.toCoord(
        std.mem.indexOfScalar(u8, content.content.items, '^').?,
    );

    var guard = Guard{ .position = start };
    var touched_points = Set(Coord).init(allocator);
    defer touched_points.deinit();

    try touched_points.put(guard.position, {});

    while (guard.aheadCoord()) |coord| {
        if (!map.inBound(coord)) {
            break;
        }
        if (map.get(coord) == '#') {
            guard.turn();
            continue;
        }
        guard.moveAhead();
        try touched_points.put(guard.position, {});
    }

    return touched_points.keys().len;
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

    std.debug.print("{}\n", .{try partOne(allocator, file)});
}
