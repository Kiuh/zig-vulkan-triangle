const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");
const allocator = std.heap.page_allocator;

/// Default GLFW error handling callback
fn glfwErrorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("GLFW ERROR: {}: {s}\n", .{ error_code, description });
}

/// Vulkan debug message handling callback
fn vkDebugMessage(
    message_severity: vk.DebugUtilsMessageSeverityFlagsEXT,
    message_type: vk.DebugUtilsMessageTypeFlagsEXT,
    callback_data: ?*const vk.DebugUtilsMessengerCallbackDataEXT,
    user_data: ?*anyopaque,
) callconv(.C) vk.Bool32 {
    _ = message_type;
    _ = user_data;
    const verbose_severity = comptime (vk.DebugUtilsMessageSeverityFlagsEXT{ .verbose_bit_ext = true }).toInt();
    const info_severity = comptime (vk.DebugUtilsMessageSeverityFlagsEXT{ .info_bit_ext = true }).toInt();
    const warning_severity = comptime (vk.DebugUtilsMessageSeverityFlagsEXT{ .warning_bit_ext = true }).toInt();
    const error_severity = comptime (vk.DebugUtilsMessageSeverityFlagsEXT{ .error_bit_ext = true }).toInt();
    const color: u32 = switch (message_severity.toInt()) {
        verbose_severity => 37,
        info_severity => 32,
        warning_severity => 33,
        error_severity => 31,
        else => unreachable,
    };
    std.log.info("\x1b[{}m{s}\x1b[0m\n", .{ color, callback_data.?.p_message });
    return vk.FALSE;
}

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .enumerateInstanceLayerProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDebugUtilsMessengerEXT = true,
    .destroyDebugUtilsMessengerEXT = true,
});

