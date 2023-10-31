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
- Max number of enabled lights per world: 128
- Max number of enabled reflection probes per world : 64
- There is no limitation when it comes to number of lights in a single cluster, however having many lights with intersecting ranges is less performant
- Spotlights currently take up as much rage in clusters as point lights
- Clustering is done in world space up to the ±far distance (far set on the main script) from the player position. Clustering is usually done in frustum space, but we don't have control over every camera in VRChat so this way it works on the stream camera as well. Keeping this range low as possible will give better clustering density
- All reflection probes have to be the same resolution in order to get packed into a tex2Darray
- Only 1 global shadow mask texture. Cant have multiple lightmaps unless implemented differently in a shader. Unity just doesn't pass the shadow mask texture in forward base unless its used. This could be forced with a shadow mask directional light, but then it wastes 1 channel of the shadow mask. If you need more lightmap density try out my [lightmap packer](https://github.com/z3y/XatlasLightmap).
- Currently, baking probes with multiple bounces is way slower than it needs to be
- This is still very new and experimental, in order to further improve it and expand with features, expect breaking changes

# How to use
- Swap shaders to a supported shader (a standard shader example included CBRIP/Standard - Mono SH enabled by default)
- Drag in the manager prefab in the scene
- Drag in lights and reflection probe prefabs
- Press bake and pack reflection probes

# Preview

Inner/Outer angles:

https://github.com/z3y/ClusteredBIRP/assets/33181641/dd173fa9-3cb5-4cb0-95b5-0e70bc537600


Shadowmask:

https://github.com/z3y/ClusteredBIRP/assets/33181641/2d36d35d-388d-47d3-9539-d0375d7b4bdb


Demo World:

https://vrchat.com/home/world/wrld_cb7fd9cd-55d5-4e48-8157-46322cfaf61c

[Discord Support](https://discord.gg/bw46tKgRFT)
