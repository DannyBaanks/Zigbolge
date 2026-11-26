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
    // Zig 0.16: stdin se lee via File.stdin().reader(io, buffer) + readSliceShort
    // hasta EndOfStream (esta std no tiene read-to-end directo). Buffers
    // separados: el del reader y el destino nunca son el mismo slice.
    const stdin = std.Io.File.stdin();
    var stdin_buf: [65536]u8 = undefined;
    var reader = stdin.reader(init.io, &stdin_buf);
    var tmp_buf: [65536]u8 = undefined;
    var input_list: std.ArrayList(u8) = .empty;
    while (true) {
        const got = reader.interface.readSliceShort(&tmp_buf) catch |e| switch (e) {
            error.ReadFailed => return e,
            else => unreachable,
        };
        if (got == 0) break;
        try input_list.appendSlice(alloc, tmp_buf[0..got]);
        if (got < tmp_buf.len) break; // fin de stream: lectura corta
    }
    var machine = vm.Vm{};
    const outcome = machine.run(cells_buf[0..n], input_list.items, max_steps);
    const stdout = std.Io.File.stdout();
    try stdout.writeStreamingAll(init.io, machine.output[0..outcome.output_len]);
    if (outcome.output_len > 0) try stdout.writeStreamingAll(init.io, "\n");
    std.debug.print("{{\"final\":{{\"a\":{d},\"c\":{d},\"d\":{d}}},\"halt_reason\":\"{s}\",\"output_len\":{d},\"status\":\"{s}\",\"steps\":{d}}}\n", .{ outcome.a, outcome.c, outcome.d, outcome.halt_reason, outcome.output_len, outcome.status, outcome.steps });
}
