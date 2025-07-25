const builtin = @import("builtin");
const std = @import("std");
const assert = std.debug.assert;
const options = @import("zphysics_options");
const c = @cImport({
    if (options.use_double_precision) @cDefine("JPH_DOUBLE_PRECISION", "");
    if (options.enable_asserts) @cDefine("JPH_ENABLE_ASSERTS", "");
    if (options.enable_cross_platform_determinism) @cDefine("JPH_CROSS_PLATFORM_DETERMINISTIC", "");
    if (options.enable_debug_renderer) @cDefine("JPH_DEBUG_RENDERER", "");
    @cInclude("JoltPhysicsC.h");
});

pub const Real = c.JPC_Real;
comptime {
    assert(if (options.use_double_precision) Real == f64 else Real == f32);
}

pub const rvec_align = if (Real == f64) 32 else 16;

pub const flt_epsilon = c.JPC_FLT_EPSILON;

pub const Material = opaque {};
pub const GroupFilter = opaque {};
pub const BodyLockInterface = opaque {};
pub const SharedMutex = opaque {};

pub const BroadPhaseLayer = c.JPC_BroadPhaseLayer;
pub const ObjectLayer = c.JPC_ObjectLayer;

const BodyIdInt = std.meta.fieldInfo(c.JPC_BodyID, .id).type;
pub const BodyId = enum(BodyIdInt) {
    invalid = c.JPC_BODY_ID_INVALID,
    index_bits = c.JPC_BODY_ID_INDEX_BITS,
    sequence_bits = c.JPC_BODY_ID_SEQUENCE_BITS,
    sequence_shift = c.JPC_BODY_ID_SEQUENCE_SHIFT,
    _,

    pub inline fn indexBits(self: BodyId) BodyIdInt {
        return @intFromEnum(self) & @intFromEnum(BodyId.index_bits);
    }

    pub inline fn toJpc(self: BodyId) c.JPC_BodyID {
        return .{ .id = @intFromEnum(self) };
    }
};

const SubShapeIdInt = std.meta.fieldInfo(c.JPC_SubShapeID, .id).type;
pub const SubShapeId = enum(SubShapeIdInt) {
    empty = c.JPC_SUB_SHAPE_ID_EMPTY,
    _,

    pub inline fn toJpc(self: SubShapeId) c.JPC_SubShapeID {
        return .{ .id = @intFromEnum(self) };
    }
};

pub const max_physics_jobs = c.JPC_MAX_PHYSICS_JOBS;
pub const max_physics_barriers = c.JPC_MAX_PHYSICS_BARRIERS;

pub const debug_renderer_enabled = options.enable_debug_renderer;
comptime {
    assert(if (debug_renderer_enabled) c.JPC_DEBUG_RENDERER == 1 else c.JPC_DEBUG_RENDERER == 0);
}

const TempAllocator = opaque {};
const JobSystem = opaque {};

/// Check if this is a valid body pointer.
/// When a body is freed the memory that the pointer occupies is reused to store a freelist.
/// NOTE: This function is *not* protected by a lock, use with care!
pub inline fn isValidBodyPointer(body: *const Body) bool {
    return (@intFromPtr(body) & c._JPC_IS_FREED_BODY_BIT) == 0;
}

/// Access a body, will return a `null` if the `body_id` is no longer valid.
/// Use `PhysicsSystem.getBodies()` to get all the bodies.
/// NOTE: This function is *not* protected by a lock, use with care!
pub inline fn tryGetBody(all_bodies: []const *const Body, body_id: BodyId) ?*const Body {
    const body = all_bodies[body_id.indexBits()];
    return if (isValidBodyPointer(body) and body.id == body_id) body else null;
}
/// Access a body, will return a `null` if the `body_id` is no longer valid.
/// Use `PhysicsSystem.getBodiesMut()` to get all the bodies.
/// NOTE: This function is *not* protected by a lock, use with care!
pub inline fn tryGetBodyMut(all_bodies: []const *Body, body_id: BodyId) ?*Body {
    const body = all_bodies[body_id.indexBits()];
    return if (isValidBodyPointer(body) and body.id == body_id) body else null;
}

pub const VTableHeader = switch (@import("builtin").abi) {
    .msvc => extern struct {
        __header: ?*const anyopaque = null,
    },
    else => extern struct {
        __header: [2]?*const anyopaque = [_]?*const anyopaque{null} ** 2,
    },
};

pub fn RefTargetHeader(comptime first_field_align: u29) type {
    return switch (@import("builtin").abi) {
        .msvc => extern struct {
            __vtable_ptr: ?*const anyopaque = null,
            __ref_count: u32 align(first_field_align) = 0,
        },
        else => extern struct {
            __vtable_ptr: ?*const anyopaque = null,
            __ref_count: u32 = 0,
        },
    };
}

fn initInterface(comptime T: type, comptime VTableT: type) *const VTableT {
    const vtable_final = comptime blk: {
        const vtable_info = @typeInfo(VTableT);
        if (vtable_info != .@"struct" or vtable_info.@"struct".layout != .@"extern")
            @compileError("vtable struct " ++ @typeName(VTableT) ++ " must be extern");

        var vtable: VTableT = undefined;
        for (vtable_info.@"struct".fields) |field| {
            const field_info = @typeInfo(field.type);

            var is_opt = false;
            const opt_fn_info: ?std.builtin.Type.Fn = unbox: switch (field_info) {
                .optional => |o| {
                    is_opt = true;
                    continue :unbox @typeInfo(o.child);
                },
                .pointer => |p| continue :unbox @typeInfo(p.child),
                .@"fn" => |f| f,
                else => null,
            };

            if (opt_fn_info) |fn_info| {
                if (is_opt)
                    @compileError("vtable function pointer " ++ field.name ++ " must be non-optional");

                if (!fn_info.calling_convention.eql(std.builtin.CallingConvention.c))
                    @compileError("vtable function pointer " ++ field.name ++ " must be callconv(.c)");

                if (@hasDecl(T, field.name)) {
                    @field(vtable, field.name) = &@field(T, field.name);
                } else {
                    if (is_opt) {
                        @field(vtable, field.name) = null;
                    } else {
                        @compileError(@typeName(T) ++ " is missing `pub fn " ++ field.name ++ "`: " ++ @typeName(@TypeOf(@field(vtable, field.name))));
                    }
                }
            } else {
                if (field.default_value_ptr) |default_value_ptr| {
                    @field(vtable, field.name) = @as(*const field.type, @alignCast(@ptrCast(default_value_ptr))).*;
                } else @compileError("non-pointer vtable field " ++ field.name ++ " must have a default value");
            }
        }
        break :blk vtable;
    };

    return &vtable_final;
}

pub const StreamOut = extern struct {
    __v: *const VTable,

    const VTable = extern struct {
        __header: VTableHeader = .{},
        writeBytes: *const fn (self: *StreamOut, data: [*]const u8, num_bytes: usize) callconv(.c) void,
        isFailed: *const fn (self: *StreamOut) callconv(.c) bool,
    };

    pub fn init(comptime T: type) StreamOut {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub fn writeBytes(self: *StreamOut, data: [*]const u8, num_bytes: usize) void {
        self.__v.writeBytes(self, data, num_bytes);
    }

    pub fn isFailed(self: *StreamOut) bool {
        return self.__v.isFailed(self);
    }

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_StreamOutVTable));
    }
};

pub const AnyWriterStreamOut = extern struct {
    stream_out: StreamOut = .init(@This()),
    writer: *const std.io.AnyWriter,
    failed: bool = false,

    pub fn init(writer: *const std.io.AnyWriter) AnyWriterStreamOut {
        return .{ .writer = writer };
    }

    pub fn writeBytes(stream_out: *StreamOut, data: [*]const u8, num_bytes: usize) callconv(.c) void {
        const self: *AnyWriterStreamOut = @alignCast(@fieldParentPtr("stream_out", stream_out));
        self.writer.writeAll(data[0..num_bytes]) catch {
            self.failed = true;
        };
    }

    pub fn isFailed(stream_out: *StreamOut) callconv(.c) bool {
        const self: *AnyWriterStreamOut = @alignCast(@fieldParentPtr("stream_out", stream_out));
        return self.failed;
    }
};

pub const StreamIn = extern struct {
    __v: *const VTable,

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        readBytes: *const fn (self: *StreamIn, data: [*]u8, num_bytes: usize) callconv(.c) void,
        isEof: *const fn (self: *StreamIn) callconv(.c) bool,
        isFailed: *const fn (self: *StreamIn) callconv(.c) bool,
    };

    pub fn init(comptime T: type) StreamIn {
        return .{ .__v = initInterface(T, VTable) };
    }

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_StreamInVTable));
    }
};

pub const AnyReaderStreamIn = extern struct {
    stream_in: StreamIn = .init(@This()),
    reader: *const std.io.AnyReader,
    failed: bool = false,
    eof: bool = false,

    pub fn init(reader: *const std.io.AnyReader) AnyReaderStreamIn {
        return .{ .reader = reader };
    }

    pub fn readBytes(stream_in: *StreamIn, data: [*]u8, num_bytes: usize) callconv(.c) void {
        const self: *@This() = @alignCast(@fieldParentPtr("stream_in", stream_in));
        self.reader.readNoEof(data[0..num_bytes]) catch |err| switch (err) {
            error.EndOfStream => self.eof = true,
            else => self.failed = true,
        };
    }

    pub fn isEof(stream_in: *StreamIn) callconv(.c) bool {
        const self: *@This() = @alignCast(@fieldParentPtr("stream_in", stream_in));
        return self.eof;
    }

    pub fn isFailed(stream_in: *StreamIn) callconv(.c) bool {
        const self: *@This() = @alignCast(@fieldParentPtr("stream_in", stream_in));
        return self.failed;
    }
};

pub const BroadPhaseLayerInterface = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) BroadPhaseLayerInterface {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        getNumBroadPhaseLayers: *const fn (self: *const BroadPhaseLayerInterface) callconv(.c) u32,
        getBroadPhaseLayer: if (@import("builtin").abi == .msvc)
            *const fn (
                self: *const BroadPhaseLayerInterface,
                out_layer: *BroadPhaseLayer,
                layer: ObjectLayer,
            ) callconv(.c) *const BroadPhaseLayer
        else
            *const fn (
                self: *const BroadPhaseLayerInterface,
                layer: ObjectLayer,
            ) callconv(.c) BroadPhaseLayer,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_BroadPhaseLayerInterfaceVTable));
        assert(@offsetOf(VTable, "getBroadPhaseLayer") == @offsetOf(
            c.JPC_BroadPhaseLayerInterfaceVTable,
            "GetBroadPhaseLayer",
        ));
    }
};

pub const ObjectVsBroadPhaseLayerFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) ObjectVsBroadPhaseLayerFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (
            self: *const ObjectVsBroadPhaseLayerFilter,
            layer1: ObjectLayer,
            layer2: BroadPhaseLayer,
        ) callconv(.c) bool,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_ObjectVsBroadPhaseLayerFilterVTable));
        assert(@offsetOf(VTable, "shouldCollide") == @offsetOf(
            c.JPC_ObjectVsBroadPhaseLayerFilterVTable,
            "ShouldCollide",
        ));
    }
};

pub const BroadPhaseLayerFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) BroadPhaseLayerFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (
            self: *const BroadPhaseLayerFilter,
            layer: BroadPhaseLayer,
        ) callconv(.c) bool,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_BroadPhaseLayerFilterVTable));
        assert(
            @offsetOf(VTable, "shouldCollide") == @offsetOf(c.JPC_BroadPhaseLayerFilterVTable, "ShouldCollide"),
        );
    }
};

pub const ObjectLayerPairFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) ObjectLayerPairFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (self: *const ObjectLayerPairFilter, ObjectLayer, ObjectLayer) callconv(.c) bool,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_ObjectLayerPairFilterVTable));
        assert(
            @offsetOf(VTable, "shouldCollide") == @offsetOf(c.JPC_ObjectLayerPairFilterVTable, "ShouldCollide"),
        );
    }
};

pub const ObjectLayerFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) ObjectLayerFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (self: *const ObjectLayerFilter, ObjectLayer) callconv(.c) bool,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_ObjectLayerFilterVTable));
        assert(@offsetOf(VTable, "shouldCollide") == @offsetOf(c.JPC_ObjectLayerFilterVTable, "ShouldCollide"));
    }
};

pub const PhysicsStepListenerContext = extern struct {
    delta_time: f32,
    is_first_step: bool,
    is_last_step: bool,
    physics_system: *PhysicsSystem,
};

pub const PhysicsStepListener = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) PhysicsStepListener {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        onStep: *const fn (self: *PhysicsStepListener, *const PhysicsStepListenerContext) callconv(.c) void,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_PhysicsStepListenerVTable));
        assert(@offsetOf(VTable, "onStep") == @offsetOf(c.JPC_PhysicsStepListenerVTable, "OnStep"));
    }
};

pub const BodyActivationListener = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) BodyActivationListener {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        onBodyActivated: *const fn (
            self: *BodyActivationListener,
            body_id: *const BodyId,
            user_data: u64,
        ) callconv(.c) void,
        onBodyDeactivated: *const fn (
            self: *BodyActivationListener,
            body_id: *const BodyId,
            user_data: u64,
        ) callconv(.c) void,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_BodyActivationListenerVTable));
        assert(@offsetOf(VTable, "onBodyDeactivated") == @offsetOf(
            c.JPC_BodyActivationListenerVTable,
            "OnBodyDeactivated",
        ));
    }
};

pub const CharacterContactListener = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) CharacterContactListener {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        OnAdjustBodyVelocity: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            body: *const Body,
            io_linear_velocity: *[3]f32,
            io_angular_velocity: *[3]f32,
        ) callconv(.c) void,
        OnContactValidate: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            body: *const Body,
            sub_shape_id: *const SubShapeId,
        ) callconv(.c) bool,
        OnCharacterContactValidate: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            other_character: *const CharacterVirtual,
            sub_shape_id: *const SubShapeId,
        ) callconv(.c) bool,
        OnContactAdded: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            body: *const Body,
            sub_shape_id: *const SubShapeId,
            contact_position: *const [3]Real,
            contact_normal: *const [3]f32,
            io_settings: *CharacterContactSettings,
        ) callconv(.c) void,
        OnCharacterContactAdded: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            other_character: *const CharacterVirtual,
            sub_shape_id: *const SubShapeId,
            contact_position: *const [3]Real,
            contact_normal: *const [3]f32,
            io_settings: *CharacterContactSettings,
        ) callconv(.c) void,
        OnContactSolve: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            body: *const Body,
            sub_shape_id: *const SubShapeId,
            contact_position: *const [3]Real,
            contact_normal: *const [3]f32,
            contact_velocity: *const [3]f32,
            contact_material: *const Material,
            character_velocity: *const [3]f32,
            character_velocity_out: *[3]f32,
        ) callconv(.c) void,
        OnCharacterContactSolve: *const fn (
            self: *CharacterContactListener,
            character: *const CharacterVirtual,
            other_character: *const CharacterVirtual,
            sub_shape_id: *const SubShapeId,
            contact_position: *const [3]Real,
            contact_normal: *const [3]f32,
            contact_velocity: *const [3]f32,
            contact_material: *const Material,
            character_velocity: *const [3]f32,
            character_velocity_out: *[3]f32,
        ) callconv(.c) void,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_CharacterContactListenerVTable));
        assert(@offsetOf(VTable, "OnAdjustBodyVelocity") == @offsetOf(c.JPC_CharacterContactListenerVTable, "OnAdjustBodyVelocity"));
        assert(@offsetOf(VTable, "OnContactSolve") == @offsetOf(c.JPC_CharacterContactListenerVTable, "OnContactSolve"));
    }
};

pub const ContactListener = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) ContactListener {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        onContactValidate: *const fn (
            self: *ContactListener,
            body1: *const Body,
            body2: *const Body,
            base_offset: *const [3]Real,
            collision_result: *const CollideShapeResult,
        ) callconv(.c) ValidateResult,
        onContactAdded: *const fn (
            self: *ContactListener,
            body1: *const Body,
            body2: *const Body,
            manifold: *const ContactManifold,
            settings: *ContactSettings,
        ) callconv(.c) void,
        onContactPersisted: *const fn (
            self: *ContactListener,
            body1: *const Body,
            body2: *const Body,
            manifold: *const ContactManifold,
            settings: *ContactSettings,
        ) callconv(.c) void,
        onContactRemoved: *const fn (
            self: *ContactListener,
            sub_shape_pair: *const SubShapeIdPair,
        ) callconv(.c) void,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_ContactListenerVTable));
        assert(@offsetOf(VTable, "onContactAdded") == @offsetOf(
            c.JPC_ContactListenerVTable,
            "OnContactAdded",
        ));
        assert(
            @offsetOf(VTable, "onContactRemoved") == @offsetOf(c.JPC_ContactListenerVTable, "OnContactRemoved"),
        );
    }
};

pub const BodyFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) BodyFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (self: *const BodyFilter, body_id: *const BodyId) callconv(.c) bool,
        shouldCollideLocked: *const fn (self: *const BodyFilter, body: *const Body) callconv(.c) bool,
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_BodyFilterVTable));
        assert(@offsetOf(VTable, "shouldCollide") == @offsetOf(c.JPC_BodyFilterVTable, "ShouldCollide"));
        assert(
            @offsetOf(VTable, "shouldCollideLocked") == @offsetOf(c.JPC_BodyFilterVTable, "ShouldCollideLocked"),
        );
    }
};

pub const ShapeFilter = extern struct {
    __v: *const VTable,

    pub fn init(comptime T: type) ShapeFilter {
        return .{ .__v = initInterface(T, VTable) };
    }

    pub const VTable = extern struct {
        __header: VTableHeader = .{},
        shouldCollide: *const fn (
            self: *const ShapeFilter,
            shape: *const Shape,
            sub_shape_id: *const SubShapeId,
        ) callconv(.c) bool,
        pairShouldCollide: *const fn (
            self: *const ShapeFilter,
            shape1: *const Shape,
            sub_shape_id1: *const SubShapeId,
            shape2: *const Shape,
            sub_shape_id2: *const SubShapeId,
        ) callconv(.c) bool,
        receiving_body_id: BodyId = .invalid, // set by jolt before each call to either of the functions above
    };

    comptime {
        assert(@sizeOf(VTable) == @sizeOf(c.JPC_ShapeFilterVTable));
        assert(@offsetOf(VTable, "shouldCollide") == @offsetOf(c.JPC_ShapeFilterVTable, "ShouldCollide"));
        assert(@offsetOf(VTable, "receiving_body_id") == @offsetOf(c.JPC_ShapeFilterVTable, "bodyId2"));
    }
};

pub const ContactSettings = extern struct {
    combined_friction: f32,
    combined_restitution: f32,

    inv_mass_scale_1: f32,
    inv_inertia_scale_1: f32,
    inv_mass_scale_2: f32,
    inv_inertia_scale_2: f32,

    is_sensor: bool,

    relative_linear_surface_velocity: [4]f32 align(16), // 4th element is ignored
    relative_angular_surface_velocity: [4]f32 align(16), // 4th element is ignored

    comptime {
        assert(@sizeOf(ContactSettings) == @sizeOf(c.JPC_ContactSettings));
        assert(@offsetOf(ContactSettings, "combined_restitution") == @offsetOf(
            c.JPC_ContactSettings,
            "combined_restitution",
        ));
        assert(@offsetOf(ContactSettings, "relative_angular_surface_velocity") == @offsetOf(
            c.JPC_ContactSettings,
            "relative_angular_surface_velocity",
        ));
    }
};

pub const MassProperties = extern struct {
    mass: f32 = 0.0,
    inertia: [16]f32 align(16) = [_]f32{0} ** 16,

    comptime {
        assert(@sizeOf(MassProperties) == @sizeOf(c.JPC_MassProperties));
        assert(@offsetOf(MassProperties, "inertia") == @offsetOf(c.JPC_MassProperties, "inertia"));
    }
};

pub const SubShapeIdPair = extern struct {
    first: extern struct {
        body_id: BodyId,
        sub_shape_id: SubShapeId,
    },
    second: extern struct {
        body_id: BodyId,
        sub_shape_id: SubShapeId,
    },

    comptime {
        assert(@sizeOf(SubShapeIdPair) == @sizeOf(c.JPC_SubShapeIDPair));
        assert(@offsetOf(SubShapeIdPair, "second") == @offsetOf(c.JPC_SubShapeIDPair, "second"));
    }
};

pub const SubShapeIDCreator = extern struct {
    id: SubShapeId = .empty,
    current_bit: u32 = 0,

    comptime {
        assert(@sizeOf(SubShapeIDCreator) == @sizeOf(c.JPC_SubShapeIDCreator));
        assert(@offsetOf(SubShapeIDCreator, "current_bit") == @offsetOf(c.JPC_SubShapeIDCreator, "current_bit"));
    }
};

pub const CollideShapeResult = extern struct {
    shape1_contact_point: [4]f32 align(16), // 4th element is ignored; world space
    shape2_contact_point: [4]f32 align(16), // 4th element is ignored; world space
    penetration_axis: [4]f32 align(16), // 4th element is ignored; world space
    penetration_depth: f32,
    shape1_sub_shape_id: SubShapeId,
    shape2_sub_shape_id: SubShapeId,
    body2_id: BodyId,
    shape1_face: extern struct {
        num_points: u32 align(16),
        points: [32][4]f32 align(16), // 4th element is ignored; world space
    },
    shape2_face: extern struct {
        num_points: u32 align(16),
        points: [32][4]f32 align(16), // 4th element is ignored; world space
    },

    comptime {
        assert(@sizeOf(CollideShapeResult) == @sizeOf(c.JPC_CollideShapeResult));
        assert(@offsetOf(CollideShapeResult, "shape2_face") == @offsetOf(c.JPC_CollideShapeResult, "shape2_face"));
    }
};

pub const ContactManifold = extern struct {
    base_offset: [4]Real align(rvec_align), // 4th element is ignored; world space
    normal: [4]f32 align(16), // 4th element is ignored; world space
    penetration_depth: f32,
    shape1_sub_shape_id: SubShapeId,
    shape2_sub_shape_id: SubShapeId,
    shape1_relative_contact: extern struct {
        num_points: u32 align(16),
        points: [64][4]f32 align(16), // 4th element is ignored; world space
    },
    shape2_relative_contact: extern struct {
        num_points: u32 align(16),
        points: [64][4]f32 align(16), // 4th element is ignored; world space
    },

    comptime {
        assert(@sizeOf(ContactManifold) == @sizeOf(c.JPC_ContactManifold));
        assert(@offsetOf(ContactManifold, "shape2_relative_contact") ==
            @offsetOf(c.JPC_ContactManifold, "shape2_relative_contact"));
    }
};

