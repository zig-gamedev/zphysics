const std = @import("std");
const c = @import("jolt_c");
const zphysics = @import("zphysics");

fn printSimpleStruct(comptime name: []const u8, comptime CType: type, comptime ZType: type) void {
    std.debug.print("\n=== {s} ===\n", .{name});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(CType), @alignOf(CType) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(ZType), @alignOf(ZType) });
    const size_match = if (@sizeOf(CType) == @sizeOf(ZType)) "✓" else "✗";
    std.debug.print("Size Match: {s}\n", .{size_match});
}

pub fn main() void {
    std.debug.print("========================================\n", .{});
    std.debug.print("  C vs Zig Struct Size Comparison Tool\n", .{});
    std.debug.print("========================================\n", .{});

    // Core structs
    printSimpleStruct("BodyID", c.JPC_BodyID, zphysics.BodyId);
    printSimpleStruct("SubShapeID", c.JPC_SubShapeID, zphysics.SubShapeId);
    printSimpleStruct("CollisionGroup", c.JPC_CollisionGroup, zphysics.CollisionGroup);
    printSimpleStruct("MassProperties", c.JPC_MassProperties, zphysics.MassProperties);
    printSimpleStruct("MotionProperties", c.JPC_MotionProperties, zphysics.MotionProperties);

    // Complex structs - print size/align only
    std.debug.print("\n=== CollideShapeResult ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_CollideShapeResult), @alignOf(c.JPC_CollideShapeResult) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.CollideShapeResult), @alignOf(zphysics.CollideShapeResult) });

    std.debug.print("\n=== ContactManifold ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_ContactManifold), @alignOf(c.JPC_ContactManifold) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.ContactManifold), @alignOf(zphysics.ContactManifold) });

    std.debug.print("\n=== BodyCreationSettings ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_BodyCreationSettings), @alignOf(c.JPC_BodyCreationSettings) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.BodyCreationSettings), @alignOf(zphysics.BodyCreationSettings) });

    std.debug.print("\n=== CharacterBaseSettings ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_CharacterBaseSettings), @alignOf(c.JPC_CharacterBaseSettings) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.CharacterBaseSettings), @alignOf(zphysics.CharacterBaseSettings) });

    std.debug.print("\n=== CharacterSettings ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_CharacterSettings), @alignOf(c.JPC_CharacterSettings) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.CharacterSettings), @alignOf(zphysics.CharacterSettings) });

    std.debug.print("\n=== CharacterVirtualSettings ===\n", .{});
    std.debug.print("C Size: {d}, Align: {d}\n", .{ @sizeOf(c.JPC_CharacterVirtualSettings), @alignOf(c.JPC_CharacterVirtualSettings) });
    std.debug.print("Z Size: {d}, Align: {d}\n", .{ @sizeOf(zphysics.CharacterVirtualSettings), @alignOf(zphysics.CharacterVirtualSettings) });

    // Constraint types (opaque pointers in C, use settings instead)
    printSimpleStruct("ConstraintSettings", c.JPC_ConstraintSettings, zphysics.ConstraintSettings);
    printSimpleStruct("HingeConstraintSettings", c.JPC_HingeConstraintSettings, zphysics.HingeConstraintSettings);
    printSimpleStruct("SliderConstraintSettings", c.JPC_SliderConstraintSettings, zphysics.SliderConstraintSettings);
    printSimpleStruct("DistanceConstraintSettings", c.JPC_DistanceConstraintSettings, zphysics.DistanceConstraintSettings);
    printSimpleStruct("PointConstraintSettings", c.JPC_PointConstraintSettings, zphysics.PointConstraintSettings);
    printSimpleStruct("FixedConstraintSettings", c.JPC_FixedConstraintSettings, zphysics.FixedConstraintSettings);
    printSimpleStruct("ConeConstraintSettings", c.JPC_ConeConstraintSettings, zphysics.ConeConstraintSettings);
    printSimpleStruct("GearConstraintSettings", c.JPC_GearConstraintSettings, zphysics.GearConstraintSettings);
    printSimpleStruct("PulleyConstraintSettings", c.JPC_PulleyConstraintSettings, zphysics.PulleyConstraintSettings);
    printSimpleStruct("SixDOFConstraintSettings", c.JPC_SixDOFConstraintSettings, zphysics.SixDOFConstraintSettings);
    printSimpleStruct("SwingTwistConstraintSettings", c.JPC_SwingTwistConstraintSettings, zphysics.SwingTwistConstraintSettings);

    // Vehicle types
    printSimpleStruct("VehicleConstraint", c.JPC_VehicleConstraint, zphysics.VehicleConstraint);
    printSimpleStruct("WheeledVehicleController", c.JPC_WheeledVehicleController, zphysics.WheeledVehicleController);
    printSimpleStruct("TrackedVehicleController", c.JPC_TrackedVehicleController, zphysics.TrackedVehicleController);
    printSimpleStruct("MotorcycleController", c.JPC_MotorcycleController, zphysics.MotorcycleController);

    // Other important structs
    printSimpleStruct("RayCast", c.JPC_RayCast, zphysics.RayCast);
    printSimpleStruct("ShapeCast", c.JPC_ShapeCast, zphysics.ShapeCast);
    printSimpleStruct("RayCastResult", c.JPC_RayCastResult, zphysics.RayCastResult);
    printSimpleStruct("ShapeCastResult", c.JPC_ShapeCastResult, zphysics.ShapeCastResult);
    printSimpleStruct("ContactPoint", c.JPC_ContactPoint, zphysics.ContactPoint);
    printSimpleStruct("SoftBodyCreationSettings", c.JPC_SoftBodyCreationSettings, zphysics.SoftBodyCreationSettings);

    // Enum sizes
    std.debug.print("\n========================================\n", .{});
    std.debug.print("  Enum Sizes\n", .{});
    std.debug.print("========================================\n", .{});
    std.debug.print("MotionType: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_MotionType), @sizeOf(zphysics.MotionType) });
    std.debug.print("MotionQuality: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_MotionQuality), @sizeOf(zphysics.MotionQuality) });
    std.debug.print("Activation: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_Activation), @sizeOf(zphysics.Activation) });
    std.debug.print("ValidateResult: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_ValidateResult), @sizeOf(zphysics.ValidateResult) });
    std.debug.print("OverrideMassProperties: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_OverrideMassProperties), @sizeOf(zphysics.OverrideMassProperties) });
    std.debug.print("CharacterGroundState: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_CharacterGroundState), @sizeOf(zphysics.CharacterGroundState) });
    std.debug.print("BackFaceMode: C={d}, Z={d}\n", .{ @sizeOf(c.JPC_BackFaceMode), @sizeOf(zphysics.BackFaceMode) });
}