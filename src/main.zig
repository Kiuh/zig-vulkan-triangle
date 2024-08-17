const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("zglfw");

const Allocator = std.mem.Allocator;

const App = struct {
    allocator: Allocator = undefined,

    window: *glfw.Window = undefined,

    size: @Vector(2, i32),
    title: [:0]const u8,

    pub fn init(allocator: Allocator, size: @Vector(2, i32), title: [:0]const u8) App {
        return App{
            .allocator = allocator,
            .size = size,
            .title = title,
        };
    }

    pub fn run(self: *App) !void {
        try self.initWindow();
        try self.mainLoop();
    }

    pub fn initWindow(self: *App) !void {
        try glfw.init();
        self.window = try glfw.Window.create(self.size[0], self.size[1], self.title, null);
    }
    pub fn mainLoop(self: *App) !void {
        while (!self.window.shouldClose()) {
            glfw.pollEvents();
            self.window.swapBuffers();
        }
    }

    pub fn deinit(self: *App) void {
        glfw.terminate();
        self.window.destroy();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = App.init(gpa.allocator(), .{ 1280, 720 }, "Zig + Vulkan = zex");
    defer app.deinit();

    try app.run();
}
