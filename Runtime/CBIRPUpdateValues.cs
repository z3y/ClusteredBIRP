#if UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using CBIRP;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class CBIRPUpdateValues : MonoBehaviour
{
    public CBIRPManager cBIRPManager;
    // unity 2022 just keeps loosing it in editor
    void Update()
    {
        if (Application.isPlaying)
        {
            return;
        }

        if (cBIRPManager)
        {
            cBIRPManager.SetGlobalUniforms();
        }
        Vector4 pos = SceneView.lastActiveSceneView.camera.transform.position;
        pos.w = cBIRPManager.cullFar;
        Shader.SetGlobalVector("_Udon_CBIRP_PlayerPosition", pos);
    }
}
#endif