const std = @import("std");

pub const END: u64 = 1162261467; // 3^19
pub const THIRD: u64 = END / 3; // 387420489
pub const PAGE: usize = 65536;
pub const OUT_CAP: usize = 65536;

pub const XLAT_CONCAT =
    "SOMEBODY MAKE ME FEEL ALIVE" ++
    "[hj9>,5z]&gqtyfr$(we4{WP)H-Zn,[%\\3dL+Q;>U!pJS72FhOA1CB6v^=I_0/8|jsb9m<.TVac`uY*MK'X~xDl}REokN:#?G\"i@" ++
    "AND SHATTER ME";

pub const CRAZY_TBL = [3][3]u8{
    .{ 1, 0, 0 },
    .{ 1, 0, 2 },
    .{ 2, 2, 1 },
};

pub const CRZ2 = [144]u8{
    4, 3, 3, 1, 0, 0, 1, 0, 0, 9, 9, 9, 9, 9, 9, 9,
    4, 3, 5, 1, 0, 2, 1, 0, 2, 9, 9, 9, 9, 9, 9, 9,
    5, 5, 4, 2, 2, 1, 2, 2, 1, 9, 9, 9, 9, 9, 9, 9,
    4, 3, 3, 1, 0, 0, 7, 6, 6, 9, 9, 9, 9, 9, 9, 9,
    4, 3, 5, 1, 0, 2, 7, 6, 8, 9, 9, 9, 9, 9, 9, 9,
    5, 5, 4, 2, 2, 1, 8, 8, 7, 9, 9, 9, 9, 9, 9, 9,
    7, 6, 6, 7, 6, 6, 4, 3, 3, 9, 9, 9, 9, 9, 9, 9,
    7, 6, 8, 7, 6, 8, 4, 3, 5, 9, 9, 9, 9, 9, 9, 9,
    8, 8, 7, 8, 8, 7, 5, 5, 4, 9, 9, 9, 9, 9, 9, 9,
};

pub inline fn mcrz(a_in: u32, d_in: u32) u32 {
    var r: u32 = 0;
    var k: u32 = 1;
    var a: u32 = a_in;
    var d: u32 = d_in;
    comptime var pass = 0;
    inline while (pass < 9) : (pass += 1) {
        r +%= k *% CRZ2[(a % 9) + 16 * (d % 9)];
        a /= 9;
        d /= 9;
        k *%= 9;
    }
    r +%= k *% @as(u32, CRAZY_TBL[d % 3][a % 3]);
    return r;
}

pub inline fn mrot(x: u32) u32 {
    const t: u32 = @intCast(THIRD);
    const b = x % t;
    const m = b % 3;
    const q = b / 3;
    return q +% m *% (t / 3) +% (x -% b);
}

pub const Outcome19 = struct {
    steps: u64,
    status: []const u8,
    halt_reason: []const u8,
    a: u32,
    c: u64,
    d: u64,
    output_len: usize,
};

