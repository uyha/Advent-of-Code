const std = @import("std");
const File = std.fs.File;
const assert = std.debug.assert;
const openFile = @import("utils.zig").openFile;

const Content = struct {
    const Self = @This();

    fn Set(comptime T: type) type {
        return std.AutoHashMap(T, void);
    }

    const Rules = std.AutoHashMap(u64, Set(u64));
    const Updates = std.ArrayList(std.ArrayList(u64));

    arena: std.heap.ArenaAllocator,
    rules: Rules,
    updates: Updates,

    pub fn parse(child_allocator: std.mem.Allocator, file: File) !Self {
        var result: Self = .{
            .arena = std.heap.ArenaAllocator.init(child_allocator),
            .rules = undefined,
            .updates = undefined,
        };
        result.rules = Rules.init(result.arena.allocator());
        result.updates = Updates.init(result.arena.allocator());

        var buffer = std.ArrayList(u8).init(child_allocator);
        defer buffer.deinit();

        const stat = try file.stat();
        try buffer.resize(stat.size);

        const bytes_read = try file.readAll(buffer.items);
        assert(bytes_read == stat.size);

        var section_iter = std.mem.tokenizeSequence(u8, buffer.items, "\n\n");

        const rules = section_iter.next().?;
        const updates = section_iter.next().?;
        assert(section_iter.next() == null);

        var rules_iter = std.mem.tokenizeScalar(u8, rules, '\n');
        while (rules_iter.next()) |rule| {
            var page_iter = std.mem.tokenizeScalar(u8, rule, '|');

            const first = try std.fmt.parseInt(u64, page_iter.next().?, 10);
            const second = try std.fmt.parseInt(u64, page_iter.next().?, 10);

            if (!result.rules.contains(first)) {
                try result.rules.put(first, Set(u64).init(result.arena.allocator()));
            }
            var rule_pages = result.rules.getPtr(first).?;
            try rule_pages.put(second, {});
        }

        var updates_iter = std.mem.tokenizeScalar(u8, updates, '\n');
        while (updates_iter.next()) |update| {
            var pages = std.ArrayList(u64).init(result.arena.allocator());
            var page_iter = std.mem.tokenizeScalar(u8, update, ',');

            while (page_iter.next()) |page| {
                try pages.append(try std.fmt.parseInt(u64, page, 10));
            }

            try result.updates.append(pages);
        }

        return result;
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }
};

fn partOne(allocator: std.mem.Allocator, file: File) !u64 {
    var content = try Content.parse(allocator, file);
    defer content.deinit();

    var result: u64 = 0;

    update: for (content.updates.items) |*update| {
        for (update.items, 0..) |current_page, index| {
            for (update.items[index + 1 ..]) |next_page| {
                if (content.rules.get(next_page)) |rule| {
                    if (rule.contains(current_page)) {
                        continue :update;
                    }
                }
            }
        }
        result += update.items[update.items.len / 2];
    }

    return result;
}

fn rotate(comptime T: type, source: []T, first_: usize, middle_: usize, last: usize) usize {
    var first = first_;
    var middle = middle_;

    while (true) {
        if (first == middle) {
            return last;
        }
        if (middle == last) {
            return first;
        }

        var write = first;
        var next_read = first;
        var read = middle;

        while (read < last) {
            defer {
                write += 1;
                read += 1;
            }

            if (write == next_read) {
                next_read = read;
            }

            std.mem.swap(T, &source[write], &source[read]);
        }

        first = write;
        middle = next_read;
    }
}

fn partTwo(allocator: std.mem.Allocator, file: File) !u64 {
    var content = try Content.parse(allocator, file);
    defer content.deinit();

    var result: u64 = 0;

    update: for (content.updates.items) |*update| {
        var correct = true;

        check: for (update.items, 0..) |current_page, index| {
            for (update.items[index + 1 ..]) |next_page| {
                if (content.rules.get(next_page)) |rule| {
                    if (rule.contains(current_page)) {
                        correct = false;
                        break :check;
                    }
                }
            }
        }

        if (correct) {
            continue :update;
        }

        for (0..update.items.len - 1) |current| {
            for (current + 1..update.items.len) |next| {
                const current_page = update.items[current];
                const next_page = update.items[next];

                if (content.rules.get(next_page)) |rule| {
                    if (rule.contains(current_page)) {
                        _ = rotate(u64, update.items, current, next, next + 1);
                    }
                }
            }
        }

        result += update.items[update.items.len / 2];
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
