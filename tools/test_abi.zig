const std = @import("std");
const c = @import("jolt_c");
const zphysics = @import("zphysics");

pub fn main() void {
    // Test Zig side BodyCreationSettings layout
    std.debug.print("Zig BodyCreationSettings:\n", .{});
    std.debug.print("  Size: {d}\n", .{@sizeOf(zphysics.BodyCreationSettings)});
    std.debug.print("  Align: {d}\n", .{@alignOf(zphysics.BodyCreationSettings)});
    std.debug.print("  shape offset: {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "shape")});
    std.debug.print("  reserved offset: {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "reserved")});

    // Create an instance and check memory layout
    const settings = zphysics.BodyCreationSettings{
        .position = .{ 0.0, -1.0, 0.0, 1.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .shape = null,
        .motion_type = .static,
        .object_layer = 1,
    };

    const bytes = std.mem.asBytes(&settings);
    std.debug.print("\nZig BodyCreationSettings bytes (224-239):\n", .{});
    var i: usize = 224;
    while (i < 240) : (i += 1) {
        std.debug.print("  [{d}] {x:0>2}\n", .{ i, bytes[i] });
    }

    // Check shape field value
    const shape_ptr: ?*const zphysics.Shape = settings.shape;
    const shape_bytes: *const [8]u8 = @ptrCast(&shape_ptr);
    std.debug.print("\nShape field bytes: {x} {x} {x} {x} {x} {x} {x} {x}\n", .{
        shape_bytes[0], shape_bytes[1], shape_bytes[2], shape_bytes[3],
        shape_bytes[4], shape_bytes[5], shape_bytes[6], shape_bytes[7],
    });

    // Check C side expected layout
    std.debug.print("\nC BodyCreationSettings:\n", .{});
    std.debug.print("  Size: {d}\n", .{@sizeOf(c.JPC_BodyCreationSettings)});
    std.debug.print("  Align: {d}\n", .{@alignOf(c.JPC_BodyCreationSettings)});
    std.debug.print("  shape offset: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "shape")});
}