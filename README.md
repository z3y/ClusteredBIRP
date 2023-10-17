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

## Limitations
- Max number of lights per scene: 256 (hard coded at 128 to not waste uniforms, no one really needs this many anyway)
- Max number of reflection probes per scene: 64
- Max number of lights or probes in one cluster 16 (cant have more than 16 overlapping lights)
- Clustering is done in world space around the player up to the far distance set on the main script. Keeping this range low as possible will give better clustering density
- Clustering done only in XZ axis, worlds with a lot of verticallity cant have many lights stacked vertically. It is possible to use all 3 axis, but this approximation seemes better for most VRChat worlds and lights are still culled outside the far range on Y axis
- All reflection probes have to be the same resolution in order to get packed into a tex2Darray
- Having many dynamic transforms can affect performance because of Udon. Lights could also be tracked with a camera (used in the demo world), but setting global uniforms turned out to be faster than reading from a texture
- Only 1 global shadow mask texture. Cant have multiple lightmaps unless implemented differently in a shader. Unity just doesnt pass the shadow mask texture in forward base unless its used. This could be forced with a shadow mask directional light, but then it wastes 1 channel of the shadow mask. If you need more lightmap density try out my [lightmap packer](https://github.com/z3y/XatlasLightmap).

# How to use
- Swap shaders to a supported shader (a standard shader example included CBRIP/Standard - Mono SH enabled by default)
- Drag in the manager prefab in the scene
- Drag in lights and reflection probe prefabs

# Preview

Inner/Outer angles:

https://github.com/z3y/ClusteredBIRP/assets/33181641/aa49040a-c6c6-41b4-950c-584262275196


Shadowmask:

https://github.com/z3y/ClusteredBIRP/assets/33181641/a2084640-7297-4b2b-a3d4-9c109f50af26


Demo World:

https://vrchat.com/home/world/wrld_cb7fd9cd-55d5-4e48-8157-46322cfaf61c

[Discord Support](https://discord.gg/bw46tKgRFT)