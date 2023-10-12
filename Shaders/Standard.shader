﻿Shader "CBIRP/Standard"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex ("Albedo", 2D) = "white" {}

        [NoScaleOffset] [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Normal Scale", Float) = 1.0

        [NoScaleOffset] _MetallicGlossMap("Mask Map", 2D) = "white" {}
        _Roughness ("Roughness", Range(0.0, 1.0)) = 0.5
        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        _OcclusionStrength ("Occlusion", Range(0.0, 1.0)) = 1.0

        [NonModifiableTextureData] [NoScaleOffset]_DFG ("DFG", 2D) = "white" {}

        _Metallic ("Metallic", Range(0.0, 1.0)) = 0.0
        [Toggle(_CBIRP_DEBUG)] _CBIRPDebugModeEnable ("Debug", Float) = 0
        [Enum(Lights,0,Probes,1)] _CBIRPDebugMode ("Debug Mode", Float) = 0
    }
    

HLSLINCLUDE

#pragma target 4.5
#pragma vertex vert
#pragma fragment frag
#pragma shader_feature_local _CUTOUT
#pragma shader_feature_local _EMISSION

#ifdef LIGHTMAP_ON
    #define DIRLIGHTMAP_COMBINED
#endif

#include "UnityCG.cginc"
#include "Lighting.cginc"
#include "AutoLight.cginc"

#ifdef UNITY_PASS_SHADOWCASTER
    // #include "UnityStandardShadow.cginc"
#endif

#ifdef UNITY_PASS_META
    #include "UnityMetaPass.cginc"
#endif

#include "CBIRP.hlsl"

struct Attributes
{
    float3 positionOS : POSITION;
    float2 uv0 : TEXCOORD0;
    float2 uv1 : TEXCOORD1;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float2 uv0 : TEXCOORD0;

    #ifdef UNITY_PASS_FORWARDBASE
        float3 positionWS : POSITIONWS;
        float3 normalWS : NORMAL;
        float4 tangentWS : TANGENT;
    #endif
    #ifdef LIGHTMAP_ON
        centroid float2 lightmapUV : LIGHTMAPUV;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

struct Material
{
    half3 albedo;
    half alpha;
    half3 normalTS;
    half metallic;
    half roughness;
    half3 emission;
    half occlusion;

