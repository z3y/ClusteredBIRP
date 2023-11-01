#ifndef CBIRP_INCLUDED
#define CBIRP_INCLUDED

Texture2D<float4> _Udon_CBIRP_Uniforms;
Texture2D<uint4> _Udon_CBIRP_Clusters;
TextureCubeArray _Udon_CBIRP_ReflectionProbes;
// TextureCube _Udon_CBIRP_SkyProbe;
SamplerState sampler_Udon_CBIRP_ReflectionProbes;
Texture2D _Udon_CBIRP_ShadowMask;

#include "Constants.hlsl"
#include "Filament.hlsl"
#include "Packing.hlsl"

#define CBIRP_TYPE_LIGHT 0
#define CBIRP_TYPE_PROBE 1
static uint cbirpTempIndexable[3];

#define CBIRP_CLUSTER_START(cluster, type) \
    uint4 flags4x = _Udon_CBIRP_Clusters[uint2(type ? 3 : 0, cluster.x)]; \
    uint4 flags4y = _Udon_CBIRP_Clusters[uint2(type ? 4 : 1, cluster.y)]; \
    uint4 flags4z = _Udon_CBIRP_Clusters[uint2(type ? 5 : 2, cluster.z)]; \
    uint4 flags4 = flags4x & flags4y & flags4z; \
    cbirpTempIndexable[0] = flags4.y; \
    cbirpTempIndexable[1] = flags4.z; \
    cbirpTempIndexable[2] = flags4.w; \
    uint flags = flags4.x; \
    uint component = 0; \
    while (component < 3) { \
        [branch] if (flags == 0) { flags = cbirpTempIndexable[component]; component++; continue; } \
        uint index = firstbitlow(flags); \
        flags ^= 0x1 << index; \
        index += 32 * component; \

#define CBIRP_CLUSTER_END \
    } \

// uniform float _Udon_CBIRP_CullFar;
// uniform float4 _Udon_CBIRP_PlayerCamera;
// uniform float4 _Udon_CBIRP_ProbeDecodeInstructions;

namespace CBIRP
{
    // from filament
    float GetSquareFalloffAttenuation(float distanceSquare, float lightInvRadius2)
    {
        float factor = distanceSquare * lightInvRadius2;
        float smoothFactor = saturate(1.0 - factor * factor);
        return (smoothFactor * smoothFactor) / max(distanceSquare, 1e-4);
    }
    
    // modified attenuation up close, inv square falloff is too bright
    float GetSquareFalloffAttenuationCustom(float distanceSquare, float lightInvRadius2)
    {
        float factor = distanceSquare * lightInvRadius2;
        float smoothFactor = saturate(1.0 - factor * factor);
        return (smoothFactor * smoothFactor) / (distanceSquare + 1.0);
    }

    float GetSpotAngleAttenuation(float3 spotForward, float3 l, float spotScale, float spotOffset)
    {
        float cd = dot(-spotForward, l);
        float attenuation = saturate(cd * spotScale + spotOffset);
        return attenuation * attenuation;
    }

    float3 Heatmap(float v)
    {
        float3 r = v * 2.1 - float3(1.8, 1.14, 0.3);
        return 1.0 - r * r;
    }

    struct Light
    {
        float3 positionWS;
        half range;
        bool spot;
        bool enabled;
        half3 color;
        bool hasShadowmask;
        uint shadowmaskID;
        half3 direction;
        half spotOffset;
        half spotScale;
        bool specularOnly;

        bool hasCookie;
        uint cookieID;

        static Light DecodeLight(uint index)
        {
            Light l = (Light)0;
            float4 data0 = _Udon_CBIRP_Uniforms[uint2(index, 0)];
            float4 data1 = _Udon_CBIRP_Uniforms[uint2(index, 1)];

            l.enabled = data0.w != 0;
            l.positionWS = data0.xyz;
            half unpackedData0a;
            uint unpackedData0b;
            CBIRP_Packing::UnpackFloatAndUint(data0.w, unpackedData0a, unpackedData0b);
            l.range = abs(unpackedData0a);
            l.spot = unpackedData0a < 0;

            l.hasShadowmask = unpackedData0b & 0x1;
            l.shadowmaskID = (unpackedData0b & 0x6) >> 1;
            l.hasCookie = unpackedData0b & 0x8;
            l.cookieID = (unpackedData0b & 0xf0) >> 4;

            half4 unpackedData1a;
            half4 unpackedData1b;
            CBIRP_Packing::UnpackFloat(data1, unpackedData1a, unpackedData1b);

            l.color = unpackedData1a.xyz;
            l.direction = unpackedData1b.xyz;
            l.spotScale = abs(unpackedData1a.w);
            l.spotOffset = unpackedData1b.w;

            l.specularOnly = unpackedData1a.w < 0;

            return l;
        }
    };

