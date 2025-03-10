Shader "_Prototype/OpaqueRaymarcher"
{
    Properties
    {
        [Header(SURFACE)]
        _AlbedoColor("Albedo", Color) = (1.0, 1.0, 1.0, 1.0)
        _MetallicFactor("Metallic", Range(0.0, 1.0)) = 0.8
        _SmoothnessFactor("Smoothness", Range(0.0, 1.0)) = 0.8
        _EmissionColor("Emission", Color) = (0.0, 0.0, 0.0, 0.0)
        _SpecularPower("Specular Power", Range(1.0, 100.0)) = 1.0
        _SpecularColorTint("Specular Color Tint", Color) = (1.0, 1.0, 1.0, 1.0)
        [Header(AMBIENT OCCLUSION)]
        [KeywordEnum(Yes, No, Preview)] _AO_USE("AO usage", int) = 0
        [KeywordEnum(_1,_2,_3,_4,_5,_6)] _AO_CASTS("AO casts", int) = 0
        _AOIntensity("AO intensity", Range(1.0, 10.0)) = 1.0
    }
    // this include is used to store major structures and defines
    CGINCLUDE
    	#pragma shader_feature _AO_USE_YES _AO_USE_NO _AO_USE_PREVIEW
        #pragma shader_feature _AO_CASTS__1 _AO_CASTS__2 _AO_CASTS__3 _AO_CASTS__4 _AO_CASTS__5 _AO_CASTS__6
        #if defined(_AO_CASTS__1)
        	#define AO_RAY_CASTS 1
        #elif defined(_AO_CASTS__2)
            #define AO_RAY_CASTS 2
        #elif defined(_AO_CASTS__3)
            #define AO_RAY_CASTS 3
        #elif defined( _AO_CASTS__4)
            #define AO_RAY_CASTS 4
        #elif defined(_AO_CASTS__5)
            #define AO_RAY_CASTS 5
        #elif defined(_AO_CASTS__6)
            #define AO_RAY_CASTS 6
        #endif
        #include "UnityCG.cginc"
        struct v2fColor
        {
            float3 rayWDir : TEXCOORD0;
            float3 rayWPos : TEXCOORD1;
            float4 vertex : SV_POSITION;
            float4 screenPos : TEXCOORD3;
            float3 ray : TEXCOORD4;
            float fogDepth : TEXCOORD5;
        };
        struct v2fShadow
        {
            float4 vertex : SV_POSITION;
            float3 rayWDir : TEXCOORD0;
            float3 rayWPos : TEXCOORD1;
        };
    ENDCG

    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "Queue" = "Geometry"
            "DisableBatching" = "True"
            "IgnoreProjector" = "True"
        }
        
        Cull Off
        LOD 100
        
        Pass
        {
            // main coloring
            Lighting On // ADDED
            Name "FORWARD BASE"
            Tags { "LightMode" = "ForwardBase" }
            ZWrite On

            CGPROGRAM
            //skip support for any kind of baked lighting
            //#pragma skip_variants LIGHTMAP_ON DYNAMICLIGHTMAP_ON DIRLIGHTMAP_COMBINED SHADOWS_SHADOWMASK

            #pragma target 3.0

            #pragma multi_compile_fwdbase
            #pragma multi_compile _ SHADOWS_SCREEN
            #pragma multi_compile _ VERTEXLIGHT_ON
            #pragma multi_compile_fog

            #pragma vertex vertColor
            #pragma fragment fragColor

            #include "OpaqueRaymarcher_VERT_FRAG.cginc"

            ENDCG
        }

        Pass
        {
            //lighting pass (received lights and shadows)
            Tags { "LightMode" = "ForwardAdd" }
            Blend One OneMinusSrcAlpha
            ZWrite On
            BlendOp Add

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_fwdadd_fullshadows
            #pragma multi_compile_fog
            #pragma multi_compile _ VERTEXLIGHT_ON
            
            #pragma vertex vertColor
            #pragma fragment fragColor

            #include "OpaqueRaymarcher_VERT_FRAG.cginc"

            ENDCG
        }

        Pass
        {
            //ofcourse a shadowcasting pass
            Tags { "LightMode" = "ShadowCaster" }
            ZWrite On

            CGPROGRAM

            #pragma target 3.0

            #pragma multi_compile_shadowcaster

            #pragma vertex vertShadow
            #pragma fragment fragShadow

            #include "OpaqueRaymarcher_VERT_FRAG.cginc"

            ENDCG
        }
    }
}
