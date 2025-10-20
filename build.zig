const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Build static artifact
    const root_module = b.createModule(.{
        .target = target,
        .optimize = optimize,
    });
    const lib = b.addLibrary(.{
        .name = "brotli_lib",
        .root_module = root_module,
    });

    lib.linkLibC();

    const upstream = b.dependency("brotli", .{});
    lib.addIncludePath(upstream.path("c/include"));
    lib.installHeadersDirectory(upstream.path("c/include/brotli"), "brotli", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // get c_sources according to c_root
    const c_root = upstream.path("c");
    const csources_exclude = [_][]const u8{ "fuzz", "tools" };
    const c_sources = getCSources(allocator, c_root, b, &csources_exclude);
    defer allocator.free(c_sources);

    if (c_sources.len == 0) {
        const cr_path_rel = c_root.getPath(b);
        std.debug.print("Error: no .c source files were returned from {s}\n", .{cr_path_rel});
        return;
    }

    lib.addCSourceFiles(.{
        .root = c_root,
        .files = c_sources,
    });

    switch (target.result.os.tag) {
        .linux => lib.root_module.addCMacro("OS_LINUX", "1"),
        .freebsd => lib.root_module.addCMacro("OS_FREEBSD", "1"),
        .macos => lib.root_module.addCMacro("OS_MACOSX", "1"),
        else => {},
    }

    b.installArtifact(lib);

    // Add C api module
    const brotli_api = b.addTranslateC(.{
        .root_source_file = b.path("include/c.h"),
        .target = target,
        .optimize = optimize,
    });

    brotli_api.addIncludePath(upstream.path("c/include"));

    _ = b.addModule("c_api", .{
        .root_source_file = brotli_api.getOutput(),
    });

    // build tools/brotli.c
    const build_exe = b.option(bool, "build-exe", "Build brotli executable from test/brotli.c (default:false)") orelse false;
    if (build_exe) {
        const exe_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        });
        const exe = b.addExecutable(.{
            .name = "brotli",
            .root_module = exe_module,
        });
        exe.addCSourceFile(.{ .file = upstream.path("c/tools/brotli.c"), .flags = &.{} });
        exe.linkLibrary(lib);
        b.installArtifact(exe);
    }
}

/// get relevant .c files to add as sources
fn getCSources(allocator: std.mem.Allocator, c_root: std.Build.LazyPath, src_builder: *std.Build, exclude: []const []const u8) [][]const u8 {
    // Get the actual path from LazyPath - this resolves the dependency
    const cr_path_rel = c_root.getPath(src_builder);

    // get a walker for cr_path directory
    var cr_dir = std.fs.cwd().openDir(cr_path_rel, .{ .iterate = true }) catch |err| {
        std.debug.print("Error: {}, while trying to open dir '{s}'\n", .{ err, cr_path_rel });
        return &[_][]const u8{};
    };
    defer cr_dir.close();
    var walker = cr_dir.walk(allocator) catch |err| {
        std.debug.print("Error: {}, while trying to get walker for dir '{s}'\n", .{ err, cr_path_rel });
        return &[_][]const u8{};
    };
    defer walker.deinit();

    // arraylist to populate with .c files path
    var source_list: std.ArrayList([]const u8) = .{};
    defer source_list.deinit(allocator);

    blk: while (walker.next() catch null) |entry| {
        switch (entry.kind) {
            std.fs.File.Kind.file => {
                for (exclude) |x| {
                    if (std.mem.indexOf(u8, entry.path, x) != null) continue :blk;
                }
                if (std.mem.indexOf(u8, entry.basename, ".c") != null) {
                    const path = allocator.dupe(u8, entry.path) catch |err| {
                        std.debug.print("Error: {}, while trying to duplicate '{s}'\n", .{ err, entry.path });
                        continue;
                    };
                    source_list.append(allocator, path) catch |err| {
                        std.debug.print("Error: {}, while trying to append '{s}' to source_list\n", .{ err, path });
                        continue;
                    };
                }
            },
            else => {},
        }
    }

    return source_list.toOwnedSlice(allocator) catch |err| {
        std.debug.print("Error: {}, while converting source_list to owned slice\n", .{err});
        return &[_][]const u8{};
    };
}
