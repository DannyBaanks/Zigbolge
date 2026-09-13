const std = @import("std");

pub const MEM_SIZE: usize = 59049;
pub const LAST: u32 = MEM_SIZE - 1;
pub const POW9: u32 = 19683;
pub const HALF: u32 = 243;
pub const OUT_CAP: usize = 65536;

pub const ENCRYPT = "5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@";
const CRAZY_TBL = [3][3]u8{ .{ 1, 0, 0 }, .{ 1, 0, 2 }, .{ 2, 2, 1 } };

fn buildCrazy5Table() [HALF][HALF]u32 {
    @setEvalBranchQuota(1_000_000);
    var table: [HALF][HALF]u32 = undefined;
    var a5: usize = 0;
    while (a5 < HALF) : (a5 += 1) {
        var b5: usize = 0;
        while (b5 < HALF) : (b5 += 1) {
            var r: u32 = 0;
            var place: u32 = 1;
            var aa = a5;
            var bb = b5;
            var k: usize = 0;
            while (k < 5) : (k += 1) {
                r += @as(u32, CRAZY_TBL[bb % 3][aa % 3]) * place;
                aa /= 3;
                bb /= 3;
                place *= 3;
            }
            table[a5][b5] = r;
        }
    }
    return table;
}

const CRAZY5 = buildCrazy5Table();

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

    fn crazy(a: u32, b: u32) u32 {
        return CRAZY5[a % HALF][b % HALF] + HALF * CRAZY5[a / HALF][b / HALF];
    }

    fn rotate(n: u32) u32 {
        return POW9 * (n % 3) + n / 3;
    }

    fn load(self: *Vm, cells: []const u8) void {
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
        var reason: []const u8 = "StepsExhausted";
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
                        reason = "Eof";
                        return .{ .steps = steps, .status = "HALTED", .halt_reason = reason, .a = a, .c = c, .d = d, .output_len = output_len };
                    }
                    a = input[input_pos];
                    input_pos += 1;
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
                    return .{ .steps = steps, .status = "HALTED", .halt_reason = "VInstruction", .a = a, .c = c, .d = d, .output_len = output_len };
                },
                else => {},
            }
            const current = self.mem[c];
            if (current >= 33 and current <= 126) self.mem[c] = ENCRYPT[current - 33];
            c = if (c == LAST) 0 else c + 1;
            d = if (d == LAST) 0 else d + 1;
        }
        return .{ .steps = steps, .status = "TIMEOUT", .halt_reason = reason, .a = a, .c = c, .d = d, .output_len = output_len };
    }
};
