const std = @import("std");
const glfw = @import("mach_glfw");

pub fn build(b: *std.Build) void {
    // Define
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vulkan_dep = b.dependency("vulkan", .{});
    const vulkan_mod = vulkan_dep.module("vulkan-zig-generated");

    const glfw_dep = b.dependency("mach_glfw", .{ .target = target, .optimize = optimize });
    const glfw_mod = glfw_dep.module("mach-glfw");

    // Construct exe
    const exe = b.addExecutable(.{
        .name = "zig-vulkan-triangle",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    try glfw.link(b, exe);
    exe.addModule("vulkan", vulkan_mod);
    exe.addModule("glfw", glfw_mod);

    // Install Artifact
    b.installArtifact(exe);

    // Addictional run command
    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
