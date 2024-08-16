const std = @import("std");
const system_sdk = @import("system_sdk");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Zglfw
    const zglfw = b.dependency("zglfw", .{});

    // Vulkan-generator
    const vk_gen = b.dependency("vulkan_zig", .{}).artifact("vulkan-zig-generator");
    const vk_generate_cmd = b.addRunArtifact(vk_gen);
    const vulkan_registry = b.dependency("vulkan_headers", .{}).path("registry/vk.xml");
    vk_generate_cmd.addFileArg(vulkan_registry);
    const vulkan_zig = b.addModule("vulkan-zig", .{
        .root_source_file = vk_generate_cmd.addOutputFileArg("vk.zig"),
    });

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
    exe.root_module.addImport("vulkan", vulkan_zig);
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
