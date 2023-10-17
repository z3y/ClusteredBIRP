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
- Max number of reflection probes per scene 64
- Max number of lights or probes in one cluster 16 (cant have more than 16 overlapping lights)
- Clustering is done in world space around the player up to the far distance set on the main script. Keeping this range low as possible will give better clustering density
- Clustering done only in XZ axis, worlds with a lot of verticallity cant have many lights stacked vertically. It is possible to use all 3 axis, but this approximation seemes better for most VRChat worlds and lights are still culled outside the far range on Y axis
- All reflection probes have to be the same resolution in order to get packed into a tex2Darray

# How to use
- Swap shaders to a supported shader (a standard shader example included CBRIP/Standard)
- Drag in the manager prefab in the scene
- Drag in lights and reflection probe prefabs