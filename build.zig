const std = @import("std");
const system_sdk = @import("system_sdk");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Zglfw
    const zglfw = b.dependency("zglfw", .{});

    // Vulkan-generator
    const vk_zig = b.dependency("vulkan_zig", .{});

    // Main program exe
    const exe = b.addExecutable(.{
        .name = "zig-vulkan-triangle",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("zglfw", zglfw.module("root"));
    exe.linkLibrary(zglfw.artifact("glfw"));
    system_sdk.addLibraryPathsTo(exe);

    exe.root_module.addImport("vulkan", vk_zig.module("vulkan-zig"));
    b.installArtifact(exe);

    // Run command
    const run_exe = b.addRunArtifact(exe);
    run_exe.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_exe.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);
}
