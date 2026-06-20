#include <stdio.h>
#include <stddef.h>
#include "JoltPhysicsC.h"

int main() {
    printf("JPC_BodyCreationSettings:\n");
    printf("  Size: %zu\n", sizeof(JPC_BodyCreationSettings));
    printf("  Align: %zu\n", _Alignof(JPC_BodyCreationSettings));
    
    printf("\nField offsets:\n");
    printf("  position: %zu\n", offsetof(JPC_BodyCreationSettings, position));
    printf("  rotation: %zu\n", offsetof(JPC_BodyCreationSettings, rotation));
    printf("  linear_velocity: %zu\n", offsetof(JPC_BodyCreationSettings, linear_velocity));
    printf("  angular_velocity: %zu\n", offsetof(JPC_BodyCreationSettings, angular_velocity));
    printf("  user_data: %zu\n", offsetof(JPC_BodyCreationSettings, user_data));
    printf("  object_layer: %zu\n", offsetof(JPC_BodyCreationSettings, object_layer));
    printf("  motion_type: %zu\n", offsetof(JPC_BodyCreationSettings, motion_type));
    printf("  allowed_DOFs: %zu\n", offsetof(JPC_BodyCreationSettings, allowed_DOFs));
    printf("  allow_dynamic_or_kinematic: %zu\n", offsetof(JPC_BodyCreationSettings, allow_dynamic_or_kinematic));
    printf("  is_sensor: %zu\n", offsetof(JPC_BodyCreationSettings, is_sensor));
    printf("  collide_kinematic_vs_non_dynamic: %zu\n", offsetof(JPC_BodyCreationSettings, collide_kinematic_vs_non_dynamic));
    printf("  use_manifold_reduction: %zu\n", offsetof(JPC_BodyCreationSettings, use_manifold_reduction));
    printf("  apply_gyroscopic_force: %zu\n", offsetof(JPC_BodyCreationSettings, apply_gyroscopic_force));
    printf("  motion_quality: %zu\n", offsetof(JPC_BodyCreationSettings, motion_quality));
    printf("  enhanced_internal_edge_removal: %zu\n", offsetof(JPC_BodyCreationSettings, enhanced_internal_edge_removal));
    printf("  allow_sleeping: %zu\n", offsetof(JPC_BodyCreationSettings, allow_sleeping));
    printf("  friction: %zu\n", offsetof(JPC_BodyCreationSettings, friction));
    printf("  restitution: %zu\n", offsetof(JPC_BodyCreationSettings, restitution));
    printf("  linear_damping: %zu\n", offsetof(JPC_BodyCreationSettings, linear_damping));
    printf("  angular_damping: %zu\n", offsetof(JPC_BodyCreationSettings, angular_damping));
    printf("  max_linear_velocity: %zu\n", offsetof(JPC_BodyCreationSettings, max_linear_velocity));
    printf("  max_angular_velocity: %zu\n", offsetof(JPC_BodyCreationSettings, max_angular_velocity));
    printf("  gravity_factor: %zu\n", offsetof(JPC_BodyCreationSettings, gravity_factor));
    printf("  num_velocity_steps_override: %zu\n", offsetof(JPC_BodyCreationSettings, num_velocity_steps_override));
    printf("  num_position_steps_override: %zu\n", offsetof(JPC_BodyCreationSettings, num_position_steps_override));
    printf("  override_mass_properties: %zu\n", offsetof(JPC_BodyCreationSettings, override_mass_properties));
    printf("  inertia_multiplier: %zu\n", offsetof(JPC_BodyCreationSettings, inertia_multiplier));
    printf("  mass_properties_override: %zu\n", offsetof(JPC_BodyCreationSettings, mass_properties_override));
    printf("  reserved: %zu\n", offsetof(JPC_BodyCreationSettings, reserved));
    printf("  shape: %zu\n", offsetof(JPC_BodyCreationSettings, shape));
    
    // Test pointer representation
    const JPC_Shape* test_ptr = (const JPC_Shape*)0x1234567890ABCDEFULL;
    unsigned char* ptr_bytes = (unsigned char*)&test_ptr;
    printf("\nPointer representation (0x1234567890ABCDEF):\n");
    printf("  Bytes: ");
    for (int i = 0; i < sizeof(test_ptr); i++) {
        printf("%02x ", ptr_bytes[i]);
    }
    printf("\n");
    
    return 0;
}