pub const Vm19 = struct {
    allocator: std.mem.Allocator,
    image: []u32,
    img_len: usize,
    chain_zone: []u32,
    zone_start: usize,
    pat: [6]u32,
    overlay: std.AutoHashMapUnmanaged(u32, u32),
    output: [OUT_CAP]u8,
    output_len: usize,

    pub fn init(allocator: std.mem.Allocator) Vm19 {
        return .{
            .allocator = allocator,
            .image = &[_]u32{},
            .img_len = 0,
            .chain_zone = &[_]u32{},
            .zone_start = 0,
            .pat = .{0} ** 6,
            .overlay = .{},
            .output = undefined,
            .output_len = 0,
        };
    }

    pub fn deinit(self: *Vm19) void {
        if (self.image.len > 0) self.allocator.free(self.image);
        if (self.chain_zone.len > 0) self.allocator.free(self.chain_zone);
        self.overlay.deinit(self.allocator);
    }

    pub fn loadCells(self: *Vm19, cells: []const u8) !void {
        self.img_len = cells.len;
        self.image = try self.allocator.alloc(u32, self.img_len);
        for (cells, 0..) |cell, i| self.image[i] = cell;

        self.zone_start = ((self.img_len + PAGE - 1) / PAGE) * PAGE;
        const zlen = self.zone_start - self.img_len;
        self.chain_zone = try self.allocator.alloc(u32, zlen);

        var p2: u32 = if (self.img_len >= 2) self.image[self.img_len - 2] else 0;
        var p1: u32 = if (self.img_len >= 1) self.image[self.img_len - 1] else 0;
        var i: usize = 0;
        while (i < zlen) : (i += 1) {
            const nxt = mcrz(p1, p2);
            self.chain_zone[i] = nxt;
            p2 = p1;
            p1 = nxt;
        }
        var k: usize = 0;
        while (k < 6) : (k += 1) {
            const nxt = mcrz(p1, p2);
            self.pat[k] = nxt;
            p2 = p1;
            p1 = nxt;
        }
    }

    inline fn beyondVal(self: *const Vm19, idx: usize) u32 {
        if (idx < self.zone_start) return self.chain_zone[idx - self.img_len];
        const pbase = idx & ~(PAGE - 1);
        const phase: usize = @intCast(@mod(@as(u64, pbase) % THIRD + (idx - pbase), 6));
        return self.pat[phase];
    }

    pub inline fn memGet(self: *const Vm19, idx: usize) u32 {
        if (idx < self.img_len) return self.image[idx];
        if (self.overlay.get(@intCast(idx))) |v| return v;
        return self.beyondVal(idx);
    }

    pub fn memSet(self: *Vm19, idx: usize, v: u32) !void {
        if (idx < self.img_len) {
            self.image[idx] = v;
        } else {
            try self.overlay.put(self.allocator, @intCast(idx), v);
        }
    }

    pub fn run(self: *Vm19, input: []const u8, max_steps: u64) !Outcome19 {
        var a: u32 = 0;
        var c: u64 = 0;
        var d: u64 = 0;
        var steps: u64 = 0;
        var input_pos: usize = 0;
        self.output_len = 0;

        // Exact fast20 regional decoding offsets
        const a1_off: i64 = 94 - @mod(@as(i64, @intCast((END - 1) / 6)) - 29524, 94);
        const a2_off: i64 = 94 - @mod(@as(i64, @intCast((END - 1) / 3)) - 59048, 94);
        var offs: [3]i64 = undefined;
        offs[0] = 0;
        offs[1] = @mod(a1_off - @as(i64, @intCast(THIRD)), 94) + 94;
        offs[2] = a2_off - @as(i64, @intCast(@mod(2 * THIRD, 94))) + 94;

        while (steps < max_steps) {
            const cu: u32 = @truncate(c);
            const region = cu / @as(u32, @intCast(THIRD));
            const off_i: i64 = if (region < 3) offs[region] else 0;
            const idx: usize = @intCast(@mod(@as(i64, cu) + @as(i64, self.memGet(cu)) + off_i, 94));

            switch (idx) {
                4 => c = self.memGet(@truncate(d)),
                5 => {
                    if (self.output_len < OUT_CAP) {
                        self.output[self.output_len] = @truncate(a);
                        self.output_len += 1;
                    }
                },
                23 => {
                    if (input_pos >= input.len) {
                        a = @truncate(END - 1); // 1162261466 canonical Unshackled EOF
                    } else {
                        a = input[input_pos];
                        input_pos += 1;
                    }
                },
                39 => {
                    const du: usize = @truncate(d);
                    const r = mrot(self.memGet(du));
                    try self.memSet(du, r);
                    a = r;
                },
                40 => d = self.memGet(@truncate(d)),
                62 => {
                    const du: usize = @truncate(d);
                    const r = mcrz(a, self.memGet(du));
                    try self.memSet(du, r);
                    a = r;
                },
                81 => {
                    return Outcome19{
                        .steps = steps,
                        .status = "HALTED",
                        .halt_reason = "VInstruction",
                        .a = a,
                        .c = c,
                        .d = d,
                        .output_len = self.output_len,
                    };
                },
                else => {},
            }

            const cur: usize = @truncate(c);
            const cv = self.memGet(cur);
            if (cv < XLAT_CONCAT.len) {
                try self.memSet(cur, XLAT_CONCAT[cv]);
            }

            c = (c + 1) % END;
            d = (d + 1) % END;
            steps += 1;
        }

        return Outcome19{
            .steps = steps,
            .status = "TIMEOUT",
            .halt_reason = "StepsExhausted",
            .a = a,
            .c = c,
            .d = d,
            .output_len = self.output_len,
        };
    }
};

test "vm19 crz and rot consistency" {
    // Check mrot on 0
    try std.testing.expectEqual(@as(u32, 0), mrot(0));
    // Check mcrz on 0, 0
    // In 19 trits, 0 OP 0 produces all 1s: sum_{k=0}^{18} 3^k = (3^19 - 1)/2 = 581130733
    const half19: u32 = @truncate((END - 1) / 2);
    try std.testing.expectEqual(half19, mcrz(0, 0));
}

test "vm19 step 1 parity with reference" {
    const fixture = "(=<`#9]~6ZY327Uv4-QsqpMn&+Ij\"'E%e{Ab~w=_:]Kw%o44Uqp0/Q?xNvL:`H%c#DD2^WV>gY;dts76qKJImZkj";
    var vm19 = Vm19.init(std.testing.allocator);
    defer vm19.deinit();

    try vm19.loadCells(fixture);
    const res = try vm19.run("", 1);

    try std.testing.expectEqualStrings("TIMEOUT", res.status);
    try std.testing.expectEqualStrings("StepsExhausted", res.halt_reason);
    try std.testing.expectEqual(@as(u32, 0), res.a);
    try std.testing.expectEqual(@as(u64, 1), res.c);
    try std.testing.expectEqual(@as(u64, 41), res.d);
    try std.testing.expectEqual(@as(u64, 1), res.steps);
}

test "vm19 eof sets a to 3^19-1" {
    // Under Unshackled (region 0, offs=0), c=0 op 23 ('u'), c=1 op 81 ('P')
    const prog = "uP";
    var vm19 = Vm19.init(std.testing.allocator);
    defer vm19.deinit();

    try vm19.loadCells(prog);
    const res = try vm19.run("", 100);

    try std.testing.expectEqualStrings("HALTED", res.status);
    try std.testing.expectEqualStrings("VInstruction", res.halt_reason);
    try std.testing.expectEqual(@as(u32, @truncate(END - 1)), res.a);
}
