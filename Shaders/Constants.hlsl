// #define DEBUG_LIGHT_BRANCH
// #define DEBUG_PROBE_BRANCH


// #define CBIRP_CULL_FAR _Udon_CBIRP_CullFar
// #define CBIRP_CULL_FAR _ProjectionParams.z
// #define CBIRP_CULL_FAR 100
// #define CBIRP_PLAYER_POS _WorldSpaceCameraPos.xyz
// #define CBIRP_PLAYER_POS _Udon_CBIRP_PlayerCamera.xyz
#define CBIRP_PLAYER_POS _Udon_CBIRP_Uniforms[uint2(0,0)].xyz
#define CBIRP_CULL_FAR _Udon_CBIRP_Uniforms[uint2(0,0)].w

#include "ConstantsGenerated.hlsl"

#define CBIRP_CULLING_SIZE uint2(2048, 128)
#define CBIRP_VOXELS_COUNT ((CBIRP_CULLING_SIZE.y / 2 / 2) - 1)
#define CBIRP_VOXELS_SIZE CBIRP_CULL_FAR / float(CBIRP_VOXELS_COUNT / 2.0)
#define CBIRP_UNIFORMS_SIZE uint2(128, 4)
#define CBIRP_UNIFORMS_PROBE_START 4
#define CBIRP_CULLING_INDEX_BITS 8

#ifdef UNITY_PBS_USE_BRDF2
    #define CBIRP_LOW
#endif

#define CBIRP_GLOBAL_UNIFORMS


#define CBIRP_ASSUME_NO_Y
#ifdef CBIRP_ASSUME_NO_Y
    #undef CBIRP_CULLING_SIZE
    #undef CBIRP_VOXELS_COUNT
    #define CBIRP_CULLING_SIZE uint2(256, 512)
    #define CBIRP_VOXELS_COUNT CBIRP_CULLING_SIZE.x
#endif
