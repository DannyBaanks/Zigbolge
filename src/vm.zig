const std = @import("std");

pub const MEM_SIZE: usize = 59049;
pub const LAST: u32 = MEM_SIZE - 1; // 59048
pub const POW9: u32 = 19683;
pub const OUT_CAP: usize = 65536;

pub const ENCRYPT = "5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@";
pub const XLAT1 = "+b(29e*j1VMEKLyC})8&m#~W>qxdRp0wkrUo[D7,XTcA\"lI.v%{gJh4G\\-=O@5`_3i<?Z';FNQuY]szf$!BS/|t:Pn6^Ha";

// Canonical 9x9 lookup table for crazy operation (2 trits at a time)
// Row is y % 9, column is x % 9: matches Olmstead's CRAZY_TBL[cell][ctrl] algebra.
const O9 = [9][9]u16{
    .{ 4, 3, 3, 1, 0, 0, 1, 0, 0 },
    .{ 4, 3, 5, 1, 0, 2, 1, 0, 2 },
    .{ 5, 5, 4, 2, 2, 1, 2, 2, 1 },
    .{ 4, 3, 3, 1, 0, 0, 7, 6, 6 },
    .{ 4, 3, 5, 1, 0, 2, 7, 6, 8 },
    .{ 5, 5, 4, 2, 2, 1, 8, 8, 7 },
    .{ 7, 6, 6, 7, 6, 6, 4, 3, 3 },
    .{ 7, 6, 8, 7, 6, 8, 4, 3, 5 },
    .{ 8, 8, 7, 8, 8, 7, 5, 5, 4 },
};

const P9 = [5]u16{ 1, 9, 81, 729, 6561 };

pub fn crazy(x: u32, y: u32) u32 {
    var res: u32 = 0;
    var j: usize = 0;
    while (j < 5) : (j += 1) {
        const pj = P9[j];
        const row = (y / pj) % 9;
        const col = (x / pj) % 9;
        res += @as(u32, O9[row][col]) * pj;
    }
    return res;
}

pub fn rotate(n: u32) u32 {
    return POW9 * (n % 3) + n / 3;
}

pub const Outcome = struct {
    steps: u64,
    status: []const u8,
    halt_reason: []const u8,
    a: u32,
    c: u32,
    d: u32,
    output_len: usize,
};

pub const Vm = struct {
    mem: [MEM_SIZE]u16 = undefined,
    output: [OUT_CAP]u8 = undefined,

    pub fn load(self: *Vm, cells: []const u8) void {
        @memset(&self.mem, 0);
        for (cells, 0..) |cell, i| self.mem[i] = cell;
        var i = cells.len;
        while (i < MEM_SIZE) : (i += 1) {
            const p1 = if (i > 0) self.mem[i - 1] else 0;
            const p2 = if (i > 1) self.mem[i - 2] else 0;
            self.mem[i] = @intCast(crazy(p1, p2));
        }
    }

    pub fn run(self: *Vm, cells: []const u8, input: []const u8, max_steps: u64) Outcome {
        self.load(cells);
        var a: u32 = 0;
        var c: u32 = 0;
        var d: u32 = 0;
        var steps: u64 = 0;
        var input_pos: usize = 0;
        var output_len: usize = 0;
        const reason: []const u8 = "StepsExhausted";
        while (steps < max_steps) {
            steps += 1;
            const op = (@as(u32, self.mem[c]) + c) % 94;
            switch (op) {
                4 => c = self.mem[d],
                5 => {
                    if (output_len < OUT_CAP) {
                        self.output[output_len] = @intCast(a % 256);
                        output_len += 1;
                    }
                },
                23 => {
                    if (input_pos >= input.len) {
                        a = LAST; // Canonical Olmstead Malbolge EOF: a = 59048
                    } else {
                        a = input[input_pos];
                        input_pos += 1;
                    }
                },
                39 => {
                    const r = rotate(self.mem[d]);
                    self.mem[d] = @intCast(r);
                    a = r;
                },
                40 => d = self.mem[d],
                62 => {
                    const r = crazy(a, self.mem[d]);
                    self.mem[d] = @intCast(r);
                    a = r;
                },
                81 => {
                    return .{
                        .steps = steps,
                        .status = "HALTED",
                        .halt_reason = "VInstruction",
                        .a = a,
                        .c = c,
                        .d = d,
                        .output_len = output_len,
                    };
                },
                else => {},
            }
            const current = self.mem[c];
            if (current >= 33 and current <= 126) {
                self.mem[c] = ENCRYPT[current - 33];
            }
            c = if (c == LAST) 0 else c + 1;
            d = if (d == LAST) 0 else d + 1;
        }
        return .{
            .steps = steps,
            .status = "TIMEOUT",
            .halt_reason = reason,
            .a = a,
            .c = c,
            .d = d,
            .output_len = output_len,
        };
    }
};

test "crazy base-9 vs ternary agreement" {
    // In Malbolge ternary crazy, 0 OP 0 = 1 for all 10 trits: sum_{k=0}^9 3^k = 29524.
    try std.testing.expectEqual(@as(u32, 29524), crazy(0, 0));
    try std.testing.expectEqual(@as(u32, 1), crazy(0, 1) % 3);
}

test "hello world execution" {
    const fixture = "(=<`#9]~6ZY327Uv4-QsqpMn&+Ij\"'E%e{Ab~w=_:]Kw%o44Uqp0/Q?xNvL:`H%c#DD2^WV>gY;dts76qKJImZkj";
    var machine = Vm{};
    const res = machine.run(fixture, "", 10_000);
    try std.testing.expectEqualStrings("HALTED", res.status);
    try std.testing.expectEqualStrings("VInstruction", res.halt_reason);
    try std.testing.expectEqual(@as(u64, 48), res.steps);
    try std.testing.expectEqual(@as(usize, 13), res.output_len);
    try std.testing.expectEqualStrings("Hello, world.", machine.output[0..res.output_len]);
    try std.testing.expectEqual(@as(u32, 19758), res.a);
    try std.testing.expectEqual(@as(u32, 85), res.c);
    try std.testing.expectEqual(@as(u32, 63), res.d);
}

test "eof sets a to 59048 without halt" {
    // c=0: 'u' (117) -> op 23 (in)
    // c=1: 'P' (80)  -> (80 + 1) % 94 = 81 (halt)
    const prog = "uP";
    var machine = Vm{};
    const res = machine.run(prog, "", 100);
    try std.testing.expectEqualStrings("HALTED", res.status);
    try std.testing.expectEqualStrings("VInstruction", res.halt_reason);
    try std.testing.expectEqual(@as(u32, LAST), res.a);
    try std.testing.expectEqual(@as(u64, 2), res.steps);
}
