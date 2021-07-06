const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

const pkgs = struct {
    const harfbuzz = Pkg{
        .name = "harfbuzz",
        .path = "dependencies/harfbuzz.zig",
    };
    const SDL2 = Pkg{
        .name = "SDL2",
        .path = "dependencies/SDL2.zig",
    };
};

pub fn build(b: *Builder) void {
    const mode = b.standardReleaseOptions();
    const target = b.standardTargetOptions(.{});

    const zss_lib = b.addStaticLibrary("zss", "zss.zig");
    zss_lib.setBuildMode(mode);
    zss_lib.setTarget(target);
    zss_lib.install();

    var lib_tests = b.addTest("zss.zig");
    lib_tests.setBuildMode(mode);
    lib_tests.setTarget(target);
    lib_tests.addPackage(pkgs.harfbuzz);
    lib_tests.linkLibC();
    lib_tests.linkSystemLibrary("harfbuzz");
    lib_tests.linkSystemLibrary("freetype2");

    const lib_tests_step = b.step("test", "Run the library tests");
    lib_tests_step.dependOn(&lib_tests.step);

    addDemo(b, mode, target);
}

fn addDemo(b: *Builder, mode: std.builtin.Mode, target: std.zig.CrossTarget) void {
    var demo_exe = b.addExecutable("demo", "demo/demo.zig");
    demo_exe.addPackage(pkgs.harfbuzz);
    demo_exe.addPackage(pkgs.SDL2);
    demo_exe.addPackage(Pkg{
        .name = "zss",
        .path = "zss.zig",
        .dependencies = &[_]Pkg{ pkgs.harfbuzz, pkgs.SDL2 },
    });
    demo_exe.linkLibC();
    demo_exe.linkSystemLibrary("harfbuzz");
    demo_exe.linkSystemLibrary("freetype2");
    demo_exe.linkSystemLibrary("SDL2");
    demo_exe.linkSystemLibrary("SDL2_image");
    demo_exe.setBuildMode(mode);
    demo_exe.setTarget(target);
    demo_exe.install();

    var demo_cmd = demo_exe.run();
    if (b.args) |args| demo_cmd.addArgs(args);
    demo_cmd.step.dependOn(&demo_exe.step);

    const demo_step = b.step("demo", "Run the demo");
    demo_step.dependOn(&demo_cmd.step);
}