    struct ReflectionProbe
    {
        // data0
        float3 positionWS;
        half intensity;
        bool boxProjection;

        // data 1
        float3 boxMin;
        float arrayIndex;
        
        //data 2
        float3 boxMax;
        half blendDistance;

        static ReflectionProbe DecodeReflectionProbe(uint index)
        {
            ReflectionProbe p = (ReflectionProbe)0;
            float4 data0 = _Udon_CBIRP_Uniforms[uint2(index, 2)];
            float4 data1 = _Udon_CBIRP_Uniforms[uint2(index, 3)];

            p.positionWS = data0.xyz;
            p.blendDistance = data0.w;

            half4 unpackedData1a;
            half4 unpackedData1b;
            CBIRP_Packing::UnpackFloat(data1, unpackedData1a, unpackedData1b);
            half3 probeCenter = unpackedData1b.xyz;
            half3 probeSizeHalf = unpackedData1a.xyz;

            p.intensity = abs(unpackedData1a.w);
            p.boxProjection = unpackedData1a.w > 0.0;
            p.arrayIndex = unpackedData1b.w;

            p.boxMin = p.positionWS + probeCenter - probeSizeHalf;
            p.boxMax = p.positionWS + probeCenter + probeSizeHalf;

            return p;
        }
    };

    // Normalize that account for vectors with zero length
    float3 SafeNormalize(float3 inVec)
    {
        const float flt_min = 1.175494351e-38;
        float dp3 = max(flt_min, dot(inVec, inVec));
        return inVec * rsqrt(dp3);
    }

    uint3 GetCluster(float3 positionWS)
    {
        uint3 cluster = uint3(((positionWS - CBIRP_PLAYER_POS) + CBIRP_CULL_FAR) / float(CBIRP_VOXELS_SIZE));
        return cluster;
    }

    // uint2 CullIndex(float3 positionWS)
    // {
    //     uint3 grid = uint3(((positionWS - CBIRP_PLAYER_POS) + CBIRP_CULL_FAR) / float(CBIRP_VOXELS_SIZE));
    //     #ifdef CBIRP_ASSUME_NO_Y
    //         uint2 index_2d = uint2(grid.x, grid.z);
    //     #else
    //         uint2 index_2d = uint2(grid.x + grid.z * CBIRP_VOXELS_COUNT, grid.y);
    //     #endif

    //     return index_2d;
    // }

    void ComputeLights(uint3 cluster, float3 positionWS, float3 normalWS, float3 viewDirectionWS, half3 f0, half NoV, half roughness, half4 shadowmask, inout half3 diffuse, inout half3 specular)
    {
        half clampedRoughness = max(roughness * roughness, 0.002);
        half debug = 0;

        CBIRP_CLUSTER_START(cluster, CBIRP_TYPE_LIGHT)

debug+=1;
            Light light = Light::DecodeLight(index);

            float3 positionToLight = light.positionWS - positionWS;
            float distanceSquare = dot(positionToLight, positionToLight);

            UNITY_BRANCH
            if (distanceSquare < light.range)
            {
                light.range = 1.0 / light.range;
                float3 L = normalize(positionToLight);
                half NoL = saturate(dot(normalWS, L));
                // float attenuation = GetSquareFalloffAttenuation(distanceSquare, light.range);
                float attenuation = GetSquareFalloffAttenuationCustom(distanceSquare, light.range);

                // UNITY_BRANCH
                if (light.spot)
                {
                    attenuation *= GetSpotAngleAttenuation(light.direction, L, light.spotScale, light.spotOffset);
                }

                #ifdef LIGHTMAP_ON
                if (light.hasShadowmask)
                {
                    attenuation *= shadowmask[light.shadowmaskID];
                }
                #endif

                debug += attenuation > 0;

                UNITY_BRANCH
                if (attenuation > 0 && NoL > 0)
                {
                    half3 currentDiffuse = attenuation * light.color * NoL;

                    float3 halfVector = CBIRP::SafeNormalize(L + viewDirectionWS);
                    half LoH = saturate(dot(L, halfVector));

                    #if !defined(CBIRP_LOW) && !defined(LIGHTMAP_ON)
                        half burley = CBIRPFilament::Fd_Burley(roughness, NoV, NoL, LoH);
                        currentDiffuse *= burley;
                    #endif

                    diffuse += currentDiffuse * !light.specularOnly;

                    #ifndef _SPECULARHIGHLIGHTS_OFF
                        half vNoH = saturate(dot(normalWS, halfVector));
                        half vLoH = saturate(dot(L, halfVector));
                        half3 Fv = CBIRPFilament::F_Schlick(vLoH, f0);
                        half Dv = CBIRPFilament::D_GGX(vNoH, clampedRoughness);
                        half Vv = CBIRPFilament::V_SmithGGXCorrelatedFast(NoV, NoL, clampedRoughness);
                        half3 currentSpecular = max(0.0, (Dv * Vv) * Fv) * currentDiffuse;
                        specular += currentSpecular;
                    #endif
                }

            }
        CBIRP_CLUSTER_END

        #ifdef _CBIRP_DEBUG
            // diffuse = Heatmap((debug) / 16.);
            diffuse = debug / 32.;
        #endif

        specular *= UNITY_PI;
    }

