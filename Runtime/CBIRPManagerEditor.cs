#if !COMPILER_UDONSHARP && UNITY_EDITOR
using System.IO;
using System.Linq;
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
        public int callbackOrder => 0;

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

            foreach (var probe in probes)
            {
                probe.probe.bakedTexture = null;
                probe.enabled = false;
            }
        }

        public static void PackProbes(CBIRPManager target)
        {
            // thx error mdl
            // https://github.com/Error-mdl/UnityReflectionProbeArrays/blob/master/ReflectionProbeArray/editor/ReflectionProbeArrayCreator.cs

            var probeInstances = GameObject.FindObjectsOfType<CBIRPReflectionProbe>();

            if (probeInstances.Length == 0)
            {
                return;
            }

            var reflectionProbes = probeInstances.Select(x => x.GetComponent<ReflectionProbe>()).ToArray();

            var referenceProbe = reflectionProbes[0].texture as Cubemap;
            var array = new CubemapArray(referenceProbe.width, reflectionProbes.Length, referenceProbe.format, true);

            for (int i = 0; i < reflectionProbes.Length; i++)
            {
                Texture probe = reflectionProbes[i].texture;

                for (int mip = 0; mip < referenceProbe.mipmapCount; mip++)
                {
                    for (int side = 0; side < 6; side++)
                    {
                        Graphics.CopyTexture(probe, side, mip, array, (i * 6) + side, mip);
                    }
                }

                var cbirpProbe = reflectionProbes[i].transform.GetComponent<CBIRPReflectionProbe>();
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
            var path = Path.Combine(sceneDirectory, "CBIRP_ProbeArray_" + sceneName + ".asset");
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