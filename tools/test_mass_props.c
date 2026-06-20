#include <stdio.h>
#include <stddef.h>
#include "JoltPhysicsC.h"

int main() {
    printf("JPC_MassProperties:\n");
    printf("  Size: %zu\n", sizeof(JPC_MassProperties));
    printf("  Align: %zu\n", _Alignof(JPC_MassProperties));
    printf("  mass offset: %zu\n", offsetof(JPC_MassProperties, mass));
    printf("  inertia offset: %zu\n", offsetof(JPC_MassProperties, inertia));
    
    printf("\nJPC_BodyCreationSettings:\n");
    printf("  Size: %zu\n", sizeof(JPC_BodyCreationSettings));
    printf("  Align: %zu\n", _Alignof(JPC_BodyCreationSettings));
    printf("  mass_properties_override offset: %zu\n", offsetof(JPC_BodyCreationSettings, mass_properties_override));
    printf("  reserved offset: %zu\n", offsetof(JPC_BodyCreationSettings, reserved));
    printf("  shape offset: %zu\n", offsetof(JPC_BodyCreationSettings, shape));
    
    // Calculate expected layout
    printf("\nExpected layout analysis:\n");
    printf("  mass_properties_override ends at: %zu\n", 
           offsetof(JPC_BodyCreationSettings, mass_properties_override) + sizeof(JPC_MassProperties));
    
    return 0;
}