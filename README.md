# Clustered BIRP
Clustered lighting for the Unity Built-In Pipeline in VRChat.

## Features

### Lights
- Spot and Point lights
- Inner and outer spot angle
- Inverse square falloff
- Shadow mask
- Specular Only shadow mask (Bakery light custom lighting option - direct, indirect, shadow mask)
- All lights in one pass

### Reflection Probes
- Bounds not tied to the renderer bounds, similar to URP
- Blend distance
- Reflection probes don't break batching

# How to use
- Swap shaders to a supported shader (a standard shader example included CBRIP/Standard - Mono SH enabled by default)
- You also can use [ShaderGraphZ](https://github.com/z3y/ShaderGraphZ) to create custom shaders with a node editor that support clustered birp
- To add a Light: `Game Object > Light > CBIRP > Point Light`
- To add a Reflection Probe: `Game Object > Light > CBIRP > Reflection Probe`, press bake and pack reflection probes


## Limitations
- Max number of enabled lights per world: 128
- Max number of enabled reflection probes per world : 32
- There is no limitation when it comes to number of lights in a single cluster, however having many lights with intersecting ranges is less performant
- Clustering is done in world space up to the ±far distance (far set on the main script) from the player position. Clustering is usually done in frustum space, but we don't have control over every camera in VRChat so this way it works on the stream camera as well. Keeping this range low as possible will give better clustering density
- All reflection probes have to be the same resolution in order to get packed into a tex2Darray
- Only 1 global shadow mask texture. Cant have multiple lightmaps unless implemented differently in a shader. Unity just doesn't pass the shadow mask texture in forward base unless its used. This could be forced with a shadow mask directional light, but then it wastes 1 channel of the shadow mask. If you need more lightmap density try out my [lightmap packer](https://github.com/z3y/XatlasLightmap).
- Currently, baking probes with multiple bounces is way slower than it needs to be
- This is still very new and experimental, in order to further improve it and expand with features, expect breaking changes

# Preview

Inner/Outer angles:

https://github.com/z3y/ClusteredBIRP/assets/33181641/dd173fa9-3cb5-4cb0-95b5-0e70bc537600


Shadowmask:

https://github.com/z3y/ClusteredBIRP/assets/33181641/2d36d35d-388d-47d3-9539-d0375d7b4bdb


Demo World:

https://vrchat.com/home/world/wrld_cb7fd9cd-55d5-4e48-8157-46322cfaf61c

## [Discord](https://discord.gg/bw46tKgRFT)


# How it works

Typically, clustered lighting would be done in frustum space, per camera, up to the camera far distance. With VRChat limitations this is not possible. You can still access the main camera's projection matrices and inverse camera projection, with some adjustments to make them actually correct, in a CRT, but there is currently no way to do so per camera, so the VRChat camera, and other user created cameras would not be able to see lights. Furthermore, it is not possible to access stereo camera matrices, CRTs only receive data for a single camera.

Instead, clustering can be done in world space. This reduces the benefits of clustered lighting, but it is still much faster compared to how the built-in pipeline handles lights with the forward add pass, and still faster even than a per object light loop. The performance is comparable with proper clustered lighting used in URP's forward+ rendering, but it even works in VR on Quest. Clusters are created around the player in world space, up to the ±far distance. This allows all cameras to reuse the same clusters, and it's not dependent on any of the camera variables. It also works in VR for both eyes, without any special handling.

Clustering is computed entirely on the GPU, with custom render textures, and lights managed without any Udon/C# code. Udon is only used to assign a material property block for light variables at start, set the global textures, and destroyed after. You can still even move the light transform and animate all light properties without any Udon. Light transforms are tracked with a separate camera, only rendering one special layer to a small render texture for light uniforms. Each light is a GPU instanced quad, rendering just into 2 pixels. Two 32bit float4s are enough to store the light world space position, rotation, color, spot inner/outer angles, IES profile/Cookie index, shadow mask ID, and more, with even some free bits left unused. The instanceID is abused to tell where to render the light data on the render texture, avoiding a sparse texture. This allows tracking objects position, rotation and even managing enabled lights state without any code, which is highly beneficial considering Udon's performance. In order to fix lights from constantly changing their instance ID, depending on their distance from the camera, a unique sortingOrder is set per light's mesh renderer.

The memory cost of the clustering CRT is X+Y+Z. The height of the CRT texture is 1024, while the width (1px needed for each axis) is rounded to power of 2 (4px), each pixel representing one voxel. The 4th column is used for reflection probes. Each voxel checks if the light range is within its min/max range, per axis, and if true, assigns it to that voxel. A single 32bit uint4 (a single pixel in the CRT) can contain 128 indices. This is achieved by using the index of the bit as the light index, 1 representing the light is inside that voxel. Enabling bits at a specific index is simple `flags |= 0x1 << index`, with some special handling to use all 4 channels of the texture. To get a list of light indices from this, you can get the index of the least significant bit (first bit set to 1 on the right), toggle it to 0, and repeat. This can be pretty slow if you have to loop through all bits and check if they are 1, in this case this would have constant 128 iterations which would be extremely slow. There are ways to do this faster, one of them being the [de Bruijn sequence](https://www.youtube.com/watch?t=2590&v=ZusiKXcz_ac&feature=youtu.be), or with [bit hacks](https://graphics.stanford.edu/~seander/bithacks.html#ZerosOnRightFloatCast). However, GPUs and CPUs have a special instruction for that. On DirectX [firstbitlow](https://learn.microsoft.com/en-us/windows/win32/direct3dhlsl/firstbit--sm5---asm-), which translates to [findLSB](https://registry.khronos.org/OpenGL-Refpages/gl4/html/findLSB.xhtml) on Open GL ES 3. You would index into the clustering texture 3 times, depending on the world space position of the pixel, calculate bitwise and `X & Y & Z`, and the resulting value would contain the indices of lights that affect that certain pixel. In a loop check if this value is 0, if not find the `firstbitlow`, toggle that bit, so it becomes 0 `flags ^= 0x1 << index` and shade the light which is at that index.
