#if !defined(MY_SHADOWS_INCLUDED)
#define MY_SHADOWS_INCLUDED

#include "TransparentRaymarcher_LIGHTING.cginc"

sampler3D _DitherMaskLOD;
uniform float _CausticsMultiplier;

v2fColor vertColor(float4 vertex : POSITION)
{
    v2fColor o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.rayWPos = mul(unity_ObjectToWorld, vertex);
    o.rayWDir = GetViewRay(o.rayWPos);
    //needed for camera depth texture
    o.screenPos = ComputeScreenPos(o.vertex);
    o.uvgrab = ComputeGrabScreenPos(o.vertex);
    o.ray = UnityObjectToViewPos(float4(vertex.xyz, 1.0)) * float3(-1.0, -1.0, 1.0);
    #if FOG_DEPTH
        o.fogDepth = o.vertex.z;
    #else
        o.fogDepth = 0.0;
    #endif
    return o;
}

float4 fragColor(v2fColor i, out float fragDepth : SV_Depth) : SV_Target
{
    float3 rd = GetObjectSpaceRayDirection(i);
    float3 ro = GetObjectSpaceRayOrigin(i);
    float d = 0.0;
    if (Raymarch(ro, rd, d) == false)
        discard;
    float3 raymarchPointObjectSpace = ro + rd * d;
    float3 normalObjectSpace = GetNormal(raymarchPointObjectSpace);
    fragDepth = GetWorldDepthFromObject(raymarchPointObjectSpace);
    return LightingAndShadowing(raymarchPointObjectSpace, normalObjectSpace, i, ro, rd);
}

v2fShadow vertShadow(float4 vertex : POSITION)
{
    v2fShadow o;
    o.vertex = UnityObjectToClipPos(vertex);
    o.rayWPos = mul(unity_ObjectToWorld, vertex);
    o.rayWDir = GetViewRay(o.rayWPos);

    o.uvgrab = ComputeGrabScreenPos(o.vertex);

    return o;
}

float4 fragShadow(v2fShadow i, out float fragDepth : SV_Depth) : SV_Target
{
    float3 rd = GetObjectSpaceRayDirection(i);
    float3 ro = GetObjectSpaceRayOrigin(i);
    float d = 0.0;
    if (Raymarch(ro, rd, d) == false)
        discard;
    RefractionData rrData = GetRefractionReflection(ro,rd,_IOR,_ChromaticAberration,_OpticalDensity,i.uvgrab, false);
    float2 offset = rrData.rdAirBehindGreen.xy;
    float causticsFactor = length(offset) * _CausticsMultiplier;
    float texSlice = lerp(0.9375, saturate(causticsFactor) * 0.9375, _TransparencyFactor * rrData.opticalDistance);
    float shadowAlpha = tex3D(_DitherMaskLOD, float3(i.vertex.xy * 0.25, texSlice)).a;    
    clip(shadowAlpha - 0.001);
    float3 raymarchPointObjectSpace = ro + rd * d;
    float3 normalObjectSpace = GetNormal(raymarchPointObjectSpace);
    float4 pointClipSpace = UnityClipSpaceShadowCasterPos(raymarchPointObjectSpace, normalObjectSpace);
    pointClipSpace = UnityApplyLinearShadowBias(pointClipSpace);
    fragDepth = pointClipSpace.z / pointClipSpace.w; // set SV_DEPTH for shadow map
    return 0.0; // color is irrelevant, artifact of the syntax ?
}

#endif
