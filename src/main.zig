const std = @import("std");
const vm = @import("vm.zig");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    var args = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer args.deinit();
    _ = args.next();
    const path = args.next() orelse {
        std.debug.print("usage: zigbolge <program.mal> [max_steps]\n", .{});
        return;
    };
    const max_steps = if (args.next()) |raw| std.fmt.parseInt(u64, raw, 10) catch 100_000_000 else 100_000_000;
    const raw = try (std.Io.Dir.cwd()).readFileAlloc(init.io, path, alloc, .unlimited);
    var cells_buf: [vm.MEM_SIZE]u8 = undefined;
    var n: usize = 0;
    for (raw) |byte| {
        if (byte == 10 or byte == 13 or byte == 32 or byte == 9) continue;
        if (byte < 33 or byte > 126 or n >= vm.MEM_SIZE) {
            std.debug.print("error: invalid character in program\n", .{});
            return;
        }
        cells_buf[n] = byte;
        n += 1;
    }
    if (n == 0) {
        std.debug.print("error: empty program\n", .{});
        return;
    }
    var machine = vm.Vm{};
    const outcome = machine.run(cells_buf[0..n], "", max_steps);
    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, machine.output[0..outcome.output_len]);
    if (outcome.output_len > 0) try stdout.writeStreamingAll(init.io, "\n");
    std.debug.print("{{\"final\":{{\"a\":{d},\"c\":{d},\"d\":{d}}},\"halt_reason\":\"{s}\",\"output_len\":{d},\"status\":\"{s}\",\"steps\":{d}}}\n", .{ outcome.a, outcome.c, outcome.d, outcome.halt_reason, outcome.output_len, outcome.status, outcome.steps });
}
