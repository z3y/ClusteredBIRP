namespace CBIRPFilament
{
    float pow5(float x)
    {
        float x2 = x * x;
        return x2 * x2 * x;
    }

    float sq(float x)
    {
        return x * x;
    }

    half3 F_Schlick(half u, half3 f0)
    {
        return f0 + (1.0 - f0) * pow(1.0 - u, 5.0);
    }

    float F_Schlick(float f0, float f90, float VoH)
    {
        return f0 + (f90 - f0) * pow5(1.0 - VoH);
    }

    half Fd_Burley(half roughness, half NoV, half NoL, half LoH)
    {
        // Burley 2012, "Physically-Based Shading at Disney"
        half f90 = 0.5 + 2.0 * roughness * LoH * LoH;
        float lightScatter = F_Schlick(1.0, f90, NoL);
        float viewScatter  = F_Schlick(1.0, f90, NoV);
        return lightScatter * viewScatter;
    }

    half ComputeSpecularAO(half NoV, half ao, half roughness)
    {
        #ifdef CBIRP_LOW
        return ao;
        #else
        return clamp(pow(NoV + ao, exp2(-16.0 * roughness - 1.0)) - 1.0 + ao, 0.0, 1.0);
        #endif
    }

    half D_GGX(half NoH, half roughness)
    {
        half a = NoH * roughness;
        half k = roughness / (1.0 - NoH * NoH + a * a);
        return k * k * (1.0 / UNITY_PI);
    }

    float D_GGX_Anisotropic(float NoH, float3 h, float3 t, float3 b, float at, float ab)
    {
        half ToH = dot(t, h);
        half BoH = dot(b, h);
        half a2 = at * ab;
        float3 v = float3(ab * ToH, at * BoH, a2 * NoH);
        float v2 = dot(v, v);
        half w2 = a2 / v2;
        return a2 * w2 * w2 * (1.0 / UNITY_PI);
    }

    float V_SmithGGXCorrelatedFast(half NoV, half NoL, half roughness)
    {
        half a = roughness;
        float GGXV = NoL * (NoV * (1.0 - a) + a);
        float GGXL = NoV * (NoL * (1.0 - a) + a);
        return 0.5 / (GGXV + GGXL);
    }

    float V_SmithGGXCorrelated(half NoV, half NoL, half roughness)
    {
        #ifdef QUALITY_LOW
            return V_SmithGGXCorrelatedFast(NoV, NoL, roughness);
        #else
            half a2 = roughness * roughness;
            float GGXV = NoL * sqrt(NoV * NoV * (1.0 - a2) + a2);
            float GGXL = NoV * sqrt(NoL * NoL * (1.0 - a2) + a2);
            return 0.5 / (GGXV + GGXL);
        #endif
    }

    float V_SmithGGXCorrelated_Anisotropic(float at, float ab, float ToV, float BoV, float ToL, float BoL, float NoV, float NoL)
    {
        float lambdaV = NoL * length(float3(at * ToV, ab * BoV, NoV));
        float lambdaL = NoV * length(float3(at * ToL, ab * BoL, NoL));
        float v = 0.5 / (lambdaV + lambdaL);
        return saturate(v);
    }

    half V_Kelemen(half LoH)
    {
        // Kelemen 2001, "A Microfacet Based Coupled Specular-Matte BRDF Model with Importance Sampling"
        return saturate(0.25 / (LoH * LoH));
    }
    
    half GeometricSpecularAA(float3 geometricNormalWS, half perceptualRoughness, half varianceIn, half thresholdIn)
    {
        // Kaplanyan 2016, "Stable specular highlights"
        // Tokuyoshi 2017, "Error Reduction and Simplification for Shading Anti-Aliasing"
        // Tokuyoshi and Kaplanyan 2019, "Improved Geometric Specular Antialiasing"

        // This implementation is meant for deferred rendering in the original paper but
        // we use it in forward rendering as well (as discussed in Tokuyoshi and Kaplanyan
        // 2019). The main reason is that the forward version requires an expensive transform
        // of the half vector by the tangent frame for every light. This is therefore an
        // approximation but it works well enough for our needs and provides an improvement
        // over our original implementation based on Vlachos 2015, "Advanced VR Rendering".

        float3 du = ddx(geometricNormalWS);
        float3 dv = ddy(geometricNormalWS);

        half variance = varianceIn * (dot(du, du) + dot(dv, dv));

        half roughness = perceptualRoughness * perceptualRoughness;
        half kernelRoughness = min(2.0 * variance, thresholdIn);
        half squareRoughness = saturate(roughness * roughness + kernelRoughness);

        return sqrt(sqrt(squareRoughness));
    }
        
    half3 EnvironmentBRDFApproximation(half perceptualRoughness, half NoV, half3 f0)
    {
        // original code from https://blog.selfshadow.com/publications/s2013-shading-course/lazarov/s2013_pbs_black_ops_2_notes.pdf
        half g = 1 - perceptualRoughness;
        half4 t = half4(1 / 0.96, 0.475, (0.0275 - 0.25 * 0.04) / 0.96, 0.25);
        t *= half4(g, g, g, g);
        t += half4(0.0, 0.0, (0.015 - 0.75 * 0.04) / 0.96, 0.75);
        half a0 = t.x * min(t.y, exp2(-9.28 * NoV)) + t.z;
        half a1 = t.w;
        return saturate(lerp(a0, a1, f0));
    }

    void EnvironmentBRDF(Texture2D dfgTex, SamplerState dfgSampler, half NoV, half perceptualRoughness, half3 f0, out half3 brdf, out half3 energyCompensation)
    {
        #if defined(CBIRP_LOW)
            energyCompensation = 1.0;
            brdf = EnvironmentBRDFApproximation(perceptualRoughness, NoV, f0);
        #else
            float2 dfg = dfgTex.SampleLevel(dfgSampler, float2(NoV, perceptualRoughness), 0).rg;
            brdf = lerp(dfg.xxx, dfg.yyy, f0);
            energyCompensation = 1.0 + f0 * (1.0 / dfg.y - 1.0);
        #endif
    }
}