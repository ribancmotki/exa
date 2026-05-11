const std = @import("std");

const PQ_LIB_DIR = "/nix/store/xb4h083j02mr2ix7pgj7iawxh2hk100l-postgresql-15.7-lib/lib";
const PQ_INC_DIR = "/nix/store/07s64wxjzk6z1glwxvl3yq81vdn42k40-postgresql-15.7/include";
const HIREDIS_LIB_DIR = "/nix/store/8b9bdqwjxahgyl8yns92cva6b6j8kirz-hiredis-1.2.0/lib";
const HIREDIS_INC_DIR = "/nix/store/8b9bdqwjxahgyl8yns92cva6b6j8kirz-hiredis-1.2.0/include";
const SSL_LIB_DIR = "/nix/store/gp504m4dvw5k2pdx6pccf1km79fkcwgf-openssl-3.0.13/lib";
const SSL_INC_DIR = "/nix/store/191vca5vdxdlr32k2hpzd66mic98930f-openssl-3.0.13-dev/include";
const ZLIB_LIB_DIR = "/nix/store/lv6nackqis28gg7l2ic43f6nk52hb39g-zlib-1.3.1/lib";
const ZLIB_INC_DIR = "/nix/store/qj9byzfvh7dd61kk0aglj7cwqj1xqg6l-zlib-1.3.1-dev/include";

fn addLibs(step: *std.Build.Step.Compile) void {
    step.addLibraryPath(.{ .cwd_relative = PQ_LIB_DIR });
    step.addIncludePath(.{ .cwd_relative = PQ_INC_DIR });
    step.addLibraryPath(.{ .cwd_relative = HIREDIS_LIB_DIR });
    step.addIncludePath(.{ .cwd_relative = HIREDIS_INC_DIR });
    step.addLibraryPath(.{ .cwd_relative = SSL_LIB_DIR });
    step.addIncludePath(.{ .cwd_relative = SSL_INC_DIR });
    step.addLibraryPath(.{ .cwd_relative = ZLIB_LIB_DIR });
    step.addIncludePath(.{ .cwd_relative = ZLIB_INC_DIR });
    step.linkLibC();
    step.linkSystemLibrary("pq");
    step.linkSystemLibrary("hiredis");
    step.linkSystemLibrary("ssl");
    step.linkSystemLibrary("crypto");
    step.linkSystemLibrary("z");
}

pub fn build(b: *std.Build) void {
    const target = b.resolveTargetQuery(.{
        .cpu_arch = .x86_64,
        .os_tag = .linux,
        .abi = .gnu,
    });
    const optimize: std.builtin.OptimizeMode = .ReleaseFast;

    const options = b.addOptions();
    options.addOption([]const u8, "version", "0.1.0");
    options.addOption([]const u8, "build_time", "2025-05-11");

    const exe = b.addExecutable(.{
        .name = "search-platform",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addOptions("build_options", options);
    addLibs(exe);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the search platform");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run all tests");
    const test_files = [_][]const u8{
        "tests/search_test.zig",
        "tests/contents_test.zig",
        "tests/monitor_test.zig",
        "tests/webset_test.zig",
        "tests/billing_test.zig",
    };
    for (test_files) |tf| {
        const unit_tests = b.addTest(.{
            .root_source_file = b.path(tf),
            .target = target,
            .optimize = .Debug,
        });
        unit_tests.root_module.addOptions("build_options", options);
        addLibs(unit_tests);
        const run_tests = b.addRunArtifact(unit_tests);
        test_step.dependOn(&run_tests.step);
    }
}
