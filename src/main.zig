const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("zglfw");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("Hello, world!\n", .{});
    try stdout.print("VK {}\n", .{vk.API_VERSION_1_0});
    try stdout.print("GLFW {}\n", .{glfw.Arrow});
}