pub const CollisionGroup = extern struct {
    filter: ?*GroupFilter = null,
    group_id: GroupId = invalid_group,
    sub_group_id: SubGroupId = invalid_sub_group,

    pub const GroupId = c.JPC_CollisionGroupID;
    pub const SubGroupId = c.JPC_CollisionSubGroupID;

    const invalid_group = @as(GroupId, c.JPC_COLLISION_GROUP_INVALID_GROUP);
    const invalid_sub_group = @as(SubGroupId, c.JPC_COLLISION_GROUP_INVALID_SUB_GROUP);

    comptime {
        assert(@sizeOf(CollisionGroup) == @sizeOf(c.JPC_CollisionGroup));
    }
};

pub const Activation = enum(c.JPC_Activation) {
    activate = c.JPC_ACTIVATION_ACTIVATE,
    dont_activate = c.JPC_ACTIVATION_DONT_ACTIVATE,
};

pub const ValidateResult = enum(c.JPC_ValidateResult) {
    accept_all_contacts = c.JPC_VALIDATE_RESULT_ACCEPT_ALL_CONTACTS,
    accept_contact = c.JPC_VALIDATE_RESULT_ACCEPT_CONTACT,
    reject_contact = c.JPC_VALIDATE_RESULT_REJECT_CONTACT,
    reject_all_contacts = c.JPC_VALIDATE_RESULT_REJECT_ALL_CONTACTS,
};

pub const MotionType = enum(c.JPC_MotionType) {
    static = c.JPC_MOTION_TYPE_STATIC,
    kinematic = c.JPC_MOTION_TYPE_KINEMATIC,
    dynamic = c.JPC_MOTION_TYPE_DYNAMIC,
};

pub const MotionQuality = enum(c.JPC_MotionQuality) {
    discrete = c.JPC_MOTION_QUALITY_DISCRETE,
    linear_cast = c.JPC_MOTION_QUALITY_LINEAR_CAST,
};

/// NOTE: Enum values designed for bitwise combinations in the C tradition
pub const AllowedDOFs = enum(c.JPC_AllowedDOFs) {
    none = c.JPC_ALLOWED_DOFS_NONE, // 0b000000
    all = c.JPC_ALLOWED_DOFS_ALL, // 0b111111
    translation_x = c.JPC_ALLOWED_DOFS_TRANSLATION_X, // 0b000001
    translation_y = c.JPC_ALLOWED_DOFS_TRANSLATION_Y, // 0b000010
    translation_z = c.JPC_ALLOWED_DOFS_TRANSLATION_Z, // 0b000100
    rotation_x = c.JPC_ALLOWED_DOFS_ROTATION_X, // 0b001000
    rotation_y = c.JPC_ALLOWED_DOFS_ROTATION_Y, // 0b010000
    rotation_z = c.JPC_ALLOWED_DOFS_ROTATION_Z, // 0b100000
};

pub const OverrideMassProperties = enum(c.JPC_OverrideMassProperties) {
    calc_mass_inertia = c.JPC_OVERRIDE_MASS_PROPS_CALC_MASS_INERTIA,
    calc_inertia = c.JPC_OVERRIDE_MASS_PROPS_CALC_INERTIA,
    mass_inertia_provided = c.JPC_OVERRIDE_MASS_PROPS_MASS_INERTIA_PROVIDED,
};

pub const CharacterGroundState = enum(c.JPC_CharacterGroundState) {
    on_ground = c.JPC_CHARACTER_GROUND_STATE_ON_GROUND,
    on_steep_ground = c.JPC_CHARACTER_GROUND_STATE_ON_STEEP_GROUND,
    not_supported = c.JPC_CHARACTER_GROUND_STATE_NOT_SUPPORTED,
    in_air = c.JPC_CHARACTER_GROUND_STATE_IN_AIR,
};

pub const BodyCreationSettings = extern struct {
    position: [4]Real align(rvec_align) = .{ 0, 0, 0, 0 }, // 4th element is ignored
    rotation: [4]f32 align(16) = .{ 0, 0, 0, 1 },
    linear_velocity: [4]f32 align(16) = .{ 0, 0, 0, 0 }, // 4th element is ignored
    angular_velocity: [4]f32 align(16) = .{ 0, 0, 0, 0 }, // 4th element is ignored
    user_data: u64 = 0,
    object_layer: ObjectLayer = 0,
    collision_group: CollisionGroup = .{},
    motion_type: MotionType = .dynamic,
    allowed_DOFs: AllowedDOFs = .all,
    allow_dynamic_or_kinematic: bool = false,
    is_sensor: bool = false,
    collide_kinematic_vs_non_dynamic: bool = false,
    use_manifold_reduction: bool = true,
    apply_gyroscopic_force: bool = false,
    motion_quality: MotionQuality = .discrete,
    enhanced_internal_edge_removal: bool = false,
    allow_sleeping: bool = true,
    friction: f32 = 0.2,
    restitution: f32 = 0.0,
    linear_damping: f32 = 0.05,
    angular_damping: f32 = 0.05,
    max_linear_velocity: f32 = 500.0,
    max_angular_velocity: f32 = 0.25 * c.JPC_PI * 60.0,
    gravity_factor: f32 = 1.0,
    num_velocity_steps_override: u32 = 0,
    num_position_steps_override: u32 = 0,
    override_mass_properties: OverrideMassProperties = .calc_mass_inertia,
    inertia_multiplier: f32 = 1.0,
    mass_properties_override: MassProperties = .{},
    reserved: ?*const anyopaque = null,
    shape: ?*const Shape = null,

    comptime {
        assert(@sizeOf(BodyCreationSettings) == @sizeOf(c.JPC_BodyCreationSettings));
        assert(@offsetOf(BodyCreationSettings, "is_sensor") == @offsetOf(c.JPC_BodyCreationSettings, "is_sensor"));
        assert(@offsetOf(BodyCreationSettings, "shape") == @offsetOf(c.JPC_BodyCreationSettings, "shape"));
        assert(@offsetOf(BodyCreationSettings, "user_data") == @offsetOf(c.JPC_BodyCreationSettings, "user_data"));
        assert(@offsetOf(BodyCreationSettings, "motion_quality") ==
            @offsetOf(c.JPC_BodyCreationSettings, "motion_quality"));
        assert(@offsetOf(BodyCreationSettings, "shape") ==
            @offsetOf(c.JPC_BodyCreationSettings, "shape"));
    }
};

pub const CharacterContactSettings = extern struct {
    can_push_character: bool = true,
    can_receive_impulses: bool = true,
};

pub const CharacterBaseSettings = extern struct {
    __header: RefTargetHeader(16),
    up: [4]f32 align(16), // 4th element is ignored
    supporting_volume: [4]f32 align(16), // JPH::Plane - 4th element is used
    max_slope_angle: f32,
    enhanced_internal_edge_removal: bool,
    shape: *Shape, // must provide valid shape (such as the typical capsule)

    comptime {
        assert(@sizeOf(CharacterBaseSettings) == @sizeOf(c.JPC_CharacterBaseSettings));
        assert(@offsetOf(CharacterBaseSettings, "up") == @offsetOf(c.JPC_CharacterBaseSettings, "up"));
        assert(@offsetOf(CharacterBaseSettings, "shape") == @offsetOf(c.JPC_CharacterBaseSettings, "shape"));
    }
};

pub const CharacterSettings = extern struct {
    pub fn create() !*CharacterSettings {
        const settings = c.JPC_CharacterSettings_Create();
        if (settings == null) return error.FailedToCreateCharacterSettings;
        return @as(*CharacterSettings, @ptrCast(settings));
    }
    pub fn release(settings: *CharacterSettings) void {
        c.JPC_CharacterSettings_Release(@as(*c.JPC_CharacterSettings, @ptrCast(settings)));
    }
    pub fn addRef(settings: *CharacterSettings) void {
        c.JPC_CharacterSettings_AddRef(@as(*c.JPC_CharacterSettings, @ptrCast(settings)));
    }

    base: CharacterBaseSettings,
    layer: ObjectLayer,
    mass: f32,
    friction: f32,
    gravity_factor: f32,
    allowed_DOFs: AllowedDOFs,

    comptime {
        assert(@sizeOf(CharacterSettings) == @sizeOf(c.JPC_CharacterSettings));
        assert(@offsetOf(CharacterSettings, "base") == @offsetOf(c.JPC_CharacterSettings, "base"));
        assert(@offsetOf(CharacterSettings, "layer") == @offsetOf(c.JPC_CharacterSettings, "layer"));
        assert(@offsetOf(CharacterSettings, "friction") == @offsetOf(c.JPC_CharacterSettings, "friction"));
    }
};

pub const CharacterVirtualSettings = extern struct {
    pub fn create() !*CharacterVirtualSettings {
        const settings = c.JPC_CharacterVirtualSettings_Create();
        if (settings == null) return error.FailedToCreateCharacterVirtualSettings;
        return @as(*CharacterVirtualSettings, @ptrCast(settings));
    }
    pub fn release(settings: *CharacterVirtualSettings) void {
        c.JPC_CharacterVirtualSettings_Release(@as(*c.JPC_CharacterVirtualSettings, @ptrCast(settings)));
    }

    base: CharacterBaseSettings,
    mass: f32,
    max_strength: f32,
    shape_offset: [4]f32 align(16), // 4th element is ignored
    back_face_mode: BackFaceMode,
    predictive_contact_distance: f32,
    max_collision_iterations: u32,
    max_constraint_iterations: u32,
    min_time_remaining: f32,
    collision_tolerance: f32,
    character_padding: f32,
    max_num_hits: u32,
    hit_reduction_cos_max_angle: f32,
    penetration_recovery_speed: f32,
    inner_body_shape: ?*Shape,
    inner_body_layer: ObjectLayer,

    comptime {
        assert(@sizeOf(CharacterVirtualSettings) == @sizeOf(c.JPC_CharacterVirtualSettings));
        assert(@offsetOf(CharacterVirtualSettings, "base") == @offsetOf(c.JPC_CharacterVirtualSettings, "base"));
        assert(@offsetOf(CharacterVirtualSettings, "mass") == @offsetOf(c.JPC_CharacterVirtualSettings, "mass"));
        assert(@offsetOf(CharacterVirtualSettings, "max_num_hits") ==
            @offsetOf(c.JPC_CharacterVirtualSettings, "max_num_hits"));
        assert(@offsetOf(CharacterVirtualSettings, "inner_body_layer") ==
            @offsetOf(c.JPC_CharacterVirtualSettings, "inner_body_layer"));
    }
};

pub const RayCast = extern struct {
    origin: [4]f32 align(16), // 4th element is ignored
    direction: [4]f32 align(16), // 4th element is ignored

    pub fn getPointOnRay(self: RayCast, fraction: f32) [3]f32 {
        return .{
            self.origin[0] + self.direction[0] * fraction,
            self.origin[1] + self.direction[1] * fraction,
            self.origin[2] + self.direction[2] * fraction,
        };
    }

    comptime {
        assert(@sizeOf(RayCast) == @sizeOf(c.JPC_RayCast));
        assert(@offsetOf(RayCast, "origin") == @offsetOf(c.JPC_RayCast, "origin"));
        assert(@offsetOf(RayCast, "direction") == @offsetOf(c.JPC_RayCast, "direction"));
    }
};

pub const RRayCast = extern struct {
    origin: [4]Real align(rvec_align), // 4th element is ignored
    direction: [4]f32 align(16), // 4th element is ignored

    pub fn getPointOnRay(self: RRayCast, fraction: f32) [3]Real {
        return .{
            self.origin[0] + self.direction[0] * fraction,
            self.origin[1] + self.direction[1] * fraction,
            self.origin[2] + self.direction[2] * fraction,
        };
    }

    comptime {
        assert(@sizeOf(RRayCast) == @sizeOf(c.JPC_RRayCast));
        assert(@offsetOf(RRayCast, "origin") == @offsetOf(c.JPC_RRayCast, "origin"));
        assert(@offsetOf(RRayCast, "direction") == @offsetOf(c.JPC_RRayCast, "direction"));
    }
};

pub const RayCastResult = extern struct {
    body_id: BodyId = .invalid,
    fraction: f32 = 1.0 + flt_epsilon,
    sub_shape_id: SubShapeId = undefined,

    comptime {
        assert(@sizeOf(RayCastResult) == @sizeOf(c.JPC_RayCastResult));
        assert(@offsetOf(RayCastResult, "body_id") == @offsetOf(c.JPC_RayCastResult, "body_id"));
        assert(@offsetOf(RayCastResult, "fraction") == @offsetOf(c.JPC_RayCastResult, "fraction"));
        assert(@offsetOf(RayCastResult, "sub_shape_id") == @offsetOf(c.JPC_RayCastResult, "sub_shape_id"));
    }
};

pub const BackFaceMode = enum(c.JPC_BackFaceMode) {
    ignore_back_faces = c.JPC_BACK_FACE_IGNORE,
    collide_with_back_faces = c.JPC_BACK_FACE_COLLIDE,
};

pub const BodyType = enum(c.JPC_BodyType) {
    rigid_body = c.JPC_BODY_TYPE_RIGID_BODY,
    soft_body = c.JPC_BODY_TYPE_SOFT_BODY,
};

pub const RayCastSettings = extern struct {
    back_face_mode_triangles: BackFaceMode,
    back_face_mode_convex: BackFaceMode,
    treat_convex_as_solid: bool,

    comptime {
        assert(@sizeOf(RayCastSettings) == @sizeOf(c.JPC_RayCastSettings));
        assert(
            @offsetOf(RayCastSettings, "back_face_mode_triangles") == @offsetOf(c.JPC_RayCastSettings, "back_face_mode_triangles"),
        );
        assert(
            @offsetOf(RayCastSettings, "back_face_mode_convex") == @offsetOf(c.JPC_RayCastSettings, "back_face_mode_convex"),
        );
        assert(@offsetOf(RayCastSettings, "treat_convex_as_solid") ==
            @offsetOf(c.JPC_RayCastSettings, "treat_convex_as_solid"));
    }
};

pub const AABox = extern struct {
    min: [4]f32 align(16), // 4th element is ignored
    max: [4]f32 align(16), // 4th element is ignored

    comptime {
        assert(@sizeOf(AABox) == @sizeOf(c.JPC_AABox));
        assert(@offsetOf(AABox, "min") == @offsetOf(c.JPC_AABox, "min"));
        assert(@offsetOf(AABox, "max") == @offsetOf(c.JPC_AABox, "max"));
    }
};

pub const RMatrix = extern struct {
    column_0: [4]f32 align(16),
    column_1: [4]f32 align(16),
    column_2: [4]f32 align(16),
    column_3: [4]Real align(rvec_align),

    comptime {
        assert(@sizeOf(RMatrix) == @sizeOf(c.JPC_RMatrix));
        assert(@offsetOf(RMatrix, "column_1") == @offsetOf(c.JPC_RMatrix, "column_1"));
        assert(@offsetOf(RMatrix, "column_3") == @offsetOf(c.JPC_RMatrix, "column_3"));
    }
};

pub const DebugRenderer = if (!debug_renderer_enabled) extern struct {} else extern struct {
    pub fn initVTable(comptime T: type) *const VTable(T) {
        return initInterface(T, VTable(T));
    }

    pub fn createSingleton(debug_renderer_impl: *anyopaque) !void {
        switch (@as(DebugRendererResult, @enumFromInt(c.JPC_CreateDebugRendererSingleton(debug_renderer_impl)))) {
            .success => {
                return;
            },
            .duplicate_singleton => {
                return error.DebugRendererDuplicateSingleton;
            },
            .missing_singleton => {
                return error.DebugRendererMissingSingleton;
            },
            .incomplete_impl => {
                return error.DebugRendererIncompleteImplementation;
            },
        }
    }

    pub fn destroySingleton() void {
        _ = c.JPC_DestroyDebugRendererSingleton(); // For Zig API, don't care if one actually existed, discard error.
    }

    pub fn createTriangleBatch(primitive_in: *const anyopaque) *TriangleBatch {
        return @ptrCast(c.JPC_DebugRenderer_TriangleBatch_Create(primitive_in));
    }

    pub fn getPrimitiveFromBatch(batch_in: *const TriangleBatch) *const Primitive {
        return @ptrCast(c.JPC_DebugRenderer_TriangleBatch_GetPrimitive(@ptrCast(batch_in)));
    }

    pub fn createBodyDrawFilter(filter_func: BodyDrawFilterFunc) *BodyDrawFilter {
        return @ptrCast(c.JPC_BodyDrawFilter_Create(@ptrCast(filter_func)));
    }

    pub fn destroyBodyDrawFilter(filter: *BodyDrawFilter) void {
        c.JPC_BodyDrawFilter_Destroy(@ptrCast(filter));
    }

    pub fn VTable(comptime T: type) type {
        return extern struct {
            drawLine: *const fn (
                self: *T,
                from: *const [3]Real,
                to: *const [3]Real,
                color: Color,
            ) callconv(.c) void,
            drawTriangle: *const fn (
                self: *T,
                v1: *const [3]Real,
                v2: *const [3]Real,
                v3: *const [3]Real,
                color: Color,
            ) callconv(.c) void,
            /// Implementations should call `DebugRenderer.createTriangleBatch` to
            /// allocate the reference-counted TriangleBatch
            createTriangleBatch: *const fn (
                self: *T,
                triangles: [*]Triangle,
                triangle_count: u32,
            ) callconv(.c) *TriangleBatch,
            /// Implementations should call `DebugRenderer.createTriangleBatch` to
            /// allocate the reference-counted TriangleBatch
            createTriangleBatchIndexed: *const fn (
                self: *T,
                vertices: [*]Vertex,
                vertex_count: u32,
                indices: [*]u32,
                index_count: u32,
            ) callconv(.c) *TriangleBatch,
            /// Will be called when the reference count of the TriangleBatch
            /// returned by the above functions reaches zero. `batch` will be the
            /// value that was passed to `DebugRenderer.createTriangleBatch`.
            destroyTriangleBatch: *const fn (
                self: *T,
                batch: *TriangleBatch,
            ) callconv(.c) void,
            drawGeometry: *const fn (
                self: *T,
                model_matrix: *const RMatrix,
                world_space_bound: *const AABox,
                lod_scale_sq: f32,
                color: Color,
                geometry: *const Geometry,
                cull_mode: CullMode,
                cast_shadow: CastShadow,
                draw_mode: DrawMode,
            ) callconv(.c) void,
            drawText3D: *const fn (
                self: *T,
                positions: *const [3]Real,
                string: [*:0]const u8,
                color: Color,
                height: f32,
            ) callconv(.c) void,
        };
    }

    pub const Color = extern union { uint: u32, comp: extern struct {
        r: u8,
        g: u8,
        b: u8,
        a: u8,
    } };

    pub const Triangle = extern struct {
        v: [3]Vertex,
    };

    pub const Vertex = extern struct {
        position: [3]f32,
        normal: [3]f32,
        uv: [2]f32,
        color: Color,
    };

    pub const LOD = extern struct {
        batch: *TriangleBatch,
        distance: f32,
    };

    pub const Geometry = extern struct {
        LODs: [*]LOD,
        num_LODs: u64,
        bounds: *AABox,
    };

    // zig fmt: off
    pub const BodyDrawSettings = extern struct {
        get_support_func: bool = false,      // Draw the GetSupport() function, used for convex collision detection
        get_support_dir: bool = false,       // If above true, also draw direction mapped to a specific support point
        get_supporting_face: bool = false,   // Draw the faces that were found colliding during collision detection
        shape: bool = true,                  // Draw the shapes of all bodies
        shape_wireframe: bool = false,       // If 'shape' true, the shapes will be drawn in wireframe instead of solid.
        shape_color: ShapeColor = .motion_type_color, // Coloring scheme to use for shapes
        bounding_box: bool = false,          // Draw a bounding box per body
        center_of_mass_transform: bool = false, // Draw the center of mass for each body
        world_transform: bool = false,       // Draw the world transform (which can be different than CoM) for each body
        velocity: bool = false,              // Draw the velocity vector for each body
        mass_and_inertia: bool = false,      // Draw the mass and inertia (as the box equivalent) for each body
        sleep_stats: bool = false,           // Draw stats regarding the sleeping algorithm of each body
    };
    // zig fmt: on

    pub const BodyDrawFilterFunc = *const fn (*const Body) callconv(.c) bool;
    pub const BodyDrawFilter = opaque {};

    pub const TriangleBatch = opaque {};
    pub const Primitive = opaque {};

    pub const DebugRendererResult = enum(c.JPC_DebugRendererResult) {
        success = c.JPC_DEBUGRENDERER_SUCCESS,
        duplicate_singleton = c.JPC_DEBUGRENDERER_DUPLICATE_SINGLETON,
        missing_singleton = c.JPC_DEBUGRENDERER_MISSING_SINGLETON,
        incomplete_impl = c.JPC_DEBUGRENDERER_INCOMPLETE_IMPL,
    };

    // zig fmt: off
    pub const ShapeColor = enum(c.JPC_ShapeColor) {
        instance_color = c.JPC_INSTANCE_COLOR,       // Random color per instance
        shape_type_color = c.JPC_SHAPE_TYPE_COLOR,   // Convex = green, scaled = yellow, compound = orange, mesh = red
        motion_type_color = c.JPC_MOTION_TYPE_COLOR, // Static = grey, keyframed = green, dynamic = random
        sleep_color = c.JPC_SLEEP_COLOR,             // Static = grey, keyframed = green, dynamic = yellow, asleep= red
        island_color = c.JPC_ISLAND_COLOR,           // Static = grey, active = random per island, sleeping = light grey
        material_color = c.JPC_MATERIAL_COLOR,       // Color as defined by the PhysicsMaterial of the shape
    };
    // zig fmt: on

    pub const CullMode = enum(c.JPC_CullMode) {
        cull_back_face = c.JPC_CULL_BACK_FACE,
        cull_front_face = c.JPC_CULL_FRONT_FACE,
        culling_off = c.JPC_CULLING_OFF,
    };

    pub const CastShadow = enum(c.JPC_CastShadow) {
        cast_shadow_on = c.JPC_CAST_SHADOW_ON,
        cast_shadow_off = c.JPC_CAST_SHADOW_OFF,
    };

    pub const DrawMode = enum(c.JPC_DrawMode) {
        draw_mode_solid = c.JPC_DRAW_MODE_SOLID,
        draw_mode_wireframe = c.JPC_DRAW_MODE_WIREFRAME,
    };

    comptime {
        if (debug_renderer_enabled) {
            assert(@sizeOf(VTable(@This())) == @sizeOf(c.JPC_DebugRendererVTable));
            assert(@offsetOf(VTable(@This()), "drawTriangle") == @offsetOf(c.JPC_DebugRendererVTable, "DrawTriangle"));
            assert(@offsetOf(VTable(@This()), "drawText3D") == @offsetOf(c.JPC_DebugRendererVTable, "DrawText3D"));
        }
    }
};
//--------------------------------------------------------------------------------------------------
//
// Init/deinit and global state
//
//--------------------------------------------------------------------------------------------------
const SizeAndAlignment = packed struct(u64) {
    size: u48,
    alignment: u16,
};
const mem_alignment = 16;
pub const GlobalState = struct {
    mem_allocator: std.mem.Allocator,
    mem_allocations: std.AutoHashMap(usize, SizeAndAlignment),
    mem_mutex: std.Thread.Mutex = .{},

    temp_allocator: *TempAllocator,
    job_system: *JobSystem,
};
var state: ?GlobalState = null;

