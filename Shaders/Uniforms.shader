Shader "CBIRP/Internal/Uniforms"
{
    Properties
    {
        [Toggle(_REFLECTION_PROBE)] _ReflectionProbe("Reflection Probe", Float) = 0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma target 4.5
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _REFLECTION_PROBE
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nolodfade nolightprobe nolightmap forcemaxcount:128 maxcount:128 // max count in vrchat seems to be 128, needs offset for ID

            #include "UnityCG.cginc"
            #include "Constants.hlsl"
    
            float PackFloats(float a, float b)
            {
                //Packing
                uint a16 = f32tof16(a);
                uint b16 = f32tof16(b);
                uint abPacked = (a16 << 16) | b16;
                return asfloat(abPacked);
            }
            float4 PackFloats(float4 a, float4 b)
            {
                //Packing
                uint4 a16 = f32tof16(a);
                uint4 b16 = f32tof16(b);
                uint4 abPacked = (a16 << 16) | b16;
                return asfloat(abPacked);
            }

            bool IsOrtho()
            {
                return unity_OrthoParams.w == 1 || UNITY_MATRIX_P[3][3] == 1;
            }

            UNITY_INSTANCING_BUFFER_START(Props)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Data0)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Data1)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Data2)
                UNITY_DEFINE_INSTANCED_PROP(float4, _Data3)
            UNITY_INSTANCING_BUFFER_END(Props)

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 transformPosition : TEXCOORD1;
                float3 direction : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            v2f vert (appdata v)
            {
                v2f o = (v2f)0;
                
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.transformPosition.xyz = mul(unity_ObjectToWorld, float4(0,0,0,1)).xyz;
                o.uv = v.uv;
                float4 uv = float4(0,0,0,1);
                float2 inUV = v.uv.xy;

                #ifdef INSTANCING_ON
                uint index = o.instanceID + 1;  // 0 reserved for no lights, offset here to skip that in the surface shader
                #else
                uint index = 0;
                #endif
                
                inUV.x += index;
                inUV.x *= (1.0 / CBIRP_UNIFORMS_SIZE.x);

                inUV.y *= 0.5;
                #ifdef _REFLECTION_PROBE
                    inUV.y += 0.5;
                #endif

                // inUV.xy *= CBIRP_UNIFORMS_SIZE;
                // inUV.x = index;


                uv.xy = inUV * 2 - 1;
                uv.y *= _ProjectionParams.x;

                o.vertex = uv;

                o.vertex *= IsOrtho(); // only needed for scene view 

                o.direction = -mul((float3x3)UNITY_MATRIX_M, v.normalOS);

                return o;
            }

            float random (float2 uv)
            {
                return frac(sin(dot(uv,float2(12.9898,78.233)))*43758.5453123);
            }

            #define glsl_mod(x,y) (((x)-(y)*floor((x)/(y))))
            // #include "Packages/com.llealloo.audiolink/Runtime/Shaders/AudioLink.cginc"
            float rand(float seed)
            {
                // Very simple pseudo-random number generator
                // Returns a value between 0 and 1
                // Preferentially returns the midrange
                return glsl_mod(frac(sin(seed * 6789.54321)) + 0.5, 1.0);
            }

            float4 frag (v2f i) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(i);

                #ifdef INSTANCING_ON
                uint index = i.instanceID + 1;  // 0 reserved for no lights
                #else
                uint index = 0;
                #endif

                float4 prop0 = UNITY_ACCESS_INSTANCED_PROP(Props, _Data0);
                float4 prop1 = UNITY_ACCESS_INSTANCED_PROP(Props, _Data1);
                float4 prop2 = UNITY_ACCESS_INSTANCED_PROP(Props, _Data2);
                float4 prop3 = UNITY_ACCESS_INSTANCED_PROP(Props, _Data3);

                float2 uv = i.uv.xy;
                uint writeIndex = uv.y * CBIRP_UNIFORMS_SIZE.y * 0.5;

                #ifdef _REFLECTION_PROBE
                if (writeIndex == 0)
                {
                    return float4(i.transformPosition.xyz, prop0.w);
                }
                if (writeIndex == 1)
                {
                    return prop1;
                }
                if (writeIndex == 2)
                {
                    return prop2;
                }
                if (writeIndex == 3)
                {
                    return prop3;
                }
                #else // LIGHTS
                    half range = prop1.x;
                    half innerAnglePercent = prop1.g;
                    half outerAngle = prop1.b;
                    bool isSpot = prop1.a > 0;

                    float3 color = prop0.rgb;
                    float intensity = prop0.a;

                    half flickerSpeed = prop2.y;
                    half flickerIntensity = prop2.z;
                    bool flickering = flickerIntensity > 0;

                    if (flickering)
                    {
                        intensity = lerp(intensity, rand(_Time.y * flickerSpeed * 0.005) * intensity, flickerIntensity);
                    }

                    float3 lightPosition = i.transformPosition.xyz;

                    
                    half shadowMaskID = prop2.x;
                    
                    float spotScale = 0;
                    float spotOffset = 0;
                    UNITY_BRANCH
                    if (isSpot)
                    {
                        half innerAngle = outerAngle / 100 * innerAnglePercent;
                        innerAngle = innerAngle / 360 * UNITY_PI;
                        outerAngle = outerAngle / 360 * UNITY_PI;
                        float cosOuter = cos(outerAngle);
                        spotScale = 1.0 / max(cos(innerAngle) - cosOuter, 1e-4);
                        spotOffset = -cosOuter * spotScale;
                    }

                    if (writeIndex == 0)
                    {
                        #if 0
                            lightPosition.x += sin((_Time.x  + (index * .01))  * 50);
                            lightPosition.z += sin((_Time.x  + (index * .02))  * 50);
                        #endif

                        float rangeScaled = range * range;
                        if (isSpot) rangeScaled = -rangeScaled;
                        return float4(lightPosition, rangeScaled);
                    }
                    else if (writeIndex == 1)
                    {
                        float4 unpackedData1a;
                        float4 unpackedData1b;
                        unpackedData1b.xyz = normalize(i.direction);
                        unpackedData1a.w = spotScale;
                        unpackedData1b.w = spotOffset;
                        unpackedData1a.xyz = color * intensity;
                        return PackFloats(unpackedData1a, unpackedData1b);
                        // return float4(color.rgb * intensity, shadowMaskID);

                    }
                    else if (writeIndex == 2)
                    {
                        // float4 packedData4a = normalize(i.direction);
                        // float4 packedData4b;
                        // UnpackFloat(data2, packedData4a, packedData4b);
                        return 0;
                        // return float4(, PackFloats(spotScale, spotOffset));
                    }

                #endif

                return 0;
            }
            ENDCG
        }
    }
}