    half3 BoxProjectedCubemapDirection(half3 reflectionWS, float3 positionWS, float3 cubemapPositionWS, float3 boxMin, float3 boxMax, bool boxProjection)
    {
        UNITY_FLATTEN // most likely box always
        if (boxProjection)
        {
            float3 boxMinMax = (reflectionWS > 0.0f) ? boxMax.xyz : boxMin.xyz;
            half3 rbMinMax = half3(boxMinMax - positionWS) / reflectionWS;

            half fa = half(min(min(rbMinMax.x, rbMinMax.y), rbMinMax.z));

            half3 worldPos = half3(positionWS - cubemapPositionWS.xyz);

            half3 result = worldPos + reflectionWS * fa;
            return result;
        }
        else
        {
            return reflectionWS;
        }
    }

    half PerceptualRoughnessToMipmapLevel(half perceptualRoughness, uint maxMipLevel)
    {
        perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

        return perceptualRoughness * maxMipLevel;
    }

    half PerceptualRoughnessToMipmapLevel(half perceptualRoughness)
    {
        return PerceptualRoughnessToMipmapLevel(perceptualRoughness, UNITY_SPECCUBE_LOD_STEPS);
    }

    float CalculateProbeWeight(float3 positionWS, float3 probeBoxMin, float3 probeBoxMax, float blendDistance)
    {
        float3 weightDir = min(positionWS - probeBoxMin.xyz, probeBoxMax.xyz - positionWS) / blendDistance;
        return saturate(min(weightDir.x, min(weightDir.y, weightDir.z)));
    }

    // half CalculateProbeVolumeSqrMagnitude(float4 probeBoxMin, float4 probeBoxMax)
    // {
    //     half3 maxToMin = half3(probeBoxMax.xyz - probeBoxMin.xyz);
    //     return dot(maxToMin, maxToMin);
    // }

    #define FLT_EPSILON     1.192092896e-07 // Smallest positive number, such that 1.0 + FLT_EPSILON != 1.0

    float PositivePow(float base, float power)
    {
        return pow(max(abs(base), float(FLT_EPSILON)), power);
    }
 
    half3 DecodeHDREnvironment(half4 encodedIrradiance, half4 decodeInstructions)
    {
        decodeInstructions.zw = 0;
        decodeInstructions.y = 1;
        // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
        half alpha = max(decodeInstructions.w * (encodedIrradiance.a - 1.0) + 1.0, 0.0);

        // If Linear mode is not supported we can skip exponent part
        return (decodeInstructions.x * PositivePow(alpha, decodeInstructions.y)) * encodedIrradiance.rgb;
    }


    half3 SampleProbes(uint3 cluster, half3 reflectVector, float3 positionWS, half perceptualRoughness)
    {
        half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        float debug = 0;
        half3 irradiance = 0;
        float totalWeight = 0;

        half4 decodeInstructions = 0;

        CBIRP_CLUSTER_START(cluster, CBIRP_TYPE_PROBE)
            ReflectionProbe probe = ReflectionProbe::DecodeReflectionProbe(index);
            debug += 1;

            float weight = CalculateProbeWeight(positionWS, probe.boxMin, probe.boxMax, probe.blendDistance);

            UNITY_BRANCH
            if (weight > 0.0)
            {
                weight = min(weight, 1.0 - totalWeight);
                totalWeight += weight;

                half3 reflectVectorBox = BoxProjectedCubemapDirection(reflectVector, positionWS, probe.positionWS, probe.boxMin, probe.boxMax, probe.boxProjection);
                half4 encodedIrradiance = half4(_Udon_CBIRP_ReflectionProbes.SampleLevel(sampler_Udon_CBIRP_ReflectionProbes, half4(reflectVectorBox, probe.arrayIndex), mip));
                irradiance += weight * DecodeHDREnvironment(encodedIrradiance, half4(probe.intensity, decodeInstructions.yzw));
            }

        CBIRP_CLUSTER_END

        #ifdef CBIRP_SKYPROBE
        UNITY_BRANCH
        if (totalWeight < 0.99f)
        {
            half4 encodedIrradiance = half4(_Udon_CBIRP_SkyProbe.SampleLevel(sampler_Udon_CBIRP_ReflectionProbes, half3(reflectVector), mip));
            irradiance += (1.0f - totalWeight) * encodedIrradiance;
        }
        #endif

        #ifdef _CBIRP_DEBUG
        return debug / 16.;
        #endif
        return irradiance;
    }
}

#endif