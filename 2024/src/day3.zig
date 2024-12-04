const std = @import("std");
const assert = std.debug.assert;

const openFile = @import("utils.zig").openFile;

const Parser = struct {
    const Self = @This();

    const State = enum { m, u, l, @"(", @"#1", @"#2", @")" };

    state: State = .m,
    first_num: u64 = 0,
    second_num: u64 = 0,

    pub fn feed(self: *Self, c: u8) bool {
        switch (self.state) {
            .m => {
                if (c == 'm') self.state = .u else self.reset();
            },
            .u => {
                if (c == 'u') self.state = .l else self.reset();
            },
            .l => {
                if (c == 'l') self.state = .@"(" else self.reset();
            },
            .@"(" => {
                if (c == '(') self.state = .@"#1" else self.reset();
            },
            .@"#1" => {
                if ('0' <= c and c <= '9') {
                    self.first_num = (c - '0') + self.first_num * 10;
                } else if (c == ',') {
                    self.state = .@"#2";
                } else {
                    self.reset();
                }
            },
            .@"#2" => {
                if ('0' <= c and c <= '9') {
                    self.second_num = (c - '0') + self.second_num * 10;
                } else if (c == ')') {
                    self.state = .@")";
                    return true;
                } else {
                    self.reset();
                }
            },
            .@")" => {
                self.reset();
                return self.feed(c);
            },
        }

        return false;
    }

    pub fn reset(self: *Self) void {
        self.* = .{};
    }
};

fn partOne(file: std.fs.File) !u64 {
    var result: u64 = 0;
    var parser = Parser{};
    var buffered_reader = std.io.bufferedReader(file.reader());
    var reader = buffered_reader.reader();

    while (reader.readByte()) |c| {
        if (parser.feed(c)) {
            std.debug.print("{}\n", .{parser.first_num * parser.second_num});
            result += parser.first_num * parser.second_num;
        }
    } else |err| {
        switch (err) {
            error.EndOfStream => {},
            else => return err,
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

    std.debug.print("{}\n", .{try partOne(file)});
}