pub const TraceFunc = *const fn (fmt: ?[*:0]const u8, ...) callconv(.c) void;
pub const AssertFailedFunc = *const fn (
    expression: ?[*:0]const u8,
    message: ?[*:0]const u8,
    file: ?[*:0]const u8,
    line: u32,
) callconv(.c) bool;

pub fn init(allocator: std.mem.Allocator, args: struct {
    temp_allocator_size: u32 = 16 * 1024 * 1024,
    max_jobs: u32 = max_physics_jobs,
    max_barriers: u32 = max_physics_barriers,
    num_threads: i32 = -1,
}) !void {
    std.debug.assert(state == null);

    state = .{
        .mem_allocator = allocator,
        .mem_allocations = std.AutoHashMap(usize, SizeAndAlignment).init(allocator),
        .temp_allocator = undefined,
        .job_system = undefined,
    };

    state.?.mem_allocations.ensureTotalCapacity(32) catch unreachable;

    c.JPC_RegisterCustomAllocator(zphysicsAlloc, zphysicsRealloc, zphysicsFree, zphysicsAlignedAlloc, zphysicsFree);

    c.JPC_CreateFactory();
    c.JPC_RegisterTypes();

    state.?.temp_allocator = @as(*TempAllocator, @ptrCast(c.JPC_TempAllocator_Create(args.temp_allocator_size)));
    state.?.job_system = @as(*JobSystem, @ptrCast(c.JPC_JobSystem_Create(args.max_jobs, args.max_barriers, args.num_threads)));
}

pub fn preReload() GlobalState {
    const tmp = state.?;
    state = null;
    return tmp;
}

pub fn postReload(allocator: std.mem.Allocator, prev_state: GlobalState) void {
    std.debug.assert(state == null);

    state = prev_state;
    state.?.mem_allocator = allocator;
    state.?.mem_allocations.allocator = allocator;

    c.JPC_RegisterCustomAllocator(zphysicsAlloc, zphysicsRealloc, zphysicsFree, zphysicsAlignedAlloc, zphysicsFree);
}

pub fn deinit() void {
    c.JPC_JobSystem_Destroy(@as(*c.JPC_JobSystem, @ptrCast(state.?.job_system)));
    c.JPC_TempAllocator_Destroy(@as(*c.JPC_TempAllocator, @ptrCast(state.?.temp_allocator)));
    c.JPC_DestroyFactory();

    state.?.mem_allocations.deinit();
    state = null;
}

pub fn registerTrace(trace: ?TraceFunc) void {
    c.JPC_RegisterTrace(trace);
}

pub fn registerAssertFailed(assert_failed: ?AssertFailedFunc) void {
    c.JPC_RegisterAssertFailed(assert_failed);
}
//--------------------------------------------------------------------------------------------------
//
// PhysicsSystem
//
//--------------------------------------------------------------------------------------------------
pub const PhysicsSystem = opaque {
    pub fn create(
        broad_phase_layer_interface: *const BroadPhaseLayerInterface,
        object_vs_broad_phase_layer_filter: *const ObjectVsBroadPhaseLayerFilter,
        object_layer_pair_filter: *const ObjectLayerPairFilter,
        args: struct {
            max_bodies: u32 = 1024,
            num_body_mutexes: u32 = 0,
            max_body_pairs: u32 = 1024,
            max_contact_constraints: u32 = 1024,
        },
    ) !*PhysicsSystem {
        return @as(*PhysicsSystem, @ptrCast(c.JPC_PhysicsSystem_Create(
            args.max_bodies,
            args.num_body_mutexes,
            args.max_body_pairs,
            args.max_contact_constraints,
            broad_phase_layer_interface,
            object_vs_broad_phase_layer_filter,
            object_layer_pair_filter,
        )));
    }

    pub fn destroy(physics_system: *PhysicsSystem) void {
        c.JPC_PhysicsSystem_Destroy(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }

    pub fn getNumBodies(physics_system: *const PhysicsSystem) u32 {
        return c.JPC_PhysicsSystem_GetNumBodies(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }
    pub fn getNumActiveBodies(physics_system: *const PhysicsSystem) u32 {
        return c.JPC_PhysicsSystem_GetNumActiveBodies(
            @as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)),
            @intFromEnum(BodyType.rigid_body),
        );
    }
    pub fn getMaxBodies(physics_system: *const PhysicsSystem) u32 {
        return c.JPC_PhysicsSystem_GetMaxBodies(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }

    pub fn getGravity(physics_system: *const PhysicsSystem) [3]f32 {
        var gravity: [3]f32 = undefined;
        c.JPC_PhysicsSystem_GetGravity(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)), &gravity);
        return gravity;
    }
    pub fn setGravity(physics_system: *PhysicsSystem, gravity: [3]f32) void {
        c.JPC_PhysicsSystem_SetGravity(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), &gravity);
    }

    pub fn getBodyInterface(physics_system: *const PhysicsSystem) *const BodyInterface {
        return @as(
            *const BodyInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyInterface(@as(*c.JPC_PhysicsSystem, @ptrFromInt(@intFromPtr(physics_system))))),
        );
    }
    pub fn getBodyInterfaceNoLock(physics_system: *const PhysicsSystem) *const BodyInterface {
        return @as(
            *const BodyInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyInterfaceNoLock(@as(*c.JPC_PhysicsSystem, @ptrFromInt(@intFromPtr(physics_system))))),
        );
    }
    pub fn getBodyInterfaceMut(physics_system: *PhysicsSystem) *BodyInterface {
        return @as(
            *BodyInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyInterface(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }
    pub fn getBodyInterfaceMutNoLock(physics_system: *PhysicsSystem) *BodyInterface {
        return @as(
            *BodyInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyInterfaceNoLock(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }

    pub fn getNarrowPhaseQuery(physics_system: *const PhysicsSystem) *const NarrowPhaseQuery {
        return @as(
            *const NarrowPhaseQuery,
            @ptrCast(c.JPC_PhysicsSystem_GetNarrowPhaseQuery(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }
    pub fn getNarrowPhaseQueryNoLock(physics_system: *const PhysicsSystem) *const NarrowPhaseQuery {
        return @as(
            *const NarrowPhaseQuery,
            @ptrCast(c.JPC_PhysicsSystem_GetNarrowPhaseQueryNoLock(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }

    pub fn getBodyLockInterface(physics_system: *const PhysicsSystem) *const BodyLockInterface {
        return @as(
            *const BodyLockInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyLockInterface(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }
    pub fn getBodyLockInterfaceNoLock(physics_system: *const PhysicsSystem) *const BodyLockInterface {
        return @as(
            *const BodyLockInterface,
            @ptrCast(c.JPC_PhysicsSystem_GetBodyLockInterfaceNoLock(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)))),
        );
    }

    pub fn setBodyActivationListener(physics_system: *PhysicsSystem, listener: ?*anyopaque) void {
        c.JPC_PhysicsSystem_SetBodyActivationListener(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), listener);
    }
    pub fn getBodyActivationListener(physics_system: *const PhysicsSystem) ?*anyopaque {
        return c.JPC_PhysicsSystem_GetBodyActivationListener(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }

    pub fn setContactListener(physics_system: *PhysicsSystem, listener: ?*anyopaque) void {
        c.JPC_PhysicsSystem_SetContactListener(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), listener);
    }
    pub fn getContactListener(physics_system: *const PhysicsSystem) ?*anyopaque {
        return c.JPC_PhysicsSystem_GetContactListener(@as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }

    pub fn optimizeBroadPhase(physics_system: *PhysicsSystem) void {
        c.JPC_PhysicsSystem_OptimizeBroadPhase(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)));
    }

    pub fn addStepListener(physics_system: *PhysicsSystem, listener: ?*anyopaque) void {
        c.JPC_PhysicsSystem_AddStepListener(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), listener);
    }
    pub fn removeStepListener(physics_system: *PhysicsSystem, listener: ?*anyopaque) void {
        c.JPC_PhysicsSystem_RemoveStepListener(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), listener);
    }

    pub fn addConstraint(physics_system: *PhysicsSystem, constraint: ?*Constraint) void {
        c.JPC_PhysicsSystem_AddConstraint(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), @ptrCast(constraint));
    }
    pub fn removeConstraint(physics_system: *PhysicsSystem, constraint: ?*Constraint) void {
        c.JPC_PhysicsSystem_RemoveConstraint(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)), @ptrCast(constraint));
    }

    pub fn update(
        physics_system: *PhysicsSystem,
        delta_time: f32,
        args: struct {
            collision_steps: i32 = 1,
        },
    ) !void {
        const res = c.JPC_PhysicsSystem_Update(
            @as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)),
            delta_time,
            args.collision_steps,
            @as(*c.JPC_TempAllocator, @ptrCast(state.?.temp_allocator)),
            @as(*c.JPC_JobSystem, @ptrCast(state.?.job_system)),
        );

        switch (res) {
            c.JPC_PHYSICS_UPDATE_NO_ERROR => {},
            c.JPC_PHYSICS_UPDATE_MANIFOLD_CACHE_FULL => return error.ManifoldCacheFull,
            c.JPC_PHYSICS_UPDATE_BODY_PAIR_CACHE_FULL => return error.BodyPairCacheFull,
            c.JPC_PHYSICS_UPDATE_CONTACT_CONSTRAINTS_FULL => return error.ContactConstraintsFull,
            else => return error.Unknown,
        }
    }

    pub const drawBodies = if (debug_renderer_enabled) _drawBodies else void;
    pub const drawConstraints = if (debug_renderer_enabled) _drawConstraints else void;
    pub const drawConstraintLimits = if (debug_renderer_enabled) _drawConstraintLimits else void;
    pub const drawConstraintReferenceFrame = if (debug_renderer_enabled) _drawConstraintReferenceFrame else void;

    fn _drawBodies(
        physics_system: *PhysicsSystem,
        in_draw_settings: *const DebugRenderer.BodyDrawSettings,
        in_draw_filter: ?*const DebugRenderer.BodyDrawFilter,
    ) void {
        c.JPC_PhysicsSystem_DrawBodies(@ptrCast(physics_system), @ptrCast(in_draw_settings), @ptrCast(in_draw_filter));
    }

    fn _drawConstraints(physics_system: *PhysicsSystem) void {
        c.JPC_PhysicsSystem_DrawConstraints(@ptrCast(physics_system));
    }

    fn _drawConstraintLimits(physics_system: *PhysicsSystem) void {
        c.JPC_PhysicsSystem_DrawConstraintLimits(@ptrCast(physics_system));
    }

    fn _drawConstraintReferenceFrame(physics_system: *PhysicsSystem) void {
        c.JPC_PhysicsSystem_DrawConstraintReferenceFrame(@ptrCast(physics_system));
    }

    pub fn getBodyIds(physics_system: *const PhysicsSystem, body_ids: *std.ArrayList(BodyId)) !void {
        try body_ids.ensureTotalCapacityPrecise(physics_system.getMaxBodies());
        var num_body_ids: u32 = 0;
        c.JPC_PhysicsSystem_GetBodyIDs(
            @as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)),
            @as(u32, @intCast(body_ids.capacity)),
            &num_body_ids,
            @ptrCast(body_ids.items.ptr),
        );
        body_ids.items.len = num_body_ids;
    }

    pub fn getActiveBodyIds(physics_system: *const PhysicsSystem, body_ids: *std.ArrayList(BodyId)) !void {
        try body_ids.ensureTotalCapacityPrecise(physics_system.getMaxBodies());
        var num_body_ids: u32 = 0;
        c.JPC_PhysicsSystem_GetActiveBodyIDs(
            @as(*const c.JPC_PhysicsSystem, @ptrCast(physics_system)),
            @as(u32, @intCast(body_ids.capacity)),
            &num_body_ids,
            @ptrCast(body_ids.items.ptr),
        );
        body_ids.items.len = num_body_ids;
    }

    /// NOTE: Advanced. This function is *not* protected by a lock, use with care!
    pub fn getBodiesUnsafe(physics_system: *const PhysicsSystem) []const *const Body {
        const ptr = c.JPC_PhysicsSystem_GetBodiesUnsafe(
            @as(*c.JPC_PhysicsSystem, @ptrFromInt(@intFromPtr(physics_system))),
        );
        return @as([*]const *const Body, @ptrCast(ptr))[0..physics_system.getNumBodies()];
    }
    /// NOTE: Advanced. This function is *not* protected by a lock, use with care!
    pub fn getBodiesMutUnsafe(physics_system: *PhysicsSystem) []const *Body {
        const ptr = c.JPC_PhysicsSystem_GetBodiesUnsafe(@as(*c.JPC_PhysicsSystem, @ptrCast(physics_system)));
        return @as([*]const *Body, @ptrCast(ptr))[0..physics_system.getNumBodies()];
    }
};
//--------------------------------------------------------------------------------------------------
//
// BodyLock*
//
//--------------------------------------------------------------------------------------------------
pub const BodyLockRead = extern struct {
    lock_interface: *const BodyLockInterface = undefined,
    mutex: ?*SharedMutex = null,
    body: ?*const Body = null,

    pub fn lock(
        read_lock: *BodyLockRead,
        lock_interface: *const BodyLockInterface,
        body_id: BodyId,
    ) void {
        c.JPC_BodyLockInterface_LockRead(
            @as(*const c.JPC_BodyLockInterface, @ptrCast(lock_interface)),
            body_id.toJpc(),
            @as(*c.JPC_BodyLockRead, @ptrCast(read_lock)),
        );
    }

    pub fn unlock(read_lock: *BodyLockRead) void {
        c.JPC_BodyLockInterface_UnlockRead(
            @as(*const c.JPC_BodyLockInterface, @ptrCast(read_lock.lock_interface)),
            @as(*c.JPC_BodyLockRead, @ptrCast(read_lock)),
        );
    }

    comptime {
        assert(@sizeOf(BodyLockRead) == @sizeOf(c.JPC_BodyLockRead));
        assert(@offsetOf(BodyLockRead, "mutex") == @offsetOf(c.JPC_BodyLockRead, "mutex"));
        assert(@offsetOf(BodyLockRead, "body") == @offsetOf(c.JPC_BodyLockRead, "body"));
    }
};