    static Material Initialize()
    {
        Material m = (Material)0;
        m.albedo = 0.5;
        m.alpha = 1;
        m.roughness = 0.5;
        m.metallic = 0;
        m.normalTS = half3(0, 0, 1);
        m.emission = 0;
        m.occlusion = 1;
        return m;
    }
};

Texture2D _MainTex;
SamplerState sampler_MainTex;
Texture2D _BumpMap;
SamplerState sampler_BumpMap;
Texture2D _MetallicGlossMap;
SamplerState sampler_MetallicGlossMap;

CBUFFER_START(UnityPerMaterial)
    float4 _MainTex_ST;
    half4 _Color;
    half _Roughness;
    half _Metallic;
    half _OcclusionStrength;
    half _BumpScale;
CBUFFER_END

Varyings vert (Attributes attributes)
{
    Varyings varyings;
    //UNITY_INITIALIZE_OUTPUT(Varyings, varyings);
    UNITY_SETUP_INSTANCE_ID(attributes);
    UNITY_TRANSFER_INSTANCE_ID(attributes, varyings);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(varyings);
    
    #if defined(UNITY_PASS_FORWARDBASE)
        varyings.positionCS = UnityObjectToClipPos(float4(attributes.positionOS, 1.0));
    #elif defined(UNITY_PASS_SHADOWCASTER)
        varyings.positionCS = UnityClipSpaceShadowCasterPos(attributes.positionOS, attributes.normalOS);
        varyings.positionCS = UnityApplyLinearShadowBias(varyings.positionCS);
        // TRANSFER_SHADOW_CASTER_NOPOS(varyings, varyings.positionCS);
    #else // meta
        varyings.positionCS = UnityMetaVertexPosition(float4(attributes.positionOS, 1.0), attributes.uv1.xy, 0, unity_LightmapST, unity_DynamicLightmapST);
    #endif


    #if defined(LIGHTMAP_ON)
        varyings.lightmapUV.xy = attributes.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    #endif

    varyings.uv0 = attributes.uv0;
    #ifdef UNITY_PASS_FORWARDBASE
        varyings.tangentWS = float4(UnityObjectToWorldDir(attributes.tangentOS.xyz), attributes.tangentOS.w);
        varyings.normalWS = UnityObjectToWorldNormal(attributes.normalOS);
        varyings.positionWS = mul(unity_ObjectToWorld, float4(attributes.positionOS, 1));
    #endif

    return varyings;
}

Material InitializeMaterial(Varyings varyings)
{
    float2 mainUV = varyings.uv0 * _MainTex_ST.xy + _MainTex_ST.zw;

    Material m = Material::Initialize();

    half4 mainTexture = _MainTex.Sample(sampler_MainTex, mainUV) * _Color;
    m.alpha = mainTexture.a;
    m.albedo = mainTexture.rgb;

    half4 normalMap = _BumpMap.Sample(sampler_BumpMap, mainUV);
    half4 maskMap = _MetallicGlossMap.Sample(sampler_MetallicGlossMap, mainUV);
    m.normalTS = UnpackScaleNormal(normalMap, _BumpScale);
    m.roughness = maskMap.g * _Roughness;
    m.metallic = maskMap.b * _Metallic;
    m.occlusion = lerp(1, maskMap.r, _OcclusionStrength);

    return m;
}


ENDHLSL

    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            Name "Forward"
            Tags { "LightMode" = "ForwardBase" }

            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma multi_compile _ DIRECTIONAL
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            // #pragma multi_compile_fwdbase
            // #pragma skip_variants SHADOWS_SCREEN DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK VERTEXLIGHT_ON LIGHTPROBE_SH
            // #pragma skip_variants SHADOWS_SCREEN VERTEXLIGHT_ON LIGHTPROBE_SH DYNAMICLIGHTMAP_ON LIGHTMAP_SHADOW_MIXING SHADOWS_SHADOWMASK
            #pragma shader_feature_local _CBIRP_DEBUG
            uint _CBIRPDebugMode;

            SamplerState custom_bilinear_clamp_sampler;
                        
            #ifndef CBIRP_LOW
                Texture2D _DFG;
            #endif
            
            half4 frag (Varyings varyings) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(varyings);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

                Material m = InitializeMaterial(varyings);

                float3 normalWS = varyings.normalWS;
                float3 tangentWS = varyings.tangentWS.xyz;
                float crossSign = (varyings.tangentWS.w > 0.0 ? 1.0 : -1.0) * unity_WorldTransformParams.w;
                float3 bitangentWS = crossSign * cross(varyings.normalWS.xyz, varyings.tangentWS.xyz);
                float3x3 tangentToWorld = float3x3(tangentWS, bitangentWS, normalWS);
                normalWS = mul(m.normalTS, tangentToWorld);
                normalWS = Unity_SafeNormalize(normalWS);

                float3 positionWS = varyings.positionWS;

                float3 viewDirectionWS = normalize(UnityWorldSpaceViewDir(positionWS));
                half NoV = abs(dot(normalWS, viewDirectionWS)) + 1e-5f;
                half reflectance = 0.5;
                half roughness2 = m.roughness * m.roughness;
                half roughness2Clamped = max(roughness2, 0.002);
                float3 reflectVector = reflect(-viewDirectionWS, normalWS);
                #if !defined(CBIRP_LOW)
                    reflectVector = lerp(reflectVector, normalWS, roughness2);
                #endif


