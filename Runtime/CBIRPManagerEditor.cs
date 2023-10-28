#if !COMPILER_UDONSHARP && UNITY_EDITOR
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Threading.Tasks;
using UnityEditor;
using UnityEditor.Build;
using UnityEditor.Build.Reporting;
using UnityEngine;
using UnityEngine.SceneManagement;
using VRC;

namespace CBIRP
{
    public class CBIRPManagerEditor : IProcessSceneWithReport, IActiveBuildTargetChanged
    {
        private static object reflectionProbe;

        public int callbackOrder => 0;

        [InitializeOnLoadMethod]
        public async static void InitliazeGlobals()
        {
            await Task.Delay(1000);

            var manager = GameObject.FindObjectOfType<CBIRPManager>();
            if (!manager)
            {
                return;
            }

            manager.OnValidate();
        }


        public void OnActiveBuildTargetChanged(BuildTarget previousTarget, BuildTarget newTarget)
        {
            // clear out packed texture arrays to not destroy performance on android
            var probes = AssetDatabase.FindAssets("CBIRP_ProbeArray_");
            foreach (var probe in probes)
            {
                AssetDatabase.DeleteAsset(AssetDatabase.GUIDToAssetPath(probe));
            }
        }

        public void OnProcessScene(Scene scene, BuildReport report)
        {
            var objects = scene.GetRootGameObjects();
            var probes = objects.SelectMany(x => x.GetComponentsInChildren<CBIRPReflectionProbe>(false));
            var lights = objects.SelectMany(x => x.GetComponentsInChildren<CBIRPLight>(true));

            foreach (var probe in probes)
            {
                probe.probe.bakedTexture = null;
                probe.enabled = false;
            }

            int order = 10000;
            foreach (var light in lights)
            {
                light.meshRenderer.sortingOrder = order;
                order++;
            }
        }

        public static CBIRPReflectionProbe[] GetAllProbeComponents()
        {
            var probeInstances = GameObject.FindObjectsOfType<CBIRPReflectionProbe>();
            return probeInstances;
        }

        public static void BakeAndPackProbes(CBIRPManager target, int bounces, int resolution)
        {
            var scene = SceneManager.GetActiveScene();
            var probeDir = Path.Combine(Path.GetDirectoryName(scene.path), scene.name);
            var probes = GameObject.FindObjectsOfType<CBIRPReflectionProbe>();

            for (int i = 0; i < bounces; i++)
            {
                for (int j = 0; j < probes.Length; j++)
                {
                    probes[j].probe.resolution = resolution;
                    Lightmapping.BakeReflectionProbe(probes[j].probe, Path.Combine(probeDir, "ReflectionProbe-" + j + ".exr"));
                    probes[j].probe.MarkDirty();
                }
                PackProbes(target, probes);
            }
        }
        public static void ClearProbes(CBIRPManager manager)
        {
            manager.reflectionProbeArray = null;
            manager.MarkDirty();
            manager.OnValidate();
        }
        public static void PackProbes(CBIRPManager target, CBIRPReflectionProbe[] probeInstances)
        {
            // thx error mdl
            // https://github.com/Error-mdl/UnityReflectionProbeArrays/blob/master/ReflectionProbeArray/editor/ReflectionProbeArrayCreator.cs

            if (probeInstances.Length == 0)
            {
                return;
            }

            var referenceProbe = probeInstances[0].probe.texture as Cubemap;
            var array = new CubemapArray(referenceProbe.width, referenceProbe.height, referenceProbe.format, true);

            for (int i = 0; i < probeInstances.Length; i++)
            {
                var reflectionProbe = probeInstances[i].probe;
                Texture probe = reflectionProbe.texture;

                for (int mip = 0; mip < referenceProbe.mipmapCount; mip++)
                {
                    for (int side = 0; side < 6; side++)
                    {
                        Graphics.CopyTexture(probe, side, mip, array, (i * 6) + side, mip);
                    }
                }

                var cbirpProbe = reflectionProbe.transform.GetComponent<CBIRPReflectionProbe>();
                if (cbirpProbe)
                {
                    cbirpProbe.cubeArrayIndex = i;
                    cbirpProbe.MarkDirty();
                    cbirpProbe.OnValidate();
                }
            }

            var scenePath = SceneManager.GetActiveScene().path;
            var sceneName = Path.GetFileNameWithoutExtension(scenePath);
            var sceneDirectory = Path.GetDirectoryName(scenePath);
            var path = Path.Combine(sceneDirectory, "ReflectionProbesArray-" + sceneName + ".asset");
            AssetDatabase.CreateAsset(array, path);
            AssetDatabase.ImportAsset(path);
            var probes = AssetDatabase.LoadAssetAtPath<CubemapArray>(path);
            var instance = target;
            instance.reflectionProbeArray = probes;
            instance.MarkDirty();
            instance.OnValidate();
        }
    }
}
#endif