const Application = struct {
    const Self = @This();

    // General Info
    title: [*:0]const u8 = undefined, // CREATE
    width: u32 = undefined, // CREATE
    height: u32 = undefined, // CREATE

    // Glfw stuff
    window: glfw.Window = undefined, // INIT WINDOW

    //Vulkan dispatchers
    base_dispatch: BaseDispatch = undefined, // INIT VULKAN -> CREATE INSTANCE
    instance_dispatch: InstanceDispatch = undefined, // INIT VULKAN -> CREATE INSTANCE

    // Validation
    enable_validation_layers: bool = undefined, // CREATE
    validation_layers: std.ArrayList([*:0]const u8) = undefined, // CREATE

    // Debug Messager
    debug_messager: vk.DebugUtilsMessengerEXT = undefined, // INIT VULKAN -> SETUP DEBUG MESSAGER

    //Vulkan variables
    instance: vk.Instance = undefined, // INIT VULKAN -> CREATE INSTANCE

    pub fn Create(_title: [*:0]const u8, _width: u32, _height: u32, _enable_validation_layers: bool) !Self {
        var self = Self{ .title = _title, .width = _width, .height = _height, .enable_validation_layers = _enable_validation_layers };
        if (_enable_validation_layers) {
            self.validation_layers = try std.ArrayList([*:0]const u8).initCapacity(allocator, 1);
            try self.validation_layers.append("VK_LAYER_KHRONOS_validation");
        }
        return self;
    }

    pub fn run(self: *Self) !void {
        try self.initWindow();
        try self.initVulkan();
        try self.mainLoop();
    }

    fn initWindow(self: *Self) error{ FailedToInitializeGLFW, CannotCreateGLFWWindow }!void {
        // Init glfw
        glfw.setErrorCallback(glfwErrorCallback);
        if (!glfw.init(.{})) {
            std.log.err("Failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
            return error.FailedToInitializeGLFW;
        }
        // Init window
        self.window = glfw.Window.create(self.width, self.height, self.title, null, null, .{
            .client_api = .no_api,
            .resizable = false,
        }) orelse {
            std.log.err("Failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            return error.CannotCreateGLFWWindow;
        };
    }

    fn initVulkan(self: *Self) !void {
        try self.createInstance();
        try self.setupDebugMessenger();
    }

    fn setupDebugMessenger(self: *Self) !void {
        if (!self.enable_validation_layers) {
            return;
        }

        const severnity = vk.DebugUtilsMessageSeverityFlagsEXT{ .verbose_bit_ext = true, .warning_bit_ext = true, .error_bit_ext = true };
        const message_type = vk.DebugUtilsMessageTypeFlagsEXT{ .general_bit_ext = true, .validation_bit_ext = true, .performance_bit_ext = true };
        const debug_utils_create_info = vk.DebugUtilsMessengerCreateInfoEXT{ .message_severity = severnity, .message_type = message_type, .pfn_user_callback = vkDebugMessage };

        self.debug_messager = try self.instance_dispatch.createDebugUtilsMessengerEXT(self.instance, &debug_utils_create_info, null);
    }

    fn checkValidationLayerSupport(self: *Self) !bool {
        var layer_count: u32 = undefined;
        _ = try self.base_dispatch.enumerateInstanceLayerProperties(&layer_count, null);

        const avaible_layers = try allocator.alloc(vk.LayerProperties, layer_count);
        defer allocator.free(avaible_layers);

        _ = try self.base_dispatch.enumerateInstanceLayerProperties(&layer_count, avaible_layers.ptr);

        for (self.validation_layers.items) |layer_name| {
            var check = false;
            for (avaible_layers) |avaible_layer_property| {
                const len = std.mem.indexOfScalar(u8, &avaible_layer_property.layer_name, 0).?;
                const avaible_layer_name = avaible_layer_property.layer_name[0..len];
                const needed_layer_name = std.mem.span(layer_name);
                if (std.mem.eql(u8, avaible_layer_name, needed_layer_name)) {
                    check = true;
                }
            }
            if (!check) {
                return false;
            }
        }
        return true;
    }

    fn createInstance(self: *Self) !void {
        const vk_proc = @as(vk.PfnGetInstanceProcAddr, @ptrCast(&glfw.getInstanceProcAddress));
        self.base_dispatch = try BaseDispatch.load(vk_proc);

        if (self.enable_validation_layers and !try self.checkValidationLayerSupport()) {
            std.log.err("Validation layers requested, but not available!", .{});
            return error.LayerNotPresent;
        }

        const glfw_extstantions = glfw.getRequiredInstanceExtensions() orelse {
            const err = glfw.mustGetError();
            std.log.err("Failed to get required vulkan instance extensions: error={s}", .{err.description});
            return err.error_code;
        };

        var required_instance_extensions = std.ArrayList([*:0]const u8).init(allocator);
        defer required_instance_extensions.deinit();
        try required_instance_extensions.appendSlice(glfw_extstantions);

        if (self.enable_validation_layers) {
            try required_instance_extensions.append(vk.extension_info.ext_debug_utils.name);
        }

        const application_info = vk.ApplicationInfo{
            .p_application_name = "Application name",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "No Engine",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.makeApiVersion(0, 1, 1, 0),
        };

        const create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &application_info,
            .enabled_layer_count = blk: {
                if (self.enable_validation_layers) {
                    break :blk @intCast(self.validation_layers.items.len);
                }
                break :blk 0;
            },
            .pp_enabled_layer_names = blk: {
                if (self.enable_validation_layers) {
                    break :blk @ptrCast(self.validation_layers.items);
                }
                break :blk undefined;
            },
            .enabled_extension_count = @intCast(required_instance_extensions.items.len),
            .pp_enabled_extension_names = @ptrCast(required_instance_extensions.items),
        };

        self.instance = try self.base_dispatch.createInstance(&create_info, null);
        self.instance_dispatch = try InstanceDispatch.load(self.instance, self.base_dispatch.dispatch.vkGetInstanceProcAddr);
    }

    fn mainLoop(self: *Self) !void {
        while (!self.window.shouldClose()) {
            glfw.pollEvents();
        }
    }

    pub fn deinit(self: *Self) void {
        if (self.enable_validation_layers) {
            self.validation_layers.deinit();
            self.instance_dispatch.destroyDebugUtilsMessengerEXT(self.instance, self.debug_messager, null);
        }
        self.instance_dispatch.destroyInstance(self.instance, null);
        self.window.destroy();
        glfw.terminate();
    }
};

pub fn main() !void {
    var app = try Application.Create("Vulkan triangle", 1280, 720, true);
    defer app.deinit();
    app.run() catch |err| {
        std.log.err("Application exited with error: {any}", .{err});
        return err;
    };
}