                half3 f0 = 0.16 * reflectance * reflectance * (1.0 - m.metallic) + m.albedo * m.metallic;
                half3 brdf;
                half3 energyCompensation;
                CBIRP::EnvironmentBRDF(_DFG, custom_bilinear_clamp_sampler, NoV, m.roughness, f0, brdf, energyCompensation);

                half3 diffuse = 0;
                half3 specular = 0;
                
                #ifdef LIGHTMAP_ON
                    float2 lightmapUV = varyings.lightmapUV;
                    half3 L0 = DecodeLightmap(unity_Lightmap.SampleLevel(custom_bilinear_clamp_sampler, lightmapUV, 0));

                    #ifdef DIRLIGHTMAP_COMBINED
                        half4 directionalLightmap = unity_LightmapInd.SampleLevel(custom_bilinear_clamp_sampler, lightmapUV, 0);
                        // bakery mono sh
                        half3 nL1 = directionalLightmap * 2 - 1;
                        half3 L1x = nL1.x * L0 * 2;
                        half3 L1y = nL1.y * L0 * 2;
                        half3 L1z = nL1.z * L0 * 2;
                        half3 sh = L0 + normalWS.x * L1x + normalWS.y * L1y + normalWS.z * L1z;
                        half3 lightmapOcclusion = (dot(nL1, reflectVector) + 1.0) * L0 * 2;
                        lightmapOcclusion = max(0.0, lightmapOcclusion);
                    #else
                        lightmapOcclusion = max(0.0, L0);
                    #endif

                    diffuse += max(0.0, sh);
                #else
                    diffuse += max(0.0, ShadeSH9(half4(normalWS, 1)));
                #endif
                                
                #ifdef LIGHTMAP_ON
                    half4 shadowmask = _Udon_CBIRP_ShadowMask.SampleLevel(custom_bilinear_clamp_sampler, lightmapUV, 0);
                    // half4 shadowmask = 1;
                #else
                    half4 shadowmask = 1;
                #endif

                uint2 cullIndex = CBIRP::CullIndex(positionWS);
                half3 light = 0;
                CBIRP::ComputeLights(cullIndex, positionWS, normalWS, viewDirectionWS, f0, NoV, m.roughness, shadowmask, light, specular);
                half3 probes = CBIRP::SampleProbes(cullIndex, reflectVector, positionWS, m.roughness);

                #ifdef _CBIRP_DEBUG
                    return float3(_CBIRPDebugMode ? probes : light).xyzz;
                #endif

                #ifdef LIGHTMAP_ON
                    half3 bentLight = lightmapOcclusion;
                #else
                    half3 bentLight = diffuse;
                #endif

                half bentLightGrayscale = sqrt(dot(bentLight + light, 1.0));
                probes *= bentLightGrayscale;

                specular += probes * brdf * energyCompensation;
                diffuse += light;

                half4 color = half4(m.albedo * (1.0 - m.metallic) * (diffuse * m.occlusion) + specular + m.emission, m.alpha);
                return color;
            }

            ENDHLSL
        }
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On ZTest LEqual

            HLSLPROGRAM
            #pragma skip_variants _EMISSION
            // #pragma multi_compile_shadowcaster
            #pragma multi_compile_instancing
            #pragma multi_compile SHADOWS_DEPTH
            
            void frag (Varyings varyings)
            {
                UNITY_SETUP_INSTANCE_ID(varyings);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(varyings);

                // Material m = InitializeMaterial(varyings);
                //half4 color = half4(m.albedo, m.alpha);


                // return 0;
            }
            ENDHLSL
        }
        Pass
        {
            Name "Meta"
            Tags { "LightMode"="Meta" }

            Cull Off

            HLSLPROGRAM
            #pragma shader_feature EDITOR_VISUALIZATION

            half4 frag (Varyings varyings) : SV_Target
            {
                Material m = InitializeMaterial(varyings);

                half4 color = half4(m.albedo, m.alpha);

                return color;
            }
            ENDHLSL
        }
    }
}
