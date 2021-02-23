const std = @import("std");
const Builder = std.build.Builder;
const Pkg = std.build.Pkg;

const prefixTreePkg = Pkg{
    .name = "prefix-tree-map",
    .path = "dependencies/zig-data-structures/source/prefix_tree_map.zig",
};
const harfbuzzPkg = Pkg{
    .name = "harfbuzz",
    .path = "dependencies/harfbuzz.zig",
};
const freetypePkg = Pkg{
    .name = "freetype",
    .path = "dependencies/freetype.zig",
    .dependencies = &[_]Pkg{harfbuzzPkg},
};
const SDL2Pkg = Pkg{
    .name = "SDL2",
    .path = "dependencies/SDL2.zig",
};
const zssPkg = Pkg{
    .name = "zss",
    .path = "zss.zig",
    .dependencies = &[_]Pkg{ prefixTreePkg, freetypePkg, SDL2Pkg },
};

pub fn build(b: *Builder) void {
    const freetype_system_include_dir = b.option(
        []const u8,
        "freetype-dir",
        "the location of the header files for freetype",
    ) orelse "/usr/include/freetype2/";

    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("zss", "zss.zig");
    lib.setBuildMode(mode);
    lib.addPackage(zssPkg);
    lib.install();

    var main_tests = b.addTest("zss.zig");
    main_tests.setBuildMode(mode);
    main_tests.addPackage(prefixTreePkg);
    main_tests.addPackage(freetypePkg);
    main_tests.addPackage(SDL2Pkg);
    main_tests.addPackage(zssPkg);
    main_tests.linkSystemLibrary("c");
    main_tests.linkSystemLibrary("freetype");
    main_tests.addIncludeDir(freetype_system_include_dir);
    main_tests.linkSystemLibrary("SDL2");

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);

    const graphical_test_step = b.step("graphical-test", "Run graphical tests");
    const all_tests = @import("test/tests.zig");
    inline for (all_tests.tests) |t| {
        var test_exec = b.addExecutable(t.name, "test/" ++ t.root);
        test_exec.setBuildMode(mode);
        test_exec.addPackage(prefixTreePkg);
        test_exec.addPackage(harfbuzzPkg);
        test_exec.addPackage(SDL2Pkg);
        test_exec.addPackage(zssPkg);
        test_exec.linkSystemLibrary("c");
        test_exec.linkSystemLibrary("freetype");
        test_exec.linkSystemLibrary("harfbuzz");
        test_exec.linkSystemLibrary("SDL2");
        test_exec.linkSystemLibrary("SDL2_image");
        test_exec.addSystemIncludeDir(freetype_system_include_dir);
        test_exec.install();
        graphical_test_step.dependOn(&graphical_tests.step);
    }
}
