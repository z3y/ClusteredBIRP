namespace CBIRP_Packing
{
    // :bgolus: https://forum.unity.com/threads/storing-two-16-bits-halfs-in-one-32-bits-float.987531/
    
    float PackFloats(float a, float b)
    {
        uint a16 = f32tof16(a);
        uint b16 = f32tof16(b);
        uint abPacked = (a16 << 16) | b16;
        return asfloat(abPacked);
    }
    void UnpackFloat(float input, out float a, out float b)
    {
        uint uintInput = asuint(input);
        a = f16tof32(uintInput >> 16);
        b = f16tof32(uintInput);
    }

    float PackFloatAndUint(float a, uint b)
    {
        uint a16 = f32tof16(a);
        uint abPacked = (a16 << 16) | b & 0xff;
        return asfloat(abPacked);
    }
    void UnpackFloatAndUint(float input, out float a, out uint b)
    {
        uint uintInput = asuint(input);
        a = f16tof32(uintInput >> 16);
        b = uintInput & 0xff;
    }

    float4 PackFloats(float4 a, float4 b)
    {
        uint4 a16 = f32tof16(a);
        uint4 b16 = f32tof16(b);
        uint4 abPacked = (a16 << 16) | b16;
        return asfloat(abPacked);
    }
    void UnpackFloat(float4 input, out float4 a, out float4 b)
    {
        uint4 uintInput = asuint(input);
        a = f16tof32(uintInput >> 16);
        b = f16tof32(uintInput);
    }


}