pub const BodyLockWrite = extern struct {
    lock_interface: *const BodyLockInterface = undefined,
    mutex: ?*SharedMutex = null,
    body: ?*Body = null,

    pub fn lock(
        write_lock: *BodyLockWrite,
        lock_interface: *const BodyLockInterface,
        body_id: BodyId,
    ) void {
        c.JPC_BodyLockInterface_LockWrite(
            @as(*const c.JPC_BodyLockInterface, @ptrCast(lock_interface)),
            body_id.toJpc(),
            @as(*c.JPC_BodyLockWrite, @ptrCast(write_lock)),
        );
    }

    pub fn unlock(write_lock: *BodyLockWrite) void {
        c.JPC_BodyLockInterface_UnlockWrite(
            @as(*const c.JPC_BodyLockInterface, @ptrCast(write_lock.lock_interface)),
            @as(*c.JPC_BodyLockWrite, @ptrCast(write_lock)),
        );
    }

    comptime {
        assert(@sizeOf(BodyLockWrite) == @sizeOf(c.JPC_BodyLockWrite));
        assert(@offsetOf(BodyLockWrite, "mutex") == @offsetOf(c.JPC_BodyLockWrite, "mutex"));
        assert(@offsetOf(BodyLockWrite, "body") == @offsetOf(c.JPC_BodyLockWrite, "body"));
    }
};
//--------------------------------------------------------------------------------------------------
//
// BodyInterface
//
//--------------------------------------------------------------------------------------------------
pub const BodyInterface = opaque {
    pub fn createBody(body_iface: *BodyInterface, settings: BodyCreationSettings) !*Body {
        const body = c.JPC_BodyInterface_CreateBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            @as(*const c.JPC_BodyCreationSettings, @ptrCast(&settings)),
        );
        if (body == null)
            return error.FailedToCreateBody;
        return @as(*Body, @ptrCast(body));
    }

    pub fn createBodyWithId(body_iface: *BodyInterface, body_id: BodyId, settings: BodyCreationSettings) !*Body {
        const body = c.JPC_BodyInterface_CreateBodyWithID(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            @as(*const c.JPC_BodyCreationSettings, @ptrCast(&settings)),
        );
        if (body == null)
            return error.FailedToCreateBody;
        return @as(*Body, @ptrCast(body));
    }

    pub fn destroyBody(body_iface: *BodyInterface, body_id: BodyId) void {
        c.JPC_BodyInterface_DestroyBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn addBody(body_iface: *BodyInterface, body_id: BodyId, mode: Activation) void {
        c.JPC_BodyInterface_AddBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            @intFromEnum(mode),
        );
    }

    pub fn removeBody(body_iface: *BodyInterface, body_id: BodyId) void {
        c.JPC_BodyInterface_RemoveBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn createAndAddBody(body_iface: *BodyInterface, settings: BodyCreationSettings, mode: Activation) !BodyId {
        const body_id: BodyId = @enumFromInt(c.JPC_BodyInterface_CreateAndAddBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            @as(*const c.JPC_BodyCreationSettings, @ptrCast(&settings)),
            @intFromEnum(mode),
        ).id);
        if (body_id == .invalid)
            return error.FailedToCreateBody;
        return body_id;
    }

    pub fn removeAndDestroyBody(body_iface: *BodyInterface, body_id: BodyId) void {
        body_iface.removeBody(body_id);
        body_iface.destroyBody(body_id);
    }

    pub fn isAdded(body_iface: *const BodyInterface, body_id: BodyId) bool {
        return c.JPC_BodyInterface_IsAdded(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn activate(body_iface: *BodyInterface, body_id: BodyId) void {
        return c.JPC_BodyInterface_ActivateBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn activateBodies(body_iface: *BodyInterface, body_ids: []const BodyId) void {
        return c.JPC_BodyInterface_ActivateBodies(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            @ptrCast(body_ids.ptr),
            @intCast(body_ids.len),
        );
    }

    pub fn deactivate(body_iface: *BodyInterface, body_id: BodyId) void {
        return c.JPC_BodyInterface_DeactivateBody(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn deactivateBodies(body_iface: *BodyInterface, body_ids: []const BodyId) void {
        return c.JPC_BodyInterface_DeactivateBodies(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            @ptrCast(body_ids.ptr),
            @intCast(body_ids.len),
        );
    }

    pub fn isActive(body_iface: *const BodyInterface, body_id: BodyId) bool {
        return c.JPC_BodyInterface_IsActive(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn setLinearAndAngularVelocity(
        body_iface: *BodyInterface,
        body_id: BodyId,
        linear_velocity: [3]f32,
        angular_velocity: [3]f32,
    ) void {
        return c.JPC_BodyInterface_SetLinearAndAngularVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &linear_velocity,
            &angular_velocity,
        );
    }
    pub fn getLinearAndAngularVelocity(
        body_iface: *const BodyInterface,
        body_id: BodyId,
    ) struct { linear: [3]f32, angular: [3]f32 } {
        var linear: [3]f32 = undefined;
        var angular: [3]f32 = undefined;
        c.JPC_BodyInterface_GetLinearAndAngularVelocity(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &linear,
            &angular,
        );
        return .{ .linear = linear, .angular = angular };
    }

    pub fn setLinearVelocity(body_iface: *BodyInterface, body_id: BodyId, velocity: [3]f32) void {
        return c.JPC_BodyInterface_SetLinearVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &velocity,
        );
    }
    pub fn getLinearVelocity(body_iface: *const BodyInterface, body_id: BodyId) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_BodyInterface_GetLinearVelocity(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &velocity,
        );
        return velocity;
    }

    pub fn addLinearVelocity(body_iface: *BodyInterface, body_id: BodyId, velocity: [3]f32) void {
        return c.JPC_BodyInterface_AddLinearVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &velocity,
        );
    }

    pub fn addLinearAndAngularVelocity(
        body_iface: *BodyInterface,
        body_id: BodyId,
        linear_velocity: [3]f32,
        angular_velocity: [3]f32,
    ) void {
        return c.JPC_BodyInterface_AddLinearAndAngularVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &linear_velocity,
            &angular_velocity,
        );
    }

    pub fn setAngularVelocity(body_iface: *BodyInterface, body_id: BodyId, velocity: [3]f32) void {
        return c.JPC_BodyInterface_SetAngularVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &velocity,
        );
    }
    pub fn getAngularVelocity(body_iface: *const BodyInterface, body_id: BodyId) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_BodyInterface_GetAngularVelocity(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &velocity,
        );
        return velocity;
    }

    pub fn getPointVelocity(body_iface: *const BodyInterface, body_id: BodyId, point: [3]Real) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_BodyInterface_GetPointVelocity(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &point,
            &velocity,
        );
        return velocity;
    }

    pub fn getPosition(body_iface: *const BodyInterface, body_id: BodyId) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_BodyInterface_GetPosition(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &position,
        );
        return position;
    }

    pub fn setPosition(body_iface: *BodyInterface, body_id: BodyId, in_position: [3]Real, in_activation_type: Activation) void {
        c.JPC_BodyInterface_SetPosition(@as(*c.JPC_BodyInterface, @ptrCast(body_iface)), body_id.toJpc(), &in_position, @intFromEnum(in_activation_type));
    }

    pub fn getCenterOfMassPosition(body_iface: *const BodyInterface, body_id: BodyId) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_BodyInterface_GetCenterOfMassPosition(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &position,
        );
        return position;
    }

    pub fn getRotation(body_iface: *const BodyInterface, body_id: BodyId) [4]f32 {
        var rotation: [4]f32 = undefined;
        c.JPC_BodyInterface_GetRotation(
            @as(*const c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &rotation,
        );
        return rotation;
    }

    pub fn setRotation(body_iface: *BodyInterface, body_id: BodyId, in_rotation: [4]f32, in_activation_type: Activation) void {
        c.JPC_BodyInterface_SetRotation(@as(*c.JPC_BodyInterface, @ptrCast(body_iface)), body_id.toJpc(), &in_rotation, @intFromEnum(in_activation_type));
    }

    pub fn setPositionRotationAndVelocity(
        body_iface: *BodyInterface,
        body_id: BodyId,
        position: [3]Real,
        rotation: [4]f32,
        linear_velocity: [3]f32,
        angular_velocity: [3]f32,
    ) void {
        return c.JPC_BodyInterface_SetPositionRotationAndVelocity(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &position,
            &rotation,
            &linear_velocity,
            &angular_velocity,
        );
    }

    pub fn addForce(body_iface: *BodyInterface, body_id: BodyId, force: [3]f32) void {
        return c.JPC_BodyInterface_AddForce(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &force,
        );
    }
    pub fn addForceAtPosition(body_iface: *BodyInterface, body_id: BodyId, force: [3]f32, position: [3]Real) void {
        return c.JPC_BodyInterface_AddForceAtPosition(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &force,
            &position,
        );
    }

    pub fn addTorque(body_iface: *BodyInterface, body_id: BodyId, torque: [3]f32) void {
        return c.JPC_BodyInterface_AddTorque(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &torque,
        );
    }
    pub fn addForceAndTorque(body_iface: *BodyInterface, body_id: BodyId, force: [3]f32, torque: [3]f32) void {
        return c.JPC_BodyInterface_AddForceAndTorque(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &force,
            &torque,
        );
    }

    pub fn addImpulse(body_iface: *BodyInterface, body_id: BodyId, impulse: [3]f32) void {
        return c.JPC_BodyInterface_AddImpulse(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &impulse,
        );
    }
    pub fn addImpulseAtPosition(
        body_iface: *BodyInterface,
        body_id: BodyId,
        impulse: [3]f32,
        position: [3]Real,
    ) void {
        return c.JPC_BodyInterface_AddImpulseAtPosition(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &impulse,
            &position,
        );
    }

    pub fn addAngularImpulse(body_iface: *BodyInterface, body_id: BodyId, impulse: [3]f32) void {
        return c.JPC_BodyInterface_AddAngularImpulse(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            &impulse,
        );
    }

    pub fn getMotionType(body_iface: *const BodyInterface, body_id: BodyId) MotionType {
        return @as(MotionType, @enumFromInt(
            c.JPC_BodyInterface_GetMotionType(
                @ptrCast(body_iface),
                body_id.toJpc(),
            ),
        ));
    }

    pub fn setMotionType(body_iface: *BodyInterface, body_id: BodyId, in_motion_type: MotionType, in_activation_type: Activation) void {
        return c.JPC_BodyInterface_SetMotionType(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            @intFromEnum(in_motion_type),
            @intFromEnum(in_activation_type),
        );
    }

    pub fn getObjectLayer(body_iface: *BodyInterface, body_id: BodyId) ObjectLayer {
        return c.JPC_BodyInterface_GetObjectLayer(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
        );
    }

    pub fn setObjectLayer(body_iface: *BodyInterface, body_id: BodyId, in_layer: ObjectLayer) void {
        c.JPC_BodyInterface_SetObjectLayer(
            @as(*c.JPC_BodyInterface, @ptrCast(body_iface)),
            body_id.toJpc(),
            in_layer,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// NarrowPhaseQuery
//
//--------------------------------------------------------------------------------------------------
pub const NarrowPhaseQuery = opaque {
    pub fn castRay(
        query: *const NarrowPhaseQuery,
        ray: RRayCast,
        args: struct {
            broad_phase_layer_filter: ?*const BroadPhaseLayerFilter = null,
            object_layer_filter: ?*const ObjectLayerFilter = null,
            body_filter: ?*const BodyFilter = null,
        },
    ) struct { has_hit: bool, hit: RayCastResult } {
        var hit: RayCastResult = .{};
        const has_hit = c.JPC_NarrowPhaseQuery_CastRay(
            @as(*const c.JPC_NarrowPhaseQuery, @ptrCast(query)),
            @as(*const c.JPC_RRayCast, @ptrCast(&ray)),
            @as(*c.JPC_RayCastResult, @ptrCast(&hit)),
            args.broad_phase_layer_filter,
            args.object_layer_filter,
            args.body_filter,
        );
        return .{ .has_hit = has_hit, .hit = hit };
    }
};
//--------------------------------------------------------------------------------------------------
//
// Body
//
//--------------------------------------------------------------------------------------------------
pub const Body = extern struct {
    position: [4]Real align(rvec_align), // 4th element is ignored
    rotation: [4]f32 align(16),
    bounds_min: [4]f32 align(16), // 4th element is ignored
    bounds_max: [4]f32 align(16), // 4th element is ignored

    shape: *const Shape,
    motion_properties: ?*MotionProperties, // Will be null for static objects
    user_data: u64,
    collision_group: CollisionGroup,

    friction: f32,
    restitution: f32,
    id: BodyId,

    object_layer: ObjectLayer,

    body_type: BodyType,
    broad_phase_layer: BroadPhaseLayer,
    motion_type: MotionType,
    flags: u8,

    pub fn getId(body: *const Body) BodyId {
        return @enumFromInt(c.JPC_Body_GetID(@as(*const c.JPC_Body, @ptrCast(body))).id);
    }

    pub fn isActive(body: *const Body) bool {
        return c.JPC_Body_IsActive(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn isStatic(body: *const Body) bool {
        return c.JPC_Body_IsStatic(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn isKinematic(body: *const Body) bool {
        return c.JPC_Body_IsKinematic(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn isDynamic(body: *const Body) bool {
        return c.JPC_Body_IsDynamic(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn canBeKinematicOrDynamic(body: *const Body) bool {
        return c.JPC_Body_CanBeKinematicOrDynamic(@as(*const c.JPC_Body, @ptrCast(body)));
    }

    pub fn isSensor(body: *const Body) bool {
        return c.JPC_Body_IsSensor(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn setIsSensor(body: *Body, is_sensor: bool) void {
        c.JPC_Body_SetIsSensor(@as(*c.JPC_Body, @ptrCast(body)), is_sensor);
    }

    pub fn getMotionType(body: *const Body) MotionType {
        return @as(MotionType, @enumFromInt(c.JPC_Body_GetMotionType(@as(*const c.JPC_Body, @ptrCast(body)))));
    }
    pub fn setMotionType(body: *Body, motion_type: MotionType) void {
        return c.JPC_Body_SetMotionType(@as(*c.JPC_Body, @ptrCast(body)), @intFromEnum(motion_type));
    }

    pub fn getBroadPhaseLayer(body: *const Body) BroadPhaseLayer {
        return c.JPC_Body_GetBroadPhaseLayer(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn getObjectLayer(body: *const Body) ObjectLayer {
        return c.JPC_Body_GetObjectLayer(@as(*const c.JPC_Body, @ptrCast(body)));
    }

    pub fn getCollisionGroup(body: *const Body) *const CollisionGroup {
        return @as(
            *const CollisionGroup,
            @ptrCast(c.JPC_Body_GetCollisionGroup(@as(*c.JPC_Body, @ptrFromInt(@intFromPtr(body))))),
        );
    }
    pub fn getCollisionGroupMut(body: *Body) *CollisionGroup {
        return @as(
            *CollisionGroup,
            @ptrCast(c.JPC_Body_GetCollisionGroup(@as(*c.JPC_Body, @ptrCast(body)))),
        );
    }
    pub fn setCollisionGroup(body: *Body, group: CollisionGroup) void {
        c.JPC_Body_SetCollisionGroup(
            @as(*c.JPC_Body, @ptrCast(body)),
            @as(*const c.JPC_CollisionGroup, @ptrCast(&group)),
        );
    }

    pub fn getAllowSleeping(body: *const Body) bool {
        return c.JPC_Body_GetAllowSleeping(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn setAllowSleeping(body: *Body, allow: bool) void {
        c.JPC_Body_SetAllowSleeping(@as(*c.JPC_Body, @ptrCast(body)), allow);
    }

    pub fn getFriction(body: *const Body) f32 {
        return c.JPC_Body_GetFriction(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn setFriction(body: *Body, friction: f32) void {
        c.JPC_Body_SetFriction(@as(*c.JPC_Body, @ptrCast(body)), friction);
    }

    pub fn getRestitution(body: *const Body) f32 {
        return c.JPC_Body_GetRestitution(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn setRestitution(body: *Body, restitution: f32) void {
        c.JPC_Body_SetRestitution(@as(*c.JPC_Body, @ptrCast(body)), restitution);
    }

    pub fn getLinearVelocity(body: *const Body) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_Body_GetLinearVelocity(@as(*const c.JPC_Body, @ptrCast(body)), &velocity);
        return velocity;
    }
    pub fn setLinearVelocity(body: *Body, velocity: [3]f32) void {
        c.JPC_Body_SetLinearVelocity(@as(*c.JPC_Body, @ptrCast(body)), &velocity);
    }
    pub fn setLinearVelocityClamped(body: *Body, velocity: [3]f32) void {
        c.JPC_Body_SetLinearVelocityClamped(@as(*c.JPC_Body, @ptrCast(body)), &velocity);
    }

    pub fn getAngularVelocity(body: *const Body) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_Body_GetAngularVelocity(@as(*const c.JPC_Body, @ptrCast(body)), &velocity);
        return velocity;
    }
    pub fn setAngularVelocity(body: *Body, velocity: [3]f32) void {
        c.JPC_Body_SetAngularVelocity(@as(*c.JPC_Body, @ptrCast(body)), &velocity);
    }
    pub fn setAngularVelocityClamped(body: *Body, velocity: [3]f32) void {
        c.JPC_Body_SetAngularVelocityClamped(@as(*c.JPC_Body, @ptrCast(body)), &velocity);
    }

    /// `point` is relative to the center of mass (com)
    pub fn getPointVelocityCom(body: *const Body, point: [3]f32) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_Body_GetPointVelocityCOM(@as(*const c.JPC_Body, @ptrCast(body)), &point, &velocity);
        return velocity;
    }
    /// `point` is in the world space
    pub fn getPointVelocity(body: *const Body, point: [3]Real) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_Body_GetPointVelocity(@as(*const c.JPC_Body, @ptrCast(body)), &point, &velocity);
        return velocity;
    }

    pub fn addForce(body: *Body, force: [3]f32) void {
        c.JPC_Body_AddForce(@as(*c.JPC_Body, @ptrCast(body)), &force);
    }
    pub fn addForceAtPosition(body: *Body, force: [3]f32, position: [3]Real) void {
        c.JPC_Body_AddForceAtPosition(@as(*c.JPC_Body, @ptrCast(body)), &force, &position);
    }

    pub fn addTorque(body: *Body, torque: [3]f32) void {
        c.JPC_Body_AddTorque(@as(*c.JPC_Body, @ptrCast(body)), &torque);
    }

    pub fn getInverseInertia(body: *const Body) [16]f32 {
        var inverse_inertia: [16]f32 = undefined;
        c.JPC_Body_GetInverseInertia(@as(*const c.JPC_Body, @ptrCast(body)), &inverse_inertia);
        return inverse_inertia;
    }

    pub fn addImpulse(body: *Body, impulse: [3]f32) void {
        c.JPC_Body_AddImpulse(@as(*c.JPC_Body, @ptrCast(body)), &impulse);
    }
    pub fn addImpulseAtPosition(body: *Body, impulse: [3]f32, position: [3]Real) void {
        c.JPC_Body_AddImpulseAtPosition(@as(*c.JPC_Body, @ptrCast(body)), &impulse, &position);
    }

    pub fn addAngularImpulse(body: *Body, impulse: [3]f32) void {
        c.JPC_Body_AddAngularImpulse(@as(*c.JPC_Body, @ptrCast(body)), &impulse);
    }

    pub fn moveKinematic(
        body: *Body,
        target_position: [3]Real,
        target_rotation: [4]f32,
        delta_time: f32,
    ) void {
        c.JPC_Body_MoveKinematic(
            @as(*c.JPC_Body, @ptrCast(body)),
            &target_position,
            &target_rotation,
            delta_time,
        );
    }

    pub fn applyBuoyancyImpulse(
        body: *Body,
        surface_position: [3]Real,
        surface_normal: [3]f32,
        buoyancy: f32,
        linear_drag: f32,
        angular_drag: f32,
        fluid_velocity: [3]f32,
        gravity: [3]f32,
        delta_time: f32,
    ) void {
        c.JPC_Body_ApplyBuoyancyImpulse(
            @as(*c.JPC_Body, @ptrCast(body)),
            &surface_position,
            &surface_normal,
            buoyancy,
            linear_drag,
            angular_drag,
            &fluid_velocity,
            &gravity,
            delta_time,
        );
    }

    pub fn isInBroadPhase(body: *const Body) bool {
        return c.JPC_Body_IsInBroadPhase(@as(*const c.JPC_Body, @ptrCast(body)));
    }

    pub fn isCollisionCacheInvalid(body: *const Body) bool {
        return c.JPC_Body_IsCollisionCacheInvalid(@as(*const c.JPC_Body, @ptrCast(body)));
    }

    pub fn getShape(body: *const Body) *const Shape {
        return @as(*const Shape, @ptrCast(c.JPC_Body_GetShape(@as(*const c.JPC_Body, @ptrCast(body)))));
    }

    pub fn getPosition(body: *const Body) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_Body_GetPosition(@as(*const c.JPC_Body, @ptrCast(body)), &position);
        return position;
    }

    pub fn getRotation(body: *const Body) [4]f32 {
        var rotation: [4]f32 = undefined;
        c.JPC_Body_GetRotation(@as(*const c.JPC_Body, @ptrCast(body)), &rotation);
        return rotation;
    }

    pub fn getWorldTransform(body: *const Body) struct {
        rotation: [9]f32,
        position: [3]Real,
    } {
        var rotation: [9]f32 = undefined;
        var position: [3]Real = undefined;
        c.JPC_Body_GetWorldTransform(@as(*const c.JPC_Body, @ptrCast(body)), &rotation, &position);
        return .{ .rotation = rotation, .position = position };
    }

    pub fn getCenterOfMassPosition(body: *const Body) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_Body_GetCenterOfMassPosition(@as(*const c.JPC_Body, @ptrCast(body)), &position);
        return position;
    }

    pub fn getCenterOfMassTransform(body: *const Body) struct {
        rotation: [9]f32,
        position: [3]Real,
    } {
        var rotation: [9]f32 = undefined;
        var position: [3]Real = undefined;
        c.JPC_Body_GetCenterOfMassTransform(@as(*const c.JPC_Body, @ptrCast(body)), &rotation, &position);
        return .{ .rotation = rotation, .position = position };
    }

    pub fn getInverseCenterOfMassTransform(body: *const Body) struct {
        rotation: [9]f32,
        position: [3]Real,
    } {
        var rotation: [9]f32 = undefined;
        var position: [3]Real = undefined;
        c.JPC_Body_GetInverseCenterOfMassTransform(@as(*const c.JPC_Body, @ptrCast(body)), &rotation, &position);
        return .{ .rotation = rotation, .position = position };
    }

    pub fn getWorldSpaceBounds(body: *const Body) struct {
        min: [3]f32,
        max: [3]f32,
    } {
        var min: [3]f32 = undefined;
        var max: [3]f32 = undefined;
        c.JPC_Body_GetWorldSpaceBounds(@as(*const c.JPC_Body, @ptrCast(body)), &min, &max);
        return .{ .min = min, .max = max };
    }

    pub fn getMotionProperties(body: *const Body) *const MotionProperties {
        return @as(
            *const MotionProperties,
            @ptrCast(c.JPC_Body_GetMotionProperties(@as(*c.JPC_Body, @ptrFromInt(@intFromPtr(body))))),
        );
    }
    pub fn getMotionPropertiesMut(body: *Body) *MotionProperties {
        return @as(
            *MotionProperties,
            @ptrCast(c.JPC_Body_GetMotionProperties(@as(*c.JPC_Body, @ptrCast(body)))),
        );
    }

    pub fn getUserData(body: *const Body) u64 {
        return c.JPC_Body_GetUserData(@as(*const c.JPC_Body, @ptrCast(body)));
    }
    pub fn setUserData(body: *Body, user_data: u64) void {
        return c.JPC_Body_SetUserData(@as(*c.JPC_Body, @ptrCast(body)), user_data);
    }

    pub fn getWorldSpaceSurfaceNormal(
        body: *const Body,
        sub_shape_id: SubShapeId,
        position: [3]Real, // world space
    ) [3]f32 {
        var normal: [3]f32 = undefined;
        c.JPC_Body_GetWorldSpaceSurfaceNormal(
            @as(*const c.JPC_Body, @ptrCast(body)),
            sub_shape_id.toJpc(),
            &position,
            &normal,
        );
        return normal;
    }

    pub fn getFixedToWorld() *Body {
        return @ptrCast(c.JPC_Body_GetFixedToWorld());
    }

    comptime {
        assert(@sizeOf(Body) == @sizeOf(c.JPC_Body));
        assert(@offsetOf(Body, "flags") == @offsetOf(c.JPC_Body, "flags"));
        assert(@offsetOf(Body, "motion_properties") == @offsetOf(c.JPC_Body, "motion_properties"));
        assert(@offsetOf(Body, "object_layer") == @offsetOf(c.JPC_Body, "object_layer"));
        assert(@offsetOf(Body, "rotation") == @offsetOf(c.JPC_Body, "rotation"));
    }
};
//--------------------------------------------------------------------------------------------------
//
// Character
//
//--------------------------------------------------------------------------------------------------
pub const Character = opaque {
    pub fn create(
        in_settings: *const CharacterSettings,
        in_position: [3]Real,
        in_rotation: [4]f32,
        in_user_data: u64,
        in_physics_system: *PhysicsSystem,
    ) !*Character {
        return @as(*Character, @ptrCast(c.JPC_Character_Create(
            @as(*const c.JPC_CharacterSettings, @ptrCast(in_settings)),
            &in_position,
            &in_rotation,
            in_user_data,
            @as(*c.JPC_PhysicsSystem, @ptrCast(in_physics_system)),
        )));
    }
    pub fn destroy(character: *Character) void {
        c.JPC_Character_Destroy(@as(*c.JPC_Character, @ptrCast(character)));
    }

    pub fn addToPhysicsSystem(character: *Character, args: struct { activation: Activation = .activate, lock_bodies: bool = true }) void {
        c.JPC_Character_AddToPhysicsSystem(
            @as(*c.JPC_Character, @ptrCast(character)),
            @intFromEnum(args.activation),
            args.lock_bodies,
        );
    }
    pub fn removeFromPhysicsSystem(character: *Character, args: struct { lock_bodies: bool = true }) void {
        c.JPC_Character_RemoveFromPhysicsSystem(@as(*c.JPC_Character, @ptrCast(character)), args.lock_bodies);
    }

    pub fn getPosition(character: *const Character) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_Character_GetPosition(@as(*const c.JPC_Character, @ptrCast(character)), &position);
        return position;
    }
    pub fn setPosition(character: *Character, position: [3]Real) void {
        c.JPC_Character_SetPosition(@as(*c.JPC_Character, @ptrCast(character)), &position);
    }

    pub fn getLinearVelocity(character: *const Character) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_Character_GetLinearVelocity(@as(*const c.JPC_Character, @ptrCast(character)), &velocity);
        return velocity;
    }
    pub fn setLinearVelocity(character: *Character, velocity: [3]f32) void {
        c.JPC_Character_SetLinearVelocity(@as(*c.JPC_Character, @ptrCast(character)), &velocity);
    }
};
//--------------------------------------------------------------------------------------------------
//
// CharacterVirtual
//
//--------------------------------------------------------------------------------------------------
pub const CharacterVirtual = opaque {
    pub const ExtendedUpdateSettings = extern struct {
        stick_to_floor_step_down: [4]f32 align(16) = .{ 0, -0.5, 0, 0 }, // 4th element is ignored
        walk_stairs_step_up: [4]f32 align(16) = .{ 0, 0.4, 0, 0 }, // 4th element is ignored
        walk_stairs_min_step_forward: f32 = 0.02,
        walk_stairs_step_forward_test: f32 = 0.15,
        walk_stairs_cos_angle_forward_contact: f32 = std.math.cos(std.math.degreesToRadians(75.0)),
        walk_stairs_step_down_extra: [4]f32 align(16) = .{ 0, 0, 0, 0 }, // 4th element is ignored

        comptime {
            assert(@sizeOf(ExtendedUpdateSettings) == @sizeOf(c.JPC_CharacterVirtual_ExtendedUpdateSettings));
            assert(@offsetOf(ExtendedUpdateSettings, "walk_stairs_cos_angle_forward_contact") ==
                @offsetOf(c.JPC_CharacterVirtual_ExtendedUpdateSettings, "walk_stairs_cos_angle_forward_contact"));
        }
    };

    pub fn create(
        in_settings: *const CharacterVirtualSettings,
        in_position: [3]Real,
        in_rotation: [4]f32,
        in_physics_system: *PhysicsSystem,
    ) !*CharacterVirtual {
        return @as(*CharacterVirtual, @ptrCast(c.JPC_CharacterVirtual_Create(
            @as(*const c.JPC_CharacterVirtualSettings, @ptrCast(in_settings)),
            &in_position,
            &in_rotation,
            @as(*c.JPC_PhysicsSystem, @ptrCast(in_physics_system)),
        )));
    }

    pub fn destroy(character: *CharacterVirtual) void {
        c.JPC_CharacterVirtual_Destroy(@as(*c.JPC_CharacterVirtual, @ptrCast(character)));
    }

    pub fn update(
        character: *CharacterVirtual,
        delta_time: f32,
        gravity: [3]f32,
        args: struct {
            broad_phase_layer_filter: ?*const BroadPhaseLayerFilter = null,
            object_layer_filter: ?*const ObjectLayerFilter = null,
            body_filter: ?*const BodyFilter = null,
            shape_filter: ?*const ShapeFilter = null,
        },
    ) void {
        c.JPC_CharacterVirtual_Update(
            @as(*c.JPC_CharacterVirtual, @ptrCast(character)),
            delta_time,
            &gravity,
            args.broad_phase_layer_filter,
            args.object_layer_filter,
            args.body_filter,
            args.shape_filter,
            @as(*c.JPC_TempAllocator, @ptrCast(state.?.temp_allocator)),
        );
    }

    pub fn extendedUpdate(
        character: *CharacterVirtual,
        delta_time: f32,
        gravity: [3]f32,
        settings: *const ExtendedUpdateSettings,
        args: struct {
            broad_phase_layer_filter: ?*const BroadPhaseLayerFilter = null,
            object_layer_filter: ?*const ObjectLayerFilter = null,
            body_filter: ?*const BodyFilter = null,
            shape_filter: ?*const ShapeFilter = null,
        },
    ) void {
        c.JPC_CharacterVirtual_ExtendedUpdate(
            @as(*c.JPC_CharacterVirtual, @ptrCast(character)),
            delta_time,
            &gravity,
            settings,
            args.broad_phase_layer_filter,
            args.object_layer_filter,
            args.body_filter,
            args.shape_filter,
            @as(*c.JPC_TempAllocator, @ptrCast(state.?.temp_allocator)),
        );
    }

    pub fn setListener(character: *CharacterVirtual, listener: ?*anyopaque) void {
        c.JPC_CharacterVirtual_SetListener(@as(*c.JPC_CharacterVirtual, @ptrCast(character)), listener);
    }
    pub fn updateGroundVelocity(character: *CharacterVirtual) void {
        c.JPC_CharacterVirtual_UpdateGroundVelocity(@as(*c.JPC_CharacterVirtual, @ptrCast(character)));
    }
    pub fn getGroundVelocity(character: *const CharacterVirtual) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_CharacterVirtual_GetGroundVelocity(@as(*const c.JPC_CharacterVirtual, @ptrCast(character)), &velocity);
        return velocity;
    }
    pub fn getGroundState(character: *CharacterVirtual) CharacterGroundState {
        return @enumFromInt(c.JPC_CharacterVirtual_GetGroundState(@as(*c.JPC_CharacterVirtual, @ptrCast(character))));
    }

    pub fn getPosition(character: *const CharacterVirtual) [3]Real {
        var position: [3]Real = undefined;
        c.JPC_CharacterVirtual_GetPosition(@as(*const c.JPC_CharacterVirtual, @ptrCast(character)), &position);
        return position;
    }

    pub fn setPosition(character: *CharacterVirtual, position: [3]Real) void {
        c.JPC_CharacterVirtual_SetPosition(@as(*c.JPC_CharacterVirtual, @ptrCast(character)), &position);
    }

    pub fn getRotation(character: *const CharacterVirtual) [4]f32 {
        var rotation: [4]f32 = undefined;
        c.JPC_CharacterVirtual_GetRotation(@as(*const c.JPC_CharacterVirtual, @ptrCast(character)), &rotation);
        return rotation;
    }
    pub fn setRotation(character: *CharacterVirtual, rotation: [4]f32) void {
        c.JPC_CharacterVirtual_SetRotation(@as(*c.JPC_CharacterVirtual, @ptrCast(character)), &rotation);
    }

    pub fn getLinearVelocity(character: *const CharacterVirtual) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_CharacterVirtual_GetLinearVelocity(@as(*const c.JPC_CharacterVirtual, @ptrCast(character)), &velocity);
        return velocity;
    }
    pub fn setLinearVelocity(character: *CharacterVirtual, velocity: [3]f32) void {
        c.JPC_CharacterVirtual_SetLinearVelocity(@as(*c.JPC_CharacterVirtual, @ptrCast(character)), &velocity);
    }
};
//--------------------------------------------------------------------------------------------------
//
// MotionProperties
//
//--------------------------------------------------------------------------------------------------
pub const MotionProperties = extern struct {
    pub const inactive_index: u32 = std.math.maxInt(u32);

    linear_velocity: [4]f32 align(16), // 4th element is ignored
    angular_velocity: [4]f32 align(16), // 4th element is ignored
    inv_inertia_diagonal: [4]f32 align(16),
    inertia_rotation: [4]f32 align(16),

    force: [3]f32,
    torque: [3]f32,
    inv_mass: f32,
    linear_damping: f32,
    angular_damping: f32,
    max_linear_velocity: f32,
    max_angular_velocity: f32,
    gravity_factor: f32,
    index_in_active_bodies: u32 = inactive_index,
    island_index: u32 = inactive_index,

    motion_quality: MotionQuality,
    allow_sleeping: bool,

    allowed_DOFs: AllowedDOFs = .all,
    num_velocity_steps_override: u8 = 0,
    num_position_steps_override: u8 = 0,

    reserved: [53 + c.JPC_ENABLE_ASSERTS * 3 + c.JPC_DOUBLE_PRECISION * 24]u8 align(4 + 4 * c.JPC_DOUBLE_PRECISION),

    pub fn getMotionQuality(motion: *const MotionProperties) MotionQuality {
        return @as(MotionQuality, @enumFromInt(c.JPC_MotionProperties_GetMotionQuality(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
        )));
    }

    pub fn getLinearVelocity(motion: *const MotionProperties) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_MotionProperties_GetLinearVelocity(@as(*const c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
        return velocity;
    }
    pub fn setLinearVelocity(motion: *MotionProperties, velocity: [3]f32) void {
        c.JPC_MotionProperties_SetLinearVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
    }
    pub fn setLinearVelocityClamped(motion: *MotionProperties, velocity: [3]f32) void {
        c.JPC_MotionProperties_SetLinearVelocityClamped(@as(*c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
    }

    pub fn getAngularVelocity(motion: *const MotionProperties) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_MotionProperties_GetAngularVelocity(@as(*const c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
        return velocity;
    }
    pub fn setAngularVelocity(motion: *MotionProperties, velocity: [3]f32) void {
        c.JPC_MotionProperties_SetAngularVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
    }
    pub fn setAngularVelocityClamped(motion: *MotionProperties, velocity: [3]f32) void {
        c.JPC_MotionProperties_SetAngularVelocityClamped(@as(*c.JPC_MotionProperties, @ptrCast(motion)), &velocity);
    }

    /// `point` is relative to the center of mass (com)
    pub fn getPointVelocityCom(motion: *const MotionProperties, point: [3]f32) [3]f32 {
        var velocity: [3]f32 = undefined;
        c.JPC_MotionProperties_GetPointVelocityCOM(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
            &point,
            &velocity,
        );
        return velocity;
    }

    pub fn getMaxLinearVelocity(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetMaxLinearVelocity(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setMaxLinearVelocity(motion: *MotionProperties, velocity: f32) void {
        c.JPC_MotionProperties_SetMaxLinearVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)), velocity);
    }

    pub fn getMaxAngularVelocity(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetMaxAngularVelocity(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setMaxAngularVelocity(motion: *MotionProperties, velocity: f32) void {
        c.JPC_MotionProperties_SetMaxAngularVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)), velocity);
    }

    pub fn moveKinematic(
        motion: *MotionProperties,
        delta_position: [3]f32,
        delta_rotation: [4]f32,
        delta_time: f32,
    ) void {
        c.JPC_MotionProperties_MoveKinematic(
            @as(*c.JPC_MotionProperties, @ptrCast(motion)),
            &delta_position,
            &delta_rotation,
            delta_time,
        );
    }

    pub fn clampLinearVelocity(motion: *MotionProperties) void {
        c.JPC_MotionProperties_ClampLinearVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn clampAngularVelocity(motion: *MotionProperties) void {
        c.JPC_MotionProperties_ClampAngularVelocity(@as(*c.JPC_MotionProperties, @ptrCast(motion)));
    }

    pub fn getLinearDamping(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetLinearDamping(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setLinearDamping(motion: *MotionProperties, damping: f32) void {
        c.JPC_MotionProperties_SetLinearDamping(@as(*c.JPC_MotionProperties, @ptrCast(motion)), damping);
    }

    pub fn getAngularDamping(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetAngularDamping(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setAngularDamping(motion: *MotionProperties, damping: f32) void {
        c.JPC_MotionProperties_SetAngularDamping(@as(*c.JPC_MotionProperties, @ptrCast(motion)), damping);
    }

    pub fn getGravityFactor(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetGravityFactor(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setGravityFactor(motion: *MotionProperties, factor: f32) void {
        c.JPC_MotionProperties_SetGravityFactor(@as(*c.JPC_MotionProperties, @ptrCast(motion)), factor);
    }

    pub fn setMassProperties(
        motion: *MotionProperties,
        allowed_DOFs: AllowedDOFs,
        mass_properties: MassProperties,
    ) void {
        c.JPC_MotionProperties_SetMassProperties(
            @as(*c.JPC_MotionProperties, @ptrCast(motion)),
            @intFromEnum(allowed_DOFs),
            @as(*const c.JPC_MassProperties, @ptrCast(&mass_properties)),
        );
    }

    pub fn getInverseMass(motion: *const MotionProperties) f32 {
        return c.JPC_MotionProperties_GetInverseMass(@as(*const c.JPC_MotionProperties, @ptrCast(motion)));
    }
    pub fn setInverseMass(motion: *MotionProperties, inverse_mass: f32) void {
        c.JPC_MotionProperties_SetInverseMass(@as(*c.JPC_MotionProperties, @ptrCast(motion)), inverse_mass);
    }

    pub fn getInverseInertiaDiagonal(motion: *const MotionProperties) [3]f32 {
        var diagonal: [3]f32 = undefined;
        c.JPC_MotionProperties_GetInverseInertiaDiagonal(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
            &diagonal,
        );
        return diagonal;
    }

    pub fn getInertiaRotation(motion: *const MotionProperties) [4]f32 {
        var rotation: [4]f32 = undefined;
        c.JPC_MotionProperties_GetInertiaRotation(@as(*const c.JPC_MotionProperties, @ptrCast(motion)), &rotation);
        return rotation;
    }

    pub fn setInverseInertia(motion: *MotionProperties, diagonal: [3]f32, rotation: [4]f32) void {
        c.JPC_MotionProperties_SetInverseInertia(@as(*c.JPC_MotionProperties, @ptrCast(motion)), &diagonal, &rotation);
    }

    pub fn getLocalSpaceInverseInertia(motion: *const MotionProperties) [16]f32 {
        var inertia: [16]f32 = undefined;
        c.JPC_MotionProperties_GetLocalSpaceInverseInertia(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
            &inertia,
        );
        return inertia;
    }

    pub fn getInverseInertiaForRotation(motion: *const MotionProperties, rotation_matrix: [16]f32) [16]f32 {
        var inertia: [16]f32 = undefined;
        c.JPC_MotionProperties_GetInverseInertiaForRotation(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
            &rotation_matrix,
            &inertia,
        );
        return inertia;
    }

    pub fn multiplyWorldSpaceInverseInertiaByVector(
        motion: *const MotionProperties,
        rotation: [4]f32,
        vector: [3]f32,
    ) [3]f32 {
        var out: [3]f32 = undefined;
        c.JPC_MotionProperties_MultiplyWorldSpaceInverseInertiaByVector(
            @as(*const c.JPC_MotionProperties, @ptrCast(motion)),
            &rotation,
            &vector,
            &out,
        );
        return out;
    }

    comptime {
        assert(@sizeOf(MotionProperties) == @sizeOf(c.JPC_MotionProperties));
        assert(@offsetOf(MotionProperties, "force") == @offsetOf(c.JPC_MotionProperties, "force"));
        assert(@offsetOf(MotionProperties, "motion_quality") == @offsetOf(c.JPC_MotionProperties, "motion_quality"));
        assert(@offsetOf(MotionProperties, "gravity_factor") == @offsetOf(c.JPC_MotionProperties, "gravity_factor"));
        assert(@offsetOf(MotionProperties, "num_position_steps_override") == @offsetOf(
            c.JPC_MotionProperties,
            "num_position_steps_override",
        ));
    }
};
//--------------------------------------------------------------------------------------------------
//
// ShapeSettings
//
//--------------------------------------------------------------------------------------------------
pub const ShapeSettings = opaque {
    pub fn addRef(shape_settings: *ShapeSettings) void {
        c.JPC_ShapeSettings_AddRef(@ptrCast(shape_settings));
    }

    pub fn release(shape_settings: *ShapeSettings) void {
        c.JPC_ShapeSettings_Release(@ptrCast(shape_settings));
    }

    pub fn getRefCount(shape_settings: *const ShapeSettings) u32 {
        return c.JPC_ShapeSettings_GetRefCount(@as(*const c.JPC_ShapeSettings, @ptrCast(shape_settings)));
    }

    pub fn createShape(shape_settings: *const ShapeSettings) !*Shape {
        return @ptrCast(c.JPC_ShapeSettings_CreateShape(@ptrCast(shape_settings)) orelse
            return error.FailedToCreateShape);
    }

    pub fn getUserData(shape_settings: *const ShapeSettings) u64 {
        return c.JPC_ShapeSettings_GetUserData(@ptrCast(shape_settings));
    }

    pub fn setUserData(shape_settings: *ShapeSettings, user_data: u64) void {
        return c.JPC_ShapeSettings_SetUserData(@ptrCast(shape_settings), user_data);
    }
};
//--------------------------------------------------------------------------------------------------
//
// ConvexShapeSettings (-> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const ConvexShapeSettings = opaque {
    pub fn asShapeSettings(convex_shape_settings: *ConvexShapeSettings) *ShapeSettings {
        return @ptrCast(convex_shape_settings);
    }

    pub fn getMaterial(convex_shape_settings: *const ConvexShapeSettings) ?*const Material {
        return @ptrCast(c.JPC_ConvexShapeSettings_GetMaterial(@ptrCast(convex_shape_settings)));
    }

    pub fn setMaterial(convex_shape_settings: *ConvexShapeSettings, material: ?*Material) void {
        c.JPC_ConvexShapeSettings_SetMaterial(
            @ptrCast(convex_shape_settings),
            @ptrCast(material),
        );
    }

    pub fn getDensity(convex_shape_settings: *const ConvexShapeSettings) f32 {
        return c.JPC_ConvexShapeSettings_GetDensity(@ptrCast(convex_shape_settings));
    }

    pub fn setDensity(shape_settings: *ConvexShapeSettings, density: f32) void {
        c.JPC_ConvexShapeSettings_SetDensity(@ptrCast(shape_settings), density);
    }
};
//--------------------------------------------------------------------------------------------------
//
// BoxShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const BoxShapeSettings = opaque {
    pub fn asShapeSettings(box_shape_settings: *BoxShapeSettings) *ShapeSettings {
        return @ptrCast(box_shape_settings);
    }

    pub fn asConvexShapeSettings(box_shape_settings: *BoxShapeSettings) *ConvexShapeSettings {
        return @ptrCast(box_shape_settings);
    }

    pub fn create(half_extent: [3]f32) !*BoxShapeSettings {
        return @ptrCast(c.JPC_BoxShapeSettings_Create(&half_extent) orelse
            return error.FailedToCreateBoxShapeSettings);
    }

    pub fn getHalfExtent(box_shape_settings: *const BoxShapeSettings) [3]f32 {
        var half_extent: [3]f32 = undefined;
        c.JPC_BoxShapeSettings_GetHalfExtent(
            @ptrCast(box_shape_settings),
            &half_extent,
        );
        return half_extent;
    }

    pub fn setHalfExtent(box_shape_settings: *BoxShapeSettings, half_extent: [3]f32) void {
        c.JPC_BoxShapeSettings_SetHalfExtent(@ptrCast(box_shape_settings), &half_extent);
    }

    pub fn getConvexRadius(box_shape_settings: *const BoxShapeSettings) f32 {
        return c.JPC_BoxShapeSettings_GetConvexRadius(@ptrCast(box_shape_settings));
    }

    pub fn setConvexRadius(box_shape_settings: *BoxShapeSettings, convex_radius: f32) void {
        c.JPC_BoxShapeSettings_SetConvexRadius(
            @ptrCast(box_shape_settings),
            convex_radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// SphereShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const SphereShapeSettings = opaque {
    pub fn asShapeSettings(sphere_shape_settings: *SphereShapeSettings) *ShapeSettings {
        return @ptrCast(sphere_shape_settings);
    }

    pub fn asConvexShapeSettings(sphere_shape_settings: *SphereShapeSettings) *ConvexShapeSettings {
        return @ptrCast(sphere_shape_settings);
    }

    pub fn create(radius: f32) !*SphereShapeSettings {
        return @ptrCast(c.JPC_SphereShapeSettings_Create(radius) orelse
            return error.FailedToCreateSphereShapeSettings);
    }

    pub fn getRadius(sphere_shape_settings: *const SphereShapeSettings) f32 {
        return c.JPC_SphereShapeSettings_GetRadius(@ptrCast(sphere_shape_settings));
    }

    pub fn setRadius(sphere_shape_settings: *SphereShapeSettings, radius: f32) void {
        c.JPC_SphereShapeSettings_SetRadius(@ptrCast(sphere_shape_settings), radius);
    }
};
//--------------------------------------------------------------------------------------------------
//
// TriangleShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const TriangleShapeSettings = opaque {
    pub fn asShapeSettings(triangle_shape_settings: *TriangleShapeSettings) *ShapeSettings {
        return @ptrCast(triangle_shape_settings);
    }

    pub fn asConvexShapeSettings(triangle_shape_settings: *TriangleShapeSettings) *ConvexShapeSettings {
        return @ptrCast(triangle_shape_settings);
    }

    pub fn create(v1: [3]f32, v2: [3]f32, v3: [3]f32) !*TriangleShapeSettings {
        return @ptrCast(c.JPC_TriangleShapeSettings_Create(
            &v1,
            &v2,
            &v3,
        ) orelse return error.FailedToCreateTriangleShapeSettings);
    }

    pub fn getConvexRadius(triangle_shape_settings: *const TriangleShapeSettings) f32 {
        return c.JPC_TriangleShapeSettings_GetConvexRadius(@ptrCast(triangle_shape_settings));
    }

    pub fn setConvexRadius(triangle_shape_settings: *TriangleShapeSettings, convex_radius: f32) void {
        c.JPC_TriangleShapeSettings_SetConvexRadius(
            @ptrCast(triangle_shape_settings),
            convex_radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// CapsuleShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const CapsuleShapeSettings = opaque {
    pub fn asShapeSettings(capsule_shape_settings: *CapsuleShapeSettings) *ShapeSettings {
        return @ptrCast(capsule_shape_settings);
    }

    pub fn asConvexShapeSettings(capsule_shape_settings: *CapsuleShapeSettings) *ConvexShapeSettings {
        return @ptrCast(capsule_shape_settings);
    }

    pub fn create(half_height: f32, radius: f32) !*CapsuleShapeSettings {
        return @ptrCast(c.JPC_CapsuleShapeSettings_Create(
            half_height,
            radius,
        ) orelse return error.FailedToCreateCapsuleShapeSettings);
    }

    pub fn getHalfHeight(capsule_shape_settings: *const CapsuleShapeSettings) f32 {
        return c.JPC_CapsuleShapeSettings_GetHalfHeight(@ptrCast(capsule_shape_settings));
    }

    pub fn setHalfHeight(capsule_shape_settings: *CapsuleShapeSettings, half_height: f32) void {
        c.JPC_CapsuleShapeSettings_SetHalfHeight(@ptrCast(capsule_shape_settings), half_height);
    }

    pub fn getRadius(capsule_shape_settings: *const CapsuleShapeSettings) f32 {
        return c.JPC_CapsuleShapeSettings_GetRadius(@ptrCast(capsule_shape_settings));
    }

    pub fn setRadius(capsule_shape_settings: *CapsuleShapeSettings, radius: f32) void {
        c.JPC_CapsuleShapeSettings_SetRadius(
            @ptrCast(capsule_shape_settings),
            radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// TaperedCapsuleShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const TaperedCapsuleShapeSettings = opaque {
    pub fn asShapeSettings(tapered_capsule_shape_settings: *TaperedCapsuleShapeSettings) *ShapeSettings {
        return @ptrCast(tapered_capsule_shape_settings);
    }

    pub fn asConvexShapeSettings(tapered_capsule_shape_settings: *TaperedCapsuleShapeSettings) *ConvexShapeSettings {
        return @ptrCast(tapered_capsule_shape_settings);
    }

    pub fn create(half_height: f32, top_radius: f32, bottom_radius: f32) !*TaperedCapsuleShapeSettings {
        return @ptrCast(c.JPC_TaperedCapsuleShapeSettings_Create(
            half_height,
            top_radius,
            bottom_radius,
        ) orelse return error.FailedToCreateTaperedCapsuleShapeSettings);
    }

    pub fn getHalfHeight(capsule_shape_settings: *const TaperedCapsuleShapeSettings) f32 {
        return c.JPC_TaperedCapsuleShapeSettings_GetHalfHeight(
            @ptrCast(capsule_shape_settings),
        );
    }

    pub fn setHalfHeight(capsule_shape_settings: *TaperedCapsuleShapeSettings, half_height: f32) void {
        c.JPC_TaperedCapsuleShapeSettings_SetHalfHeight(
            @ptrCast(capsule_shape_settings),
            half_height,
        );
    }

    pub fn getTopRadius(capsule_shape_settings: *const TaperedCapsuleShapeSettings) f32 {
        return c.JPC_TaperedCapsuleShapeSettings_GetTopRadius(
            @ptrCast(capsule_shape_settings),
        );
    }

    pub fn setTopRadius(capsule_shape_settings: *TaperedCapsuleShapeSettings, radius: f32) void {
        c.JPC_TaperedCapsuleShapeSettings_SetTopRadius(
            @as(*c.JPC_TaperedCapsuleShapeSettings, @ptrCast(capsule_shape_settings)),
            radius,
        );
    }

    pub fn getBottomRadius(capsule_shape_settings: *const TaperedCapsuleShapeSettings) f32 {
        return c.JPC_TaperedCapsuleShapeSettings_GetBottomRadius(
            @as(*const c.JPC_TaperedCapsuleShapeSettings, @ptrCast(capsule_shape_settings)),
        );
    }

    pub fn setBottomRadius(capsule_shape_settings: *TaperedCapsuleShapeSettings, radius: f32) void {
        c.JPC_TaperedCapsuleShapeSettings_SetBottomRadius(
            @as(*c.JPC_TaperedCapsuleShapeSettings, @ptrCast(capsule_shape_settings)),
            radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// CylinderShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const CylinderShapeSettings = opaque {
    pub fn asShapeSettings(cylinder_shape_settings: *CylinderShapeSettings) *ShapeSettings {
        return @ptrCast(cylinder_shape_settings);
    }

    pub fn asConvexShapeSettings(cylinder_shape_settings: *CylinderShapeSettings) *ConvexShapeSettings {
        return @ptrCast(cylinder_shape_settings);
    }

    pub fn create(half_height: f32, radius: f32) !*CylinderShapeSettings {
        return @ptrCast(c.JPC_CylinderShapeSettings_Create(
            half_height,
            radius,
        ) orelse return error.FailedToCreateCylinderShapeSettings);
    }

    pub fn getConvexRadius(cylinder_shape_settings: *const CylinderShapeSettings) f32 {
        return c.JPC_CylinderShapeSettings_GetConvexRadius(
            @ptrCast(cylinder_shape_settings),
        );
    }

    pub fn setConvexRadius(cylinder_shape_settings: *CylinderShapeSettings, convex_radius: f32) void {
        c.JPC_CylinderShapeSettings_SetConvexRadius(
            @ptrCast(cylinder_shape_settings),
            convex_radius,
        );
    }

    pub fn getHalfHeight(cylinder_shape_settings: *const CylinderShapeSettings) f32 {
        return c.JPC_CylinderShapeSettings_GetHalfHeight(
            @ptrCast(cylinder_shape_settings),
        );
    }

    pub fn setHalfHeight(cylinder_shape_settings: *CylinderShapeSettings, half_height: f32) void {
        c.JPC_CylinderShapeSettings_SetHalfHeight(
            @ptrCast(cylinder_shape_settings),
            half_height,
        );
    }

    pub fn getRadius(cylinder_shape_settings: *const CylinderShapeSettings) f32 {
        return c.JPC_CylinderShapeSettings_GetRadius(
            @ptrCast(cylinder_shape_settings),
        );
    }

    pub fn setRadius(cylinder_shape_settings: *CylinderShapeSettings, radius: f32) void {
        c.JPC_CylinderShapeSettings_SetRadius(
            @ptrCast(cylinder_shape_settings),
            radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// ConvexHullShapeSettings (-> ConvexShapeSettings -> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const ConvexHullShapeSettings = opaque {
    pub fn asShapeSettings(convex_hull_shape_settings: *ConvexHullShapeSettings) *ShapeSettings {
        return @ptrCast(convex_hull_shape_settings);
    }

    pub fn asConvexShapeSettings(convex_hull_shape_settings: *ConvexHullShapeSettings) *ConvexShapeSettings {
        return @ptrCast(convex_hull_shape_settings);
    }

    pub fn create(vertices: *const anyopaque, num_vertices: u32, vertex_size: u32) !*ConvexHullShapeSettings {
        return @ptrCast(c.JPC_ConvexHullShapeSettings_Create(
            vertices,
            num_vertices,
            vertex_size,
        ) orelse return error.FailedToCreateConvexHullShapeSettings);
    }

    pub fn getMaxConvexRadius(settings: *const ConvexHullShapeSettings) f32 {
        return c.JPC_ConvexHullShapeSettings_GetMaxConvexRadius(
            @ptrCast(settings),
        );
    }

    pub fn setMaxConvexRadius(settings: *ConvexHullShapeSettings, radius: f32) void {
        c.JPC_ConvexHullShapeSettings_SetMaxConvexRadius(
            @ptrCast(settings),
            radius,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// HeightFieldShapeSettings (-> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const HeightFieldShapeSettings = opaque {
    pub fn asShapeSettings(height_field_shape_settings: *HeightFieldShapeSettings) *ShapeSettings {
        return @ptrCast(height_field_shape_settings);
    }

    pub fn create(
        samples: [*]const f32, // height_field_size^2 samples
        height_field_size: u32, //  height_field_size / block_size must be a power of 2 and minimally 2
    ) !*HeightFieldShapeSettings {
        return @ptrCast(c.JPC_HeightFieldShapeSettings_Create(
            samples,
            height_field_size,
        ) orelse return error.FailedToCreateHeightFieldShapeSettings);
    }

    pub fn getBlockSize(settings: *const HeightFieldShapeSettings) u32 {
        return c.JPC_HeightFieldShapeSettings_GetBlockSize(
            @ptrCast(settings),
        );
    }

    pub fn setBlockSize(settings: *HeightFieldShapeSettings, block_size: u32) void {
        c.JPC_HeightFieldShapeSettings_SetBlockSize(
            @ptrCast(settings),
            block_size,
        );
    }

    pub fn getBitsPerSample(settings: *const HeightFieldShapeSettings) u32 {
        return c.JPC_HeightFieldShapeSettings_GetBitsPerSample(
            @ptrCast(settings),
        );
    }

    pub fn setBitsPerSample(settings: *HeightFieldShapeSettings, num_bits: u32) void {
        c.JPC_HeightFieldShapeSettings_SetBitsPerSample(
            @ptrCast(settings),
            num_bits,
        );
    }

    pub fn getOffset(settings: *const HeightFieldShapeSettings) [3]f32 {
        var offset: [3]f32 = undefined;
        c.JPC_HeightFieldShapeSettings_GetOffset(
            @ptrCast(settings),
            &offset,
        );
        return offset;
    }

    pub fn setOffset(settings: *HeightFieldShapeSettings, offset: [3]f32) void {
        c.JPC_HeightFieldShapeSettings_SetOffset(
            @ptrCast(settings),
            &offset,
        );
    }

    pub fn getScale(settings: *const HeightFieldShapeSettings) [3]f32 {
        var scale: [3]f32 = undefined;
        c.JPC_HeightFieldShapeSettings_GetScale(
            @ptrCast(settings),
            &scale,
        );
        return scale;
    }

    pub fn setScale(settings: *HeightFieldShapeSettings, scale: [3]f32) void {
        c.JPC_HeightFieldShapeSettings_SetScale(
            @ptrCast(settings),
            &scale,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// MeshShapeSettings (-> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const MeshShapeSettings = opaque {
    pub fn asShapeSettings(mesh_shape_settings: *MeshShapeSettings) *ShapeSettings {
        return @ptrCast(mesh_shape_settings);
    }

    pub fn create(
        vertices: *const anyopaque,
        num_vertices: u32,
        vertex_size: u32,
        indices: []const u32,
    ) !*MeshShapeSettings {
        return @ptrCast(c.JPC_MeshShapeSettings_Create(
            vertices,
            num_vertices,
            vertex_size,
            indices.ptr,
            @intCast(indices.len),
        ) orelse return error.FailedToCreateMeshShapeSettings);
    }

    pub fn getMaxTrianglesPerLeaf(settings: *const MeshShapeSettings) u32 {
        return c.JPC_MeshShapeSettings_GetMaxTrianglesPerLeaf(
            @ptrCast(settings),
        );
    }
    pub fn setMaxTrianglesPerLeaf(settings: *MeshShapeSettings, max_triangles: u32) void {
        c.JPC_MeshShapeSettings_SetMaxTrianglesPerLeaf(
            @ptrCast(settings),
            max_triangles,
        );
    }

    pub fn sanitize(settings: *MeshShapeSettings) void {
        c.JPC_MeshShapeSettings_Sanitize(@ptrCast(settings));
    }
};
//--------------------------------------------------------------------------------------------------
//
// DecoratedShapeSettings (-> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const DecoratedShapeSettings = opaque {
    pub fn asShapeSettings(decorated_shape_settings: *DecoratedShapeSettings) *ShapeSettings {
        return @ptrCast(decorated_shape_settings);
    }

    pub fn createRotatedTranslated(
        inner_shape: *const ShapeSettings,
        rotation: [4]f32,
        translation: [3]f32,
    ) !*DecoratedShapeSettings {
        return @ptrCast(c.JPC_RotatedTranslatedShapeSettings_Create(
            @as(*const c.JPC_ShapeSettings, @ptrCast(inner_shape)),
            &rotation,
            &translation,
        ) orelse return error.FailedToCreateDecoratedShapeSettings);
    }

    pub fn createScaled(inner_shape: *const ShapeSettings, scale: [3]f32) !*DecoratedShapeSettings {
        return @ptrCast(c.JPC_ScaledShapeSettings_Create(
            @ptrCast(inner_shape),
            &scale,
        ) orelse return error.FailedToCreateDecoratedShapeSettings);
    }

    pub fn createOffsetCenterOfMass(inner_shape: *const ShapeSettings, offset: [3]f32) !*DecoratedShapeSettings {
        return @ptrCast(c.JPC_OffsetCenterOfMassShapeSettings_Create(
            @as(*const c.JPC_ShapeSettings, @ptrCast(inner_shape)),
            &offset,
        ) orelse return error.FailedToCreateDecoratedShapeSettings);
    }
};
//--------------------------------------------------------------------------------------------------
//
// CompoundShapeSettings (-> ShapeSettings)
//
//--------------------------------------------------------------------------------------------------
pub const CompoundShapeSettings = opaque {
    pub fn asShapeSettings(compound_shape_settings: *CompoundShapeSettings) *ShapeSettings {
        return @ptrCast(compound_shape_settings);
    }

    pub fn createStatic() !*CompoundShapeSettings {
        return @ptrCast(c.JPC_StaticCompoundShapeSettings_Create() orelse
            return error.FailedToCreateCompoundShapeSettings);
    }

    pub fn createMutable() !*CompoundShapeSettings {
        return @ptrCast(c.JPC_MutableCompoundShapeSettings_Create() orelse
            return error.FailedToCreateCompoundShapeSettings);
    }

    pub fn addShape(
        settings: *CompoundShapeSettings,
        position: [3]f32,
        rotation: [4]f32,
        shape: *const ShapeSettings,
        user_data: u32,
    ) void {
        c.JPC_CompoundShapeSettings_AddShape(
            @ptrCast(settings),
            &position,
            &rotation,
            @ptrCast(shape),
            user_data,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// Shape
//
//--------------------------------------------------------------------------------------------------
pub const Shape = opaque {
    pub const Type = enum(c.JPC_ShapeType) {
        convex = c.JPC_SHAPE_TYPE_CONVEX,
        compound = c.JPC_SHAPE_TYPE_COMPOUND,
        decorated = c.JPC_SHAPE_TYPE_DECORATED,
        mesh = c.JPC_SHAPE_TYPE_MESH,
        height_field = c.JPC_SHAPE_TYPE_HEIGHT_FIELD,
        user1 = c.JPC_SHAPE_TYPE_USER1,
        user2 = c.JPC_SHAPE_TYPE_USER2,
        user3 = c.JPC_SHAPE_TYPE_USER3,
        user4 = c.JPC_SHAPE_TYPE_USER4,
    };

    pub const SubType = enum(c.JPC_ShapeSubType) {
        sphere = c.JPC_SHAPE_SUB_TYPE_SPHERE,
        box = c.JPC_SHAPE_SUB_TYPE_BOX,
        triangle = c.JPC_SHAPE_SUB_TYPE_TRIANGLE,
        capsule = c.JPC_SHAPE_SUB_TYPE_CAPSULE,
        tapered_capsule = c.JPC_SHAPE_SUB_TYPE_TAPERED_CAPSULE,
        cylinder = c.JPC_SHAPE_SUB_TYPE_CYLINDER,
        convex_hull = c.JPC_SHAPE_SUB_TYPE_CONVEX_HULL,
        static_compound = c.JPC_SHAPE_SUB_TYPE_STATIC_COMPOUND,
        mutable_compound = c.JPC_SHAPE_SUB_TYPE_MUTABLE_COMPOUND,
        rotated_translated = c.JPC_SHAPE_SUB_TYPE_ROTATED_TRANSLATED,
        scaled = c.JPC_SHAPE_SUB_TYPE_SCALED,
        offset_center_of_mass = c.JPC_SHAPE_SUB_TYPE_OFFSET_CENTER_OF_MASS,
        mesh = c.JPC_SHAPE_SUB_TYPE_MESH,
        height_field = c.JPC_SHAPE_SUB_TYPE_HEIGHT_FIELD,
        user1 = c.JPC_SHAPE_SUB_TYPE_USER1,
        user2 = c.JPC_SHAPE_SUB_TYPE_USER2,
        user3 = c.JPC_SHAPE_SUB_TYPE_USER3,
        user4 = c.JPC_SHAPE_SUB_TYPE_USER4,
        user5 = c.JPC_SHAPE_SUB_TYPE_USER5,
        user6 = c.JPC_SHAPE_SUB_TYPE_USER6,
        user7 = c.JPC_SHAPE_SUB_TYPE_USER7,
        user8 = c.JPC_SHAPE_SUB_TYPE_USER8,
        user_convex1 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX1,
        user_convex2 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX2,
        user_convex3 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX3,
        user_convex4 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX4,
        user_convex5 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX5,
        user_convex6 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX6,
        user_convex7 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX7,
        user_convex8 = c.JPC_SHAPE_SUB_TYPE_USER_CONVEX8,
    };

    pub const SupportingFace = extern struct {
        num_points: u32 align(16),
        points: [32][4]f32 align(16), // 4th element is ignored; world space

        comptime {
            assert(@sizeOf(SupportingFace) == @sizeOf(c.JPC_Shape_SupportingFace));
            assert(@offsetOf(SupportingFace, "points") == @offsetOf(c.JPC_Shape_SupportingFace, "points"));
        }
    };

    pub fn restoreFromBinaryState(stream_in: *StreamIn) !*Shape {
        const shape = c.JPC_Shape_sRestoreFromBinaryState(stream_in);
        if (shape == null)
            return error.FailedToRestoreShape;
        return @as(*Shape, @ptrCast(shape));
    }

    pub fn restoreWithChildrenAll(stream_in: *StreamIn) !*Shape {
        const shape = c.JPC_Shape_sRestoreWithChildren_All(stream_in);
        if (shape == null)
            return error.FailedToRestoreShape;
        return @as(*Shape, @ptrCast(shape));
    }

    pub fn addRef(shape: *Shape) void {
        c.JPC_Shape_AddRef(@ptrCast(shape));
    }

    pub fn release(shape: *Shape) void {
        c.JPC_Shape_Release(@ptrCast(shape));
    }

    pub fn getRefCount(shape: *const Shape) u32 {
        return c.JPC_Shape_GetRefCount(@ptrCast(shape));
    }

    pub fn getType(shape: *const Shape) Type {
        return @as(
            Type,
            @enumFromInt(c.JPC_Shape_GetType(@ptrCast(shape))),
        );
    }

    pub fn getSubType(shape: *const Shape) SubType {
        return @as(
            SubType,
            @enumFromInt(c.JPC_Shape_GetSubType(@ptrCast(shape))),
        );
    }

    pub fn getUserData(shape: *const Shape) u64 {
        return c.JPC_Shape_GetUserData(@ptrCast(shape));
    }

    pub fn setUserData(shape: *Shape, user_data: u64) void {
        return c.JPC_Shape_SetUserData(@ptrCast(shape), user_data);
    }

    pub fn getVolume(shape: *const Shape) f32 {
        return c.JPC_Shape_GetVolume(@ptrCast(shape));
    }

    pub fn getCenterOfMass(shape: *const Shape) [3]f32 {
        var center: [3]f32 = undefined;
        c.JPC_Shape_GetCenterOfMass(@ptrCast(shape), &center);
        return center;
    }

    pub fn getLocalBounds(shape: *const Shape) AABox {
        const aabox = c.JPC_Shape_GetLocalBounds(@ptrCast(shape));
        return @as(*AABox, @constCast(@ptrCast(&aabox))).*;
    }

    pub fn getSurfaceNormal(shape: *const Shape, sub_shape_id: SubShapeId, local_pos: [3]f32) [3]f32 {
        var normal: [3]f32 = undefined;
        c.JPC_Shape_GetSurfaceNormal(
            @ptrCast(shape),
            sub_shape_id.toJpc(),
            &local_pos,
            &normal,
        );
        return normal;
    }

    pub fn getSupportingFace(
        shape: *const Shape,
        sub_shape_id: SubShapeId,
        direction: [3]f32,
        shape_scale: [3]f32,
        com_transform: [16]f32,
    ) SupportingFace {
        const c_face = c.JPC_Shape_GetSupportingFace(
            @ptrCast(shape),
            sub_shape_id.toJpc(),
            &direction,
            &shape_scale,
            &com_transform,
        );
        return @as(*const SupportingFace, @ptrCast(&c_face)).*;
    }

    pub fn castRay(
        shape: *const Shape,
        ray: RayCast,
        args: struct {
            sub_shape_id_creator: SubShapeIDCreator = .{},
        },
    ) struct { has_hit: bool, hit: RayCastResult } {
        var hit: RayCastResult = .{};
        const has_hit = c.JPC_Shape_CastRay(
            @ptrCast(shape),
            @ptrCast(&ray),
            @ptrCast(&args.sub_shape_id_creator),
            @ptrCast(&hit),
        );
        return .{ .has_hit = has_hit, .hit = hit };
    }

    pub fn saveBinaryState(shape: *const Shape, stream_out: *StreamOut) void {
        c.JPC_Shape_SaveBinaryState(@ptrCast(shape), stream_out);
    }

    pub fn saveWithChildrenAll(shape: *const Shape, stream_out: *StreamOut) void {
        c.JPC_Shape_SaveWithChildren_All(@ptrCast(shape), stream_out);
    }
};

//--------------------------------------------------------------------------------------------------
//
// BoxShape (-> Shape)
//
//--------------------------------------------------------------------------------------------------
pub const BoxShape = opaque {
    pub fn asShape(shape: *const BoxShape) *const Shape {
        return @ptrCast(shape);
    }

    pub fn asShapeMut(shape: *BoxShape) *Shape {
        return @ptrCast(shape);
    }

    pub fn asBoxShape(shape: *const Shape) *const BoxShape {
        assert(shape.getSubType() == .box);
        return @ptrCast(shape);
    }

    pub fn asBoxShapeMut(shape: *Shape) *BoxShape {
        assert(shape.getSubType() == .box);
        return @ptrCast(shape);
    }

    pub fn getHalfExtent(shape: *const BoxShape) [3]f32 {
        var half_extent: [3]f32 = undefined;
        c.JPC_BoxShape_GetHalfExtent(@as(*const c.JPC_BoxShape, @ptrCast(shape)), &half_extent);
        return half_extent;
    }
};

//--------------------------------------------------------------------------------------------------
//
// ConvexHullShape (-> Shape)
//
//--------------------------------------------------------------------------------------------------
pub const ConvexHullShape = opaque {
    pub fn asShape(shape: *const BoxShape) *const Shape {
        return @ptrCast(shape);
    }

    pub fn asShapeMut(shape: *BoxShape) *Shape {
        return @ptrCast(shape);
    }

    pub fn asConvexHullShape(shape: *const Shape) *const ConvexHullShape {
        assert(shape.getSubType() == .convex_hull);
        return @ptrCast(shape);
    }

    pub fn asConvexHullShapeMut(shape: *Shape) *ConvexHullShape {
        assert(shape.getSubType() == .convex_hull);
        return @ptrCast(shape);
    }

    pub fn getNumPoints(shape: *const ConvexHullShape) u32 {
        return c.JPC_ConvexHullShape_GetNumPoints(@ptrCast(shape));
    }

    pub fn getPoint(shape: *const ConvexHullShape, in_point_index: u32) [3]f32 {
        var point: [3]f32 = undefined;
        c.JPC_ConvexHullShape_GetPoint(@ptrCast(shape), in_point_index, &point);
        return point;
    }

    pub fn getNumFaces(shape: *const ConvexHullShape) u32 {
        return c.JPC_ConvexHullShape_GetNumFaces(@ptrCast(shape));
    }

    pub fn getNumVerticesInFace(shape: *const ConvexHullShape, in_face_index: u32) u32 {
        return c.JPC_ConvexHullShape_GetNumVerticesInFace(
            @ptrCast(shape),
            in_face_index,
        );
    }

    /// out_vertex_buffer points to memory owned by the caller.
    /// If out_vertex_buffer.len is less than getNumVerticesInFace(in_face_index), not all vertices are returned.
    /// The return value gives the number of vertices in the face, identical to getNumVerticesInFace(in_face_index).
    pub fn getFaceVertices(shape: *const ConvexHullShape, in_face_index: u32, out_vertex_buffer: []u32) u32 {
        return c.JPC_ConvexHullShape_GetFaceVertices(
            @ptrCast(shape),
            in_face_index,
            @intCast(out_vertex_buffer.len),
            out_vertex_buffer.ptr,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// ConstraintSettings
//
//--------------------------------------------------------------------------------------------------
pub const ConstraintSettings = opaque {
    pub fn addRef(constraint_settings: *ConstraintSettings) void {
        c.JPC_ConstraintSettings_AddRef(@ptrCast(constraint_settings));
    }

    pub fn release(constraint_settings: *ConstraintSettings) void {
        c.JPC_ConstraintSettings_Release(@ptrCast(constraint_settings));
    }

    pub fn getRefCount(constraint_settings: *const ConstraintSettings) u32 {
        return c.JPC_ConstraintSettings_GetRefCount(@ptrCast(constraint_settings));
    }

    pub fn getUserData(constraint_settings: *const ConstraintSettings) u64 {
        return c.JPC_ConstraintSettings_GetUserData(@ptrCast(constraint_settings));
    }

    pub fn setUserData(constraint_settings: *ConstraintSettings, user_data: u64) void {
        return c.JPC_ConstraintSettings_SetUserData(
            @ptrCast(constraint_settings),
            user_data,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// TwoBodyConstraintSettings (-> ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
pub const TwoBodyConstraintSettings = opaque {
    pub fn asConstraintSettings(self: *const TwoBodyConstraintSettings) *const ConstraintSettings {
        return @ptrCast(self);
    }

    pub fn asConstraintSettingsMut(self: *TwoBodyConstraintSettings) *ConstraintSettings {
        return @ptrCast(self);
    }

    pub fn createConstraint(
        self: *const TwoBodyConstraintSettings,
        body1: *Body,
        body2: *Body,
    ) !*Constraint {
        return @ptrCast(c.JPC_TwoBodyConstraintSettings_CreateConstraint(
            @ptrCast(self),
            @ptrCast(body1),
            @ptrCast(body2),
        ) orelse return error.FailedToCreateConstraint);
    }
};
//--------------------------------------------------------------------------------------------------
//
// FixedConstraintSettings (-> TwoBodyConstraintSettings -> ConstraintSettings)
//
//--------------------------------------------------------------------------------------------------
pub const FixedConstraintSettings = opaque {
    pub fn create() !*FixedConstraintSettings {
        return @ptrCast(c.JPC_FixedConstraintSettings_Create() orelse
            return error.FailedToCreateFixedConstraintSettings);
    }

    pub fn setSpace(settings: *FixedConstraintSettings, space: Constraint.Space) void {
        c.JPC_FixedConstraintSettings_SetSpace(
            @as(*c.JPC_FixedConstraintSettings, @ptrCast(settings)),
            @intFromEnum(space),
        );
    }

    pub fn setAutoDetectPoint(settings: *FixedConstraintSettings, enabled: bool) void {
        c.JPC_FixedConstraintSettings_SetAutoDetectPoint(
            @as(*c.JPC_FixedConstraintSettings, @ptrCast(settings)),
            enabled,
        );
    }
};
//--------------------------------------------------------------------------------------------------
//
// Constraint
//
//--------------------------------------------------------------------------------------------------
pub const Constraint = opaque {
    pub const Type = enum(c.JPC_ConstraintType) {
        constraint = c.JPC_CONSTRAINT_TYPE_CONSTRAINT,
        two_body_constraint = c.JPC_CONSTRAINT_TYPE_TWO_BODY_CONSTRAINT,
    };

    pub const SubType = enum(c.JPC_ConstraintSubType) {
        fixed = c.JPC_CONSTRAINT_SUB_TYPE_FIXED,
        point = c.JPC_CONSTRAINT_SUB_TYPE_POINT,
        hinge = c.JPC_CONSTRAINT_SUB_TYPE_HINGE,
        slider = c.JPC_CONSTRAINT_SUB_TYPE_SLIDER,
        distance = c.JPC_CONSTRAINT_SUB_TYPE_DISTANCE,
        cone = c.JPC_CONSTRAINT_SUB_TYPE_CONE,
        swing_twist = c.JPC_CONSTRAINT_SUB_TYPE_SWING_TWIST,
        six_dof = c.JPC_CONSTRAINT_SUB_TYPE_SIX_DOF,
        path = c.JPC_CONSTRAINT_SUB_TYPE_PATH,
        vehicle = c.JPC_CONSTRAINT_SUB_TYPE_VEHICLE,
        rack_and_pinion = c.JPC_CONSTRAINT_SUB_TYPE_RACK_AND_PINION,
        gear = c.JPC_CONSTRAINT_SUB_TYPE_GEAR,
        pulley = c.JPC_CONSTRAINT_SUB_TYPE_PULLEY,
        user1 = c.JPC_CONSTRAINT_SUB_TYPE_USER1,
        user2 = c.JPC_CONSTRAINT_SUB_TYPE_USER2,
        user3 = c.JPC_CONSTRAINT_SUB_TYPE_USER3,
        user4 = c.JPC_CONSTRAINT_SUB_TYPE_USER4,
    };

    pub const Space = enum(c.JPC_ConstraintSpace) {
        local_to_body_com = c.JPC_CONSTRAINT_SPACE_LOCAL_TO_BODY_COM,
        world_space = c.JPC_CONSTRAINT_SPACE_WORLD_SPACE,
    };

    // pub fn asConstraint(constraint: *const Constraint) *const Constraint {
    //     return @ptrCast(constraint);
    // }

    // pub fn asConstraintMut(constraint: *Constraint) *Constraint {
    //     return @ptrCast(constraint);
    // }

    pub fn addRef(constraint: *Constraint) void {
        c.JPC_Constraint_AddRef(@ptrCast(constraint));
    }

    pub fn release(constraint: *Constraint) void {
        c.JPC_Constraint_Release(@ptrCast(constraint));
    }

    pub fn getRefCount(constraint: *const Constraint) u32 {
        return c.JPC_Constraint_GetRefCount(@ptrCast(constraint));
    }

    pub fn getType(constraint: *const Constraint) Type {
        return @enumFromInt(c.JPC_Constraint_GetType(@ptrCast(constraint)));
    }

    pub fn getSubType(constraint: *const Constraint) SubType {
        return @enumFromInt(c.JPC_Constraint_GetSubType(@ptrCast(constraint)));
    }

    pub fn getUserData(constraint: *const Constraint) u64 {
        return c.JPC_Constraint_GetUserData(@ptrCast(constraint));
    }

    pub fn setUserData(constraint: *Constraint, user_data: u64) void {
        return c.JPC_Constraint_SetUserData(@ptrCast(constraint), user_data);
    }
};
//--------------------------------------------------------------------------------------------------
//
// Memory allocation
//
//--------------------------------------------------------------------------------------------------
fn zphysicsAlloc(size: usize) callconv(.c) ?*anyopaque {
    state.?.mem_mutex.lock();
    defer state.?.mem_mutex.unlock();

    const ptr = state.?.mem_allocator.rawAlloc(
        size,
        std.mem.Alignment.fromByteUnits(mem_alignment),
        @returnAddress(),
    );
    if (ptr == null) @panic("zphysics: out of memory");

    state.?.mem_allocations.put(
        @intFromPtr(ptr),
        .{ .size = @as(u48, @intCast(size)), .alignment = mem_alignment },
    ) catch @panic("zphysics: out of memory");

    return ptr;
}

fn zphysicsRealloc(maybe_ptr: ?*anyopaque, reported_old_size: usize, new_size: usize) callconv(.c) ?*anyopaque {
    state.?.mem_mutex.lock();
    defer state.?.mem_mutex.unlock();

    const old_size = if (maybe_ptr != null) reported_old_size else 0;

    const old_mem = if (old_size > 0)
        @as([*]align(mem_alignment) u8, @ptrCast(@alignCast(maybe_ptr)))[0..old_size]
    else
        @as([*]align(mem_alignment) u8, undefined)[0..0];

    const mem = state.?.mem_allocator.realloc(old_mem, new_size) catch @panic("zphysics: out of memory");

    if (maybe_ptr != null) {
        const removed = state.?.mem_allocations.remove(@intFromPtr(maybe_ptr.?));
        std.debug.assert(removed);
    }

    state.?.mem_allocations.put(
        @intFromPtr(mem.ptr),
        .{ .size = @as(u48, @intCast(new_size)), .alignment = mem_alignment },
    ) catch @panic("zphysics: out of memory");

    return mem.ptr;
}

fn zphysicsAlignedAlloc(size: usize, alignment: usize) callconv(.c) ?*anyopaque {
    state.?.mem_mutex.lock();
    defer state.?.mem_mutex.unlock();

    const ptr = state.?.mem_allocator.rawAlloc(
        size,
        std.mem.Alignment.fromByteUnits(alignment),
        @returnAddress(),
    );
    if (ptr == null) @panic("zphysics: out of memory");

    state.?.mem_allocations.put(
        @intFromPtr(ptr),
        .{ .size = @as(u32, @intCast(size)), .alignment = @as(u16, @intCast(alignment)) },
    ) catch @panic("zphysics: out of memory");

    return ptr;
}

fn zphysicsFree(maybe_ptr: ?*anyopaque) callconv(.c) void {
    if (maybe_ptr) |ptr| {
        state.?.mem_mutex.lock();
        defer state.?.mem_mutex.unlock();

        const info = state.?.mem_allocations.fetchRemove(@intFromPtr(ptr)).?.value;

        const mem = @as([*]u8, @ptrCast(ptr))[0..info.size];

        state.?.mem_allocator.rawFree(
            mem,
            std.mem.Alignment.fromByteUnits(info.alignment),
            @returnAddress(),
        );
    }
}
//--------------------------------------------------------------------------------------------------
//
// Tests
//
//--------------------------------------------------------------------------------------------------
const expect = std.testing.expect;

test {
    std.testing.refAllDeclsRecursive(@This());
}

extern fn JoltCTest_Basic1() u32;
test "jolt_c.basic1" {
    const ret = JoltCTest_Basic1();
    try expect(ret != 0);
}

extern fn JoltCTest_Basic2() u32;
test "jolt_c.basic2" {
    const ret = JoltCTest_Basic2();
    try expect(ret != 0);
}

extern fn JoltCTest_HelloWorld() u32;
test "jolt_c.helloworld" {
    const ret = JoltCTest_HelloWorld();
    try expect(ret != 0);
}

extern fn JoltCTest_Serialization() u32;
test "jolt_c.serialization" {
    const ret = JoltCTest_Serialization();
    try expect(ret != 0);
}

test "zphysics.BodyCreationSettings" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const approxEql = std.math.approxEqAbs;

    const bcs0 = BodyCreationSettings{};
    const bcs1 = blk: {
        var settings: c.JPC_BodyCreationSettings = undefined;
        c.JPC_BodyCreationSettings_SetDefault(&settings);
        break :blk @as(*const BodyCreationSettings, @ptrCast(&settings)).*;
    };

    try expect(approxEql(Real, bcs0.position[0], bcs1.position[0], 0.0001));
    try expect(approxEql(Real, bcs0.position[1], bcs1.position[1], 0.0001));
    try expect(approxEql(Real, bcs0.position[2], bcs1.position[2], 0.0001));

    try expect(approxEql(f32, bcs0.rotation[0], bcs1.rotation[0], 0.0001));
    try expect(approxEql(f32, bcs0.rotation[1], bcs1.rotation[1], 0.0001));
    try expect(approxEql(f32, bcs0.rotation[2], bcs1.rotation[2], 0.0001));
    try expect(approxEql(f32, bcs0.rotation[3], bcs1.rotation[3], 0.0001));

    try expect(approxEql(f32, bcs0.linear_velocity[0], bcs1.linear_velocity[0], 0.0001));
    try expect(approxEql(f32, bcs0.linear_velocity[1], bcs1.linear_velocity[1], 0.0001));
    try expect(approxEql(f32, bcs0.linear_velocity[2], bcs1.linear_velocity[2], 0.0001));

    try expect(approxEql(f32, bcs0.angular_velocity[0], bcs1.angular_velocity[0], 0.0001));
    try expect(approxEql(f32, bcs0.angular_velocity[1], bcs1.angular_velocity[1], 0.0001));
    try expect(approxEql(f32, bcs0.angular_velocity[2], bcs1.angular_velocity[2], 0.0001));

    try expect(bcs0.user_data == bcs1.user_data);
    try expect(bcs0.object_layer == bcs1.object_layer);
    //try expect(eql(u8, asBytes(&bcs0.collision_group), asBytes(&bcs1.collision_group)));
    try expect(bcs0.motion_type == bcs1.motion_type);
    try expect(bcs0.allow_dynamic_or_kinematic == bcs1.allow_dynamic_or_kinematic);
    try expect(bcs0.is_sensor == bcs1.is_sensor);
    try expect(bcs0.use_manifold_reduction == bcs1.use_manifold_reduction);
    try expect(bcs0.motion_quality == bcs1.motion_quality);
    try expect(bcs0.allow_sleeping == bcs1.allow_sleeping);
    try expect(approxEql(f32, bcs0.friction, bcs1.friction, 0.0001));
    try expect(approxEql(f32, bcs0.restitution, bcs1.restitution, 0.0001));
    try expect(approxEql(f32, bcs0.linear_damping, bcs1.linear_damping, 0.0001));
    try expect(approxEql(f32, bcs0.angular_damping, bcs1.angular_damping, 0.0001));
    try expect(approxEql(f32, bcs0.max_linear_velocity, bcs1.max_linear_velocity, 0.0001));
    try expect(approxEql(f32, bcs0.max_angular_velocity, bcs1.max_angular_velocity, 0.0001));
    try expect(approxEql(f32, bcs0.gravity_factor, bcs1.gravity_factor, 0.0001));
    try expect(bcs0.override_mass_properties == bcs1.override_mass_properties);
    try expect(approxEql(f32, bcs0.inertia_multiplier, bcs1.inertia_multiplier, 0.0001));
    try expect(approxEql(f32, bcs0.mass_properties_override.mass, bcs1.mass_properties_override.mass, 0.0001));
    //try expect(eql(
    //    u8,
    //    asBytes(&bcs0.mass_properties_override.inertia),
    //    asBytes(&bcs1.mass_properties_override.inertia),
    //));
    try expect(bcs0.reserved == bcs1.reserved);
    try expect(bcs0.shape == bcs1.shape);
}

test "zphysics.basic" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @ptrCast(&my_broad_phase_layer_interface),
        @ptrCast(&my_broad_phase_should_collide),
        @ptrCast(&my_object_should_collide),
        .{
            .max_bodies = 1024,
            .num_body_mutexes = 0,
            .max_body_pairs = 1024,
            .max_contact_constraints = 1024,
        },
    );
    defer physics_system.destroy();

    try expect(physics_system.getNumBodies() == 0);
    try expect(physics_system.getNumActiveBodies() == 0);
    try expect(physics_system.getMaxBodies() == 1024);

    {
        physics_system.setGravity(.{ 0, -10.0, 0 });
        const gravity = physics_system.getGravity();
        try expect(gravity[0] == 0 and gravity[1] == -10.0 and gravity[2] == 0);
    }

    try expect(physics_system.getBodyActivationListener() == null);
    physics_system.setBodyActivationListener(null);
    try expect(physics_system.getBodyActivationListener() == null);

    try expect(physics_system.getContactListener() == null);
    physics_system.setContactListener(null);
    try expect(physics_system.getContactListener() == null);

    _ = physics_system.getBodyInterface();
    _ = physics_system.getBodyInterfaceNoLock();
    _ = physics_system.getBodyInterfaceMut();
    _ = physics_system.getBodyInterfaceMutNoLock();
    _ = physics_system.getBodyLockInterface();
    _ = physics_system.getBodyLockInterfaceNoLock();
    _ = physics_system.getNarrowPhaseQuery();
    _ = physics_system.getNarrowPhaseQueryNoLock();

    var my_step_listener = test_cb1.MyPhysicsStepListener{
        .physics_system = physics_system,
    };
    physics_system.addStepListener(@ptrCast(@alignCast(&my_step_listener)));

    physics_system.optimizeBroadPhase();
    try physics_system.update(1.0 / 60.0, .{ .collision_steps = 1 });
    try physics_system.update(1.0 / 60.0, .{});

    physics_system.removeStepListener(@ptrCast(@alignCast(&my_step_listener)));

    var box_shape_settings: ?*BoxShapeSettings = null;
    box_shape_settings = try BoxShapeSettings.create(.{ 1.0, 2.0, 3.0 });
    defer {
        if (box_shape_settings) |bss| bss.asShapeSettings().release();
    }

    box_shape_settings.?.asConvexShapeSettings().setDensity(2.0);
    try expect(box_shape_settings.?.asConvexShapeSettings().getDensity() == 2.0);

    box_shape_settings.?.asShapeSettings().setUserData(123);
    try expect(box_shape_settings.?.asShapeSettings().getUserData() == 123);

    box_shape_settings.?.setConvexRadius(0.5);
    try expect(box_shape_settings.?.getConvexRadius() == 0.5);

    try expect(box_shape_settings.?.asShapeSettings().getRefCount() == 1);
    box_shape_settings.?.asShapeSettings().addRef();
    try expect(box_shape_settings.?.asShapeSettings().getRefCount() == 2);
    box_shape_settings.?.asShapeSettings().release();
    try expect(box_shape_settings.?.asShapeSettings().getRefCount() == 1);

    {
        var he = box_shape_settings.?.getHalfExtent();
        try expect(he[0] == 1.0 and he[1] == 2.0 and he[2] == 3.0);
        box_shape_settings.?.setHalfExtent(.{ 4.0, 5.0, 6.0 });
        he = box_shape_settings.?.getHalfExtent();
        try expect(he[0] == 4.0 and he[1] == 5.0 and he[2] == 6.0);
    }

    try expect(box_shape_settings.?.asConvexShapeSettings().getDensity() == 2.0);
    try expect(box_shape_settings.?.asShapeSettings().getRefCount() == 1);

    const box_shape = try box_shape_settings.?.asShapeSettings().createShape();
    defer box_shape.release();

    {
        const bs = try box_shape_settings.?.asShapeSettings().createShape();
        defer bs.release();
        try expect(bs == box_shape);
        try expect(bs.getRefCount() == 3);
    }

    try expect(box_shape.getRefCount() == 2);
    box_shape_settings.?.asShapeSettings().release();
    box_shape_settings = null;
    try expect(box_shape.getRefCount() == 1);

    try expect(box_shape.getType() == .convex);
    try expect(box_shape.getSubType() == .box);

    box_shape.setUserData(456);
    try expect(box_shape.getUserData() == 456);
}

test "zphysics.shape.sphere" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const sphere_shape_settings = try SphereShapeSettings.create(10.0);
    defer sphere_shape_settings.asShapeSettings().release();

    try expect(sphere_shape_settings.getRadius() == 10.0);

    sphere_shape_settings.setRadius(2.0);
    try expect(sphere_shape_settings.getRadius() == 2.0);

    sphere_shape_settings.asConvexShapeSettings().setDensity(2.0);
    try expect(sphere_shape_settings.asConvexShapeSettings().getDensity() == 2.0);

    sphere_shape_settings.asConvexShapeSettings().setMaterial(null);
    try expect(sphere_shape_settings.asConvexShapeSettings().getMaterial() == null);

    const sphere_shape = try sphere_shape_settings.asShapeSettings().createShape();
    defer sphere_shape.release();

    try expect(sphere_shape.getRefCount() == 2);
    try expect(sphere_shape.getType() == .convex);
    try expect(sphere_shape.getSubType() == .sphere);

    sphere_shape.setUserData(1456);
    try expect(sphere_shape.getUserData() == 1456);
}

test "zphysics.shape.capsule" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const capsule_shape_settings = try CapsuleShapeSettings.create(10.0, 2.0);
    defer capsule_shape_settings.asShapeSettings().release();

    try expect(capsule_shape_settings.getRadius() == 2.0);
    try expect(capsule_shape_settings.getHalfHeight() == 10.0);

    capsule_shape_settings.setRadius(4.0);
    try expect(capsule_shape_settings.getRadius() == 4.0);

    capsule_shape_settings.setHalfHeight(1.0);
    try expect(capsule_shape_settings.getHalfHeight() == 1.0);

    const capsule_shape = try capsule_shape_settings.asShapeSettings().createShape();
    defer capsule_shape.release();

    try expect(capsule_shape.getRefCount() == 2);
    try expect(capsule_shape.getType() == .convex);
    try expect(capsule_shape.getSubType() == .capsule);

    capsule_shape.setUserData(146);
    try expect(capsule_shape.getUserData() == 146);
}

test "zphysics.shape.taperedcapsule" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const capsule_shape_settings = try TaperedCapsuleShapeSettings.create(10.0, 2.0, 3.0);
    defer capsule_shape_settings.asShapeSettings().release();

    try expect(capsule_shape_settings.getTopRadius() == 2.0);
    try expect(capsule_shape_settings.getBottomRadius() == 3.0);
    try expect(capsule_shape_settings.getHalfHeight() == 10.0);

    capsule_shape_settings.setTopRadius(4.0);
    try expect(capsule_shape_settings.getTopRadius() == 4.0);

    capsule_shape_settings.setBottomRadius(1.0);
    try expect(capsule_shape_settings.getBottomRadius() == 1.0);

    const capsule_shape = try capsule_shape_settings.asShapeSettings().createShape();
    defer capsule_shape.release();

    try expect(capsule_shape.getRefCount() == 2);
    try expect(capsule_shape.getType() == .convex);
    try expect(capsule_shape.getSubType() == .tapered_capsule);

    capsule_shape.setUserData(1146);
    try expect(capsule_shape.getUserData() == 1146);
}

test "zphysics.shape.cylinder" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const cylinder_shape_settings = try CylinderShapeSettings.create(10.0, 2.0);
    defer cylinder_shape_settings.asShapeSettings().release();

    try expect(cylinder_shape_settings.getRadius() == 2.0);
    try expect(cylinder_shape_settings.getHalfHeight() == 10.0);

    cylinder_shape_settings.setRadius(4.0);
    try expect(cylinder_shape_settings.getRadius() == 4.0);

    cylinder_shape_settings.setHalfHeight(1.0);
    try expect(cylinder_shape_settings.getHalfHeight() == 1.0);

    cylinder_shape_settings.setConvexRadius(0.5);
    try expect(cylinder_shape_settings.getConvexRadius() == 0.5);

    const cylinder_shape = try cylinder_shape_settings.asShapeSettings().createShape();
    defer cylinder_shape.release();

    try expect(cylinder_shape.getRefCount() == 2);
    try expect(cylinder_shape.getType() == .convex);
    try expect(cylinder_shape.getSubType() == .cylinder);

    cylinder_shape.setUserData(146);
    try expect(cylinder_shape.getUserData() == 146);
}

test "zphysics.shape.convexhull" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const points = [_]f32{ 0, 0, 0, 1, 1, 1, 1, 1, 0 };

    const settings = try ConvexHullShapeSettings.create(&points, 3, 12);
    defer settings.asShapeSettings().release();

    settings.setMaxConvexRadius(0.1);
    try expect(settings.getMaxConvexRadius() == 0.1);

    const shape = try settings.asShapeSettings().createShape();
    defer shape.release();

    try expect(shape.getRefCount() == 2);
    try expect(shape.getType() == .convex);
    try expect(shape.getSubType() == .convex_hull);

    shape.setUserData(111);
    try expect(shape.getUserData() == 111);
}

test "zphysics.shape.heightfield" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const points = [16]f32{ 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2 };

    // Height field size is 4x4
    const settings = try HeightFieldShapeSettings.create(&points, 4);
    defer settings.asShapeSettings().release();

    settings.setBlockSize(2);
    settings.setBitsPerSample(6);
    settings.setOffset(.{ 1, 2, 3 });
    settings.setScale(.{ 4, 5, 6 });

    try expect(settings.getBlockSize() == 2);
    try expect(settings.getBitsPerSample() == 6);
    try expect(settings.getOffset()[0] == 1);
    try expect(settings.getOffset()[1] == 2);
    try expect(settings.getOffset()[2] == 3);
    try expect(settings.getScale()[0] == 4);
    try expect(settings.getScale()[1] == 5);
    try expect(settings.getScale()[2] == 6);

    const shape = try settings.asShapeSettings().createShape();
    defer shape.release();

    try expect(shape.getRefCount() == 2);
    try expect(shape.getType() == .height_field);
    try expect(shape.getSubType() == .height_field);

    shape.setUserData(1112);
    try expect(shape.getUserData() == 1112);
}

test "zphysics.shape.meshshape" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const vertices = [9]f32{ 0, 0, 0, 1, 1, 1, 1, -1, 1 };
    const indices = [3]u32{ 0, 1, 2 };

    const settings = try MeshShapeSettings.create(&vertices, 3, @sizeOf([3]f32), &indices);
    defer settings.asShapeSettings().release();

    settings.setMaxTrianglesPerLeaf(4);
    settings.sanitize();

    try expect(settings.getMaxTrianglesPerLeaf() == 4);

    const shape = try settings.asShapeSettings().createShape();
    defer shape.release();

    try expect(shape.getRefCount() == 2);
    try expect(shape.getType() == .mesh);
    try expect(shape.getSubType() == .mesh);

    shape.setUserData(1112);
    try expect(shape.getUserData() == 1112);
}

test "zphysics.body.basic" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{
            .max_bodies = 1024,
            .num_body_mutexes = 0,
            .max_body_pairs = 1024,
            .max_contact_constraints = 1024,
        },
    );
    defer physics_system.destroy();

    const body_interface_mut = physics_system.getBodyInterfaceMut();
    const body_interface = physics_system.getBodyInterface();

    const floor_shape_settings = try BoxShapeSettings.create(.{ 100.0, 1.0, 100.0 });
    defer floor_shape_settings.asShapeSettings().release();

    const floor_shape = try floor_shape_settings.asShapeSettings().createShape();
    defer floor_shape.release();

    var shape_ray = RayCast{ .origin = .{ 0, 2, 0, 1 }, .direction = .{ 101, -1, 0, 0 } };
    var shape_result = floor_shape.castRay(shape_ray, .{});
    try expect(shape_result.has_hit == false);

    shape_ray = RayCast{ .origin = .{ 0, 2, 0, 1 }, .direction = .{ 100, -1, 0, 0 } };
    shape_result = floor_shape.castRay(shape_ray, .{});
    try expect(shape_result.has_hit == true);

    const floor_settings = BodyCreationSettings{
        .position = .{ 0.0, -1.0, 0.0, 1.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .shape = floor_shape,
        .motion_type = .static,
        .object_layer = test_cb1.object_layers.non_moving,
    };
    const body_id = try body_interface_mut.createAndAddBody(floor_settings, .activate);
    defer {
        body_interface_mut.removeBody(body_id);
        body_interface_mut.destroyBody(body_id);
    }

    physics_system.optimizeBroadPhase();

    {
        const query = physics_system.getNarrowPhaseQuery();

        var result = query.castRay(.{ .origin = .{ 0, 10, 0, 1 }, .direction = .{ 0, -20, 0, 0 } }, .{});
        try expect(result.has_hit == true);
        try expect(result.hit.body_id == body_id);
        try expect(result.hit.sub_shape_id == .empty);
        try expect(std.math.approxEqAbs(f32, result.hit.fraction, 0.5, 0.001) == true);

        result = query.castRay(.{ .origin = .{ 0, 10, 0, 1 }, .direction = .{ 0, 20, 0, 0 } }, .{});
        try expect(result.has_hit == false);
        try expect(result.hit.body_id == .invalid);

        result = query.castRay(.{ .origin = .{ 0, 10, 0, 1 }, .direction = .{ 0, -5, 0, 0 } }, .{});
        try expect(result.has_hit == false);
        try expect(result.hit.body_id == .invalid);

        const ray = c.JPC_RRayCast{
            .origin = .{ 0, 10, 0, 0 },
            .direction = .{ 0, -20, 0, 0 },
        };
        var hit: c.JPC_RayCastResult = .{
            .body_id = BodyId.invalid.toJpc(),
            .fraction = 1.0 + flt_epsilon,
            .sub_shape_id = undefined,
        };
        const has_hit = c.JPC_NarrowPhaseQuery_CastRay(
            @as(*const c.JPC_NarrowPhaseQuery, @ptrCast(query)),
            &ray,
            &hit,
            null, // broad_phase_layer_filter
            null, // object_layer_filter
            null, // body_filter
        );
        try expect(has_hit == true);
        try expect(std.math.approxEqAbs(f32, hit.fraction, 0.5, 0.001) == true);
    }

    {
        var body_ids = std.ArrayList(BodyId).init(std.testing.allocator);
        defer body_ids.deinit();
        try physics_system.getBodyIds(&body_ids);
        try expect(body_ids.items.len == 1);
        try expect(body_ids.capacity >= physics_system.getMaxBodies());
        try expect(body_ids.items[0] == body_id);
    }

    {
        var body_ids = std.ArrayList(BodyId).init(std.testing.allocator);
        defer body_ids.deinit();
        try physics_system.getActiveBodyIds(&body_ids);
        try expect(body_ids.items.len == 0);
        try expect(body_ids.capacity >= physics_system.getMaxBodies());
    }

    {
        const lock_interface = physics_system.getBodyLockInterfaceNoLock();

        var read_lock: BodyLockRead = .{};
        read_lock.lock(lock_interface, body_id);
        defer read_lock.unlock();

        if (read_lock.body) |locked_body| {
            const all_bodies: []const *const Body = physics_system.getBodiesUnsafe();

            try expect(isValidBodyPointer(all_bodies[body_id.indexBits()]));
            try expect(locked_body == all_bodies[body_id.indexBits()]);
            try expect(locked_body.id == body_id);
            try expect(locked_body.id == all_bodies[body_id.indexBits()].id);
        }
    }
    {
        const lock_interface = physics_system.getBodyLockInterface();

        var write_lock: BodyLockWrite = .{};
        write_lock.lock(lock_interface, body_id);
        defer write_lock.unlock();

        if (write_lock.body) |locked_body| {
            const all_bodies_mut: []const *Body = physics_system.getBodiesMutUnsafe();

            try expect(isValidBodyPointer(all_bodies_mut[body_id.indexBits()]));
            try expect(locked_body == all_bodies_mut[body_id.indexBits()]);
            try expect(locked_body.id == body_id);
            try expect(locked_body.id == all_bodies_mut[body_id.indexBits()].id);

            all_bodies_mut[body_id.indexBits()].user_data = 12345;
            try expect(all_bodies_mut[body_id.indexBits()].user_data == 12345);
        }
    }

    try expect(physics_system.getNumBodies() == 1);
    try expect(physics_system.getNumActiveBodies() == 0);

    {
        const body1 = try body_interface_mut.createBody(floor_settings);
        defer body_interface_mut.destroyBody(body1.id);
        try expect(body_interface.isAdded(body1.getId()) == false);

        const xform = body1.getWorldTransform();
        try expect(xform.rotation[0] == 1.0);
        try expect(xform.position[1] == -1.0);

        body1.setUserData(12345);
        try expect(body1.getUserData() == 12345);

        body1.setMotionType(.static);
        try expect(body1.getMotionType() == .static);

        body1.setCollisionGroup(.{ .group_id = 123 });
        try expect(body1.getCollisionGroup().group_id == 123);
        body1.getCollisionGroupMut().group_id += 1;
        try expect(body1.getCollisionGroup().group_id == 124);

        body_interface_mut.addBody(body1.getId(), .activate);
        try expect(body_interface_mut.isAdded(body1.getId()) == true);
        try expect(body_interface.isActive(body1.id) == false);

        body_interface_mut.removeBody(body1.getId());
        try expect(body_interface.isAdded(body1.id) == false);

        try expect(physics_system.getNumBodies() == 2);
        try expect(physics_system.getNumActiveBodies() == 0);
    }

    try expect(physics_system.getNumBodies() == 1);
    try expect(physics_system.getNumActiveBodies() == 0);
}

test "zphysics.body.motion" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @as(*const BroadPhaseLayerInterface, @ptrCast(&my_broad_phase_layer_interface)),
        @as(*const ObjectVsBroadPhaseLayerFilter, @ptrCast(&my_broad_phase_should_collide)),
        @as(*const ObjectLayerPairFilter, @ptrCast(&my_object_should_collide)),
        .{},
    );
    defer physics_system.destroy();

    const body_interface = physics_system.getBodyInterfaceMut();
    const lock_interface = physics_system.getBodyLockInterface();

    const shape_settings = try BoxShapeSettings.create(.{ 1.0, 2.0, 3.0 });
    defer shape_settings.asShapeSettings().release();

    const shape = try shape_settings.asShapeSettings().createShape();
    defer shape.release();

    const body_settings = BodyCreationSettings{
        .position = .{ 0.0, 10.0, 0.0, 1.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .shape = shape,
        .motion_type = .dynamic,
        .object_layer = test_cb1.object_layers.moving,
    };
    const body_id = try body_interface.createAndAddBody(body_settings, .activate);
    defer body_interface.removeAndDestroyBody(body_id);

    physics_system.optimizeBroadPhase();

    var write_lock: BodyLockWrite = .{};
    write_lock.lock(lock_interface, body_id);
    defer write_lock.unlock();
    const body = write_lock.body.?;

    body.setRestitution(0.5);
    body.setFriction(0.25);
    body.setUserData(0xC0DE_C0DE_C0DE_C0DE);
    body.setAllowSleeping(false);

    try expect(body.getFriction() == 0.25);
    try expect(body.friction == 0.25);
    try expect(body.getRestitution() == 0.5);
    try expect(body.restitution == 0.5);
    try expect(body.isInBroadPhase() == true);
    try expect(body.isDynamic() == true);
    try expect(body.isStatic() == false);
    try expect(body.isSensor() == false);
    try expect(body.getShape() == shape);
    try expect(body.shape == shape);
    try expect(body.getUserData() == 0xC0DE_C0DE_C0DE_C0DE);
    try expect(body.user_data == 0xC0DE_C0DE_C0DE_C0DE);
    try expect(body.getAllowSleeping() == false);

    const normal0 = body.getWorldSpaceSurfaceNormal(.empty, .{ 0, 12, 0 });
    const normal1 = body.getWorldSpaceSurfaceNormal(.empty, .{ -1, 10, 0 });

    try expect(std.math.approxEqAbs(f32, normal0[0], 0.0, 0.001) == true);
    try expect(std.math.approxEqAbs(f32, normal0[1], 1.0, 0.001) == true);
    try expect(std.math.approxEqAbs(f32, normal0[2], 0.0, 0.001) == true);
    try expect(std.math.approxEqAbs(f32, normal1[0], -1.0, 0.001) == true);
    try expect(std.math.approxEqAbs(f32, normal1[1], 0.0, 0.001) == true);
    try expect(std.math.approxEqAbs(f32, normal1[2], 0.0, 0.001) == true);

    const motion = body.getMotionPropertiesMut();

    try expect(body.motion_properties.? == motion);

    motion.setLinearDamping(0.5);
    motion.setAngularDamping(0.25);
    motion.setGravityFactor(0.5);

    try expect(motion.allow_sleeping == false);
    try expect(motion.getLinearDamping() == 0.5);
    try expect(motion.linear_damping == 0.5);
    try expect(motion.getAngularDamping() == 0.25);
    try expect(motion.angular_damping == 0.25);
    try expect(motion.getGravityFactor() == 0.5);
    try expect(motion.gravity_factor == 0.5);
}

test "zphysics.debugrenderer" {
    if (!debug_renderer_enabled) return;

    try init(std.testing.allocator, .{});
    defer deinit();

    var my_debug_renderer = test_cb1.MyDebugRenderer{};
    try DebugRenderer.createSingleton(&my_debug_renderer);
    defer DebugRenderer.destroySingleton();

    const my_broad_phase_layer_interface = test_cb1.MyBroadphaseLayerInterface.init();
    const my_broad_phase_should_collide = test_cb1.MyObjectVsBroadPhaseLayerFilter{};
    const my_object_should_collide = test_cb1.MyObjectLayerPairFilter{};

    const physics_system = try PhysicsSystem.create(
        @ptrCast(&my_broad_phase_layer_interface),
        @ptrCast(&my_broad_phase_should_collide),
        @ptrCast(&my_object_should_collide),
        .{},
    );
    defer physics_system.destroy();

    try std.testing.expectEqual(24, my_debug_renderer.prim_head);

    const shape_settings = try BoxShapeSettings.create(.{ 1.0, 2.0, 3.0 });
    defer shape_settings.asShapeSettings().release();

    const shape = try shape_settings.asShapeSettings().createShape();
    defer shape.release();

    const body_settings = BodyCreationSettings{
        .position = .{ 0.0, 10.0, 0.0, 1.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .shape = shape,
        .motion_type = .dynamic,
        .object_layer = test_cb1.object_layers.moving,
    };

    const body_interface = physics_system.getBodyInterfaceMut();
    const body_id = try body_interface.createAndAddBody(body_settings, .activate);
    defer body_interface.removeAndDestroyBody(body_id);

    physics_system.optimizeBroadPhase();

    try physics_system.update(0.1, .{});

    const draw_settings: DebugRenderer.BodyDrawSettings = .{};
    const draw_filter = DebugRenderer.createBodyDrawFilter(test_cb1.MyDebugRenderer.shouldBodyDraw);
    defer DebugRenderer.destroyBodyDrawFilter(draw_filter);

    physics_system.drawBodies(&draw_settings, draw_filter);
    try std.testing.expectEqual(1, my_debug_renderer.draw_geometry_count);
}

test "zphysics.serialization" {
    try init(std.testing.allocator, .{});
    defer deinit();

    const half_extents: [3]f32 = .{ 1.0, 2.0, 3.0 };
    const shape_settings = try BoxShapeSettings.create(half_extents);
    defer shape_settings.asShapeSettings().release();

    const shape = try shape_settings.asShapeSettings().createShape();
    defer shape.release();

    var buf: std.ArrayListUnmanaged(u8) = .{};
    defer buf.deinit(std.testing.allocator);

    {
        const writer = buf.writer(std.testing.allocator).any();
        var stream_out = AnyWriterStreamOut.init(&writer);
        shape.saveBinaryState(@ptrCast(&stream_out));
        try std.testing.expectEqual(1 + 8 + 4 + 12 + 4, buf.items.len);
    }

    {
        var stream = std.io.fixedBufferStream(buf.items);
        const reader = stream.reader().any();
        var stream_in = AnyReaderStreamIn.init(&reader);
        const shape_restored = try Shape.restoreFromBinaryState(@ptrCast(&stream_in));
        defer shape_restored.release();

        try std.testing.expectEqual(Shape.SubType.box, shape_restored.getSubType());

        const box_shape_restored = BoxShape.asBoxShape(shape_restored);
        const half_extent_restored = box_shape_restored.getHalfExtent();
        try std.testing.expectEqual(half_extents, half_extent_restored);
    }
}

test {
    std.testing.refAllDecls(@This());
}

const test_cb1 = struct {
    const object_layers = struct {
        const non_moving: ObjectLayer = 0;
        const moving: ObjectLayer = 1;
        const len: u32 = 2;
    };

    const broad_phase_layers = struct {
        const non_moving: BroadPhaseLayer = 0;
        const moving: BroadPhaseLayer = 1;
        const len: u32 = 2;
    };

    const MyBroadphaseLayerInterface = extern struct {
        interface: BroadPhaseLayerInterface = .init(@This()),
        object_to_broad_phase: [object_layers.len]BroadPhaseLayer = undefined,

        fn init() MyBroadphaseLayerInterface {
            var layer_interface: MyBroadphaseLayerInterface = .{};
            layer_interface.object_to_broad_phase[object_layers.non_moving] = broad_phase_layers.non_moving;
            layer_interface.object_to_broad_phase[object_layers.moving] = broad_phase_layers.moving;
            return layer_interface;
        }

        pub fn getNumBroadPhaseLayers(interface: *const BroadPhaseLayerInterface) callconv(.c) u32 {
            const self: *const MyBroadphaseLayerInterface = @alignCast(@fieldParentPtr("interface", interface));
            return @intCast(self.object_to_broad_phase.len);
        }

        pub const getBroadPhaseLayer = if (builtin.abi == .msvc) _getBroadPhaseLayerMsvc else _getBroadPhaseLayer;

        fn _getBroadPhaseLayer(
            interface: *const BroadPhaseLayerInterface,
            layer: ObjectLayer,
        ) callconv(.c) BroadPhaseLayer {
            const self: *const MyBroadphaseLayerInterface = @alignCast(@fieldParentPtr("interface", interface));
            return self.object_to_broad_phase[@intCast(layer)];
        }

        fn _getBroadPhaseLayerMsvc(
            interface: *const BroadPhaseLayerInterface,
            out_layer: *BroadPhaseLayer,
            layer: ObjectLayer,
        ) callconv(.c) *const BroadPhaseLayer {
            const self: *const MyBroadphaseLayerInterface = @alignCast(@fieldParentPtr("interface", interface));
            out_layer.* = self.object_to_broad_phase[@intCast(layer)];
            return out_layer;
        }
    };

    const MyObjectVsBroadPhaseLayerFilter = extern struct {
        filter: ObjectVsBroadPhaseLayerFilter = .init(@This()),

        pub fn shouldCollide(
            _: *const ObjectVsBroadPhaseLayerFilter,
            layer1: ObjectLayer,
            layer2: BroadPhaseLayer,
        ) callconv(.c) bool {
            return switch (layer1) {
                object_layers.non_moving => layer2 == broad_phase_layers.moving,
                object_layers.moving => true,
                else => unreachable,
            };
        }
    };

    const MyObjectLayerPairFilter = extern struct {
        interface: ObjectLayerPairFilter = .init(@This()),

        pub fn shouldCollide(
            _: *const ObjectLayerPairFilter,
            object1: ObjectLayer,
            object2: ObjectLayer,
        ) callconv(.c) bool {
            return switch (object1) {
                object_layers.non_moving => object2 == object_layers.moving,
                object_layers.moving => true,
                else => unreachable,
            };
        }
    };

    const MyPhysicsStepListener = extern struct {
        listener: PhysicsStepListener = .init(@This()),
        steps_heard: u32 = 0,
        physics_system: *PhysicsSystem,

        pub fn onStep(listener: *PhysicsStepListener, context: *const PhysicsStepListenerContext) callconv(.c) void {
            const self: *MyPhysicsStepListener = @alignCast(@fieldParentPtr("listener", listener));
            assert(context.physics_system == self.physics_system);
            self.steps_heard += 1;
        }
    };

    const MyDebugRenderer = if (!debug_renderer_enabled) void else extern struct {
        const MyRenderPrimitive = extern struct {
            allocated: bool = false,
        };

        const VTable = DebugRenderer.VTable(@This());
        vtable: *const VTable = DebugRenderer.initVTable(@This()),

        primitives: [32]MyRenderPrimitive = @splat(.{}),
        prim_head: i32 = -1,
        draw_geometry_count: usize = 0,

        pub fn shouldBodyDraw(_: *const Body) callconv(.c) bool {
            return true;
        }

        fn drawLine(
            self: *MyDebugRenderer,
            from: *const [3]Real,
            to: *const [3]Real,
            color: DebugRenderer.Color,
        ) callconv(.c) void {
            _ = self;
            _ = from;
            _ = to;
            _ = color;
        }
        fn drawTriangle(
            self: *MyDebugRenderer,
            v1: *const [3]Real,
            v2: *const [3]Real,
            v3: *const [3]Real,
            color: DebugRenderer.Color,
        ) callconv(.c) void {
            _ = self;
            _ = v1;
            _ = v2;
            _ = v3;
            _ = color;
        }
        fn createTriangleBatch(
            self: *MyDebugRenderer,
            triangles: [*]DebugRenderer.Triangle,
            triangle_count: u32,
        ) callconv(.c) *DebugRenderer.TriangleBatch {
            _ = triangles;
            _ = triangle_count;
            self.prim_head += 1;
            const prim = &self.primitives[@intCast(self.prim_head)];
            prim.allocated = true;
            return DebugRenderer.createTriangleBatch(prim);
        }
        fn createTriangleBatchIndexed(
            self: *MyDebugRenderer,
            vertices: [*]DebugRenderer.Vertex,
            vertex_count: u32,
            indices: [*]u32,
            index_count: u32,
        ) callconv(.c) *DebugRenderer.TriangleBatch {
            _ = vertices;
            _ = vertex_count;
            _ = indices;
            _ = index_count;
            self.prim_head += 1;
            const prim = &self.primitives[@intCast(self.prim_head)];
            prim.allocated = true;
            return DebugRenderer.createTriangleBatch(prim);
        }
        fn destroyTriangleBatch(
            self: *MyDebugRenderer,
            batch: *anyopaque,
        ) callconv(.c) void {
            _ = self;
            const primitive: *MyRenderPrimitive = @alignCast(@ptrCast(batch));
            primitive.allocated = false;
        }
        fn drawGeometry(
            self: *MyDebugRenderer,
            model_matrix: *const RMatrix,
            world_space_bound: *const AABox,
            lod_scale_sq: f32,
            color: DebugRenderer.Color,
            geometry: *const DebugRenderer.Geometry,
            cull_mode: DebugRenderer.CullMode,
            cast_shadow: DebugRenderer.CastShadow,
            draw_mode: DebugRenderer.DrawMode,
        ) callconv(.c) void {
            _ = model_matrix;
            _ = world_space_bound;
            _ = lod_scale_sq;
            _ = color;
            _ = geometry;
            _ = cull_mode;
            _ = cast_shadow;
            _ = draw_mode;
            self.draw_geometry_count += 1;
        }
        fn drawText3D(
            self: *MyDebugRenderer,
            positions: *const [3]Real,
            string: [*:0]const u8,
            color: DebugRenderer.Color,
            height: f32,
        ) callconv(.c) void {
            _ = self;
            _ = positions;
            _ = string;
            _ = color;
            _ = height;
        }
    };
};
//--------------------------------------------------------------------------------------------------
