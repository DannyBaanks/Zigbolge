const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Classic Malbolge (59,049 cells)
    const exe_classic = b.addExecutable(.{
        .name = "zigbolge",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe_classic);

    // Unshackled Malbolge (3^19 cells)
    const exe_19 = b.addExecutable(.{
        .name = "zigbolge19",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main19.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe_19);

    // Run classic
    const run_cmd = b.addRunArtifact(exe_classic);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run Zigbolge Classic VM");
    run_step.dependOn(&run_cmd.step);

    // Tests
    const test_classic = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vm.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_test_classic = b.addRunArtifact(test_classic);

    const test_19 = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/vm19.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    const run_test_19 = b.addRunArtifact(test_19);

    const test_step = b.step("test", "Run all unit tests");
    test_step.dependOn(&run_test_classic.step);
    test_step.dependOn(&run_test_19.step);
}
