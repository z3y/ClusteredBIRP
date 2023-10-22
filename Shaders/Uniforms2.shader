Shader "CBIRP/Internal/Uniforms2"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        _Far ("Far", Float) = 100
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
            Name "Uniforms2"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 4.5

            #include "UnityCG.cginc"
            #include "UnityCustomRenderTexture.cginc"

            uniform float _Far;

            float4 frag (v2f_customrendertexture i) : SV_Target
            {
                return float4(_WorldSpaceCameraPos.xyz, _Far);
            }
            ENDCG
        }
    }
}
