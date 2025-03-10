#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "OpaqueRaymarcher_RAYCAST.cginc"

// needed for unity_apply_fog_color macro to work properly
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif

uniform float4 _AlbedoColor;
uniform float _MetallicFactor;
uniform float _SmoothnessFactor;
uniform float4 _EmissionColor;
uniform float _AOIntensity;

uniform float _SpecularPower;
uniform float4 _SpecularColorTint;

half3 ShadeSH9Average(half3 normal)
{
    half3x3 mat = half3x3(
        unity_SHAr.w, length(unity_SHAr.rgb), length(unity_SHBr),
        unity_SHAg.w, length(unity_SHAg.rgb), length(unity_SHBg),
        unity_SHAb.w, length(unity_SHAb.rgb), length(unity_SHBb)
    );
    half3 res = mul(mat, normal);
    //res += length(unity_SHC) * 0.1;
    #ifdef UNITY_COLORSPACE_GAMMA
        res = LinearToGammaSpace(res);
    #endif
    return res;
}

float3 BoxProjection (float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
    /*
    cubemapPosition
    unity_SpecCube0_ProbePosition

    boxMin
    unity_SpecCube0_BoxMin
    
    boxMax
    unity_SpecCube0_BoxMax
    */
    
    #if UNITY_SPECCUBE_BOX_PROJECTION
        UNITY_BRANCH
        if (cubemapPosition.w > 0)
        {
            float3 factors = ((direction > 0 ? boxMax : boxMin) - position) / direction;
            float scalar = min(min(factors.x, factors.y), factors.z);
            direction = direction * scalar + (position - cubemapPosition);
        }
    #endif
    return direction;
}

float3 GetVertexLightColor (float3 worldPos, float3 worldNormal)
{
    #if defined(VERTEXLIGHT_ON)
        return Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb,
            unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, worldPos, worldNormal);
    #endif
    return float3(0.0, 0.0, 0.0);
}

//SOURCE https://iquilezles.org/articles/functions/
float expStep( float x, float n )
{
    return exp2( -exp2(n)*pow(x,n) );
}

float GetCheapAO(float3 p, float3 n)
{
    float ao;
    float v1 = 0.4, v2 = 0.6, v3 = 0.02, v4 = 0.025;
    ao = v1 + v2 * map(p + n * v3) / v4;
    for (int i = 1; i <= AO_RAY_CASTS; i++)
    {
        v1 += 0.1;
        v2 -= 0.1;
        v3 *= 2.0;
        v4 *= 2.0;
        ao *= v1 + v2 * map(p + n * v3) / v4;
    }
    ao = clamp(0.0, 1.0, pow(ao,_AOIntensity));
    return smoothstep(0.0,1.0,ao);
}

float GetShadowAttenuation (float3 worldPos)
{
    #if defined(SHADOWS_CUBE)
    {
        unityShadowCoord3 shadowCoord = worldPos - _LightPositionRange.xyz;
        float result = UnitySampleShadowmap(shadowCoord);
        return result;
    }
    #elif defined(SHADOWS_SCREEN)
    {
        #ifdef UNITY_NO_SCREENSPACE_SHADOWS
            unityShadowCoord4 shadowCoord = mul( unity_WorldToShadow[0], worldPos);	
        #else
            unityShadowCoord4 shadowCoord = ComputeScreenPos(mul(UNITY_MATRIX_VP, float4(worldPos, 1.0)));
        #endif
        float result = unitySampleShadow(shadowCoord);
        return result;
    }		
    #elif defined(SHADOWS_DEPTH) && defined(SPOT)
    {		
        unityShadowCoord4 shadowCoord = mul(unity_WorldToShadow[0], float4(worldPos, 1.0));
        float result = UnitySampleShadowmap(shadowCoord);
        return result;
    }
    #else
        return 1.0; // NO ATTENUATION IE NO SHADOWING
    #endif
}

// could retrieve directly, but as function call, there's an opportunity to add
// more processing prior to outputting the value. ditto for the rest.
float3 GetAlbedo()
{
    return _AlbedoColor.rgb;
}
float GetMetallic()
{
    return _MetallicFactor;
}

float GetSmoothness()
{
    return _SmoothnessFactor;
}

float3 GetEmission()
{
    return _EmissionColor.rgb;
}

UnityLight CreateLight(float4 pointClipSpace, float3 pointWorldSpace, float3 normalWorldSpace, out float ndotl)
{
    /* 
    //ORIGINAL
    UnityLight light;
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    float attenuation = GetShadowAttenuation(worldPos);
    light.color = _LightColor0.rgb * attenuation;
    return light;
    */
    #if defined (SHADOWS_SCREEN)
        struct shadowInput
        {
            SHADOW_COORDS(0)
        };    
    shadowInput shadowIN;
        shadowIN._ShadowCoord = ComputeScreenPos(pointClipSpace);
    #else
        float shadowIN = 0.0;
    #endif
    UnityLight light;
    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - pointWorldSpace);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif
    UNITY_LIGHT_ATTENUATION(attenuation, shadowIN, pointWorldSpace);
    float3 lightDirectionWorldSpace = normalize(UnityWorldSpaceLightDir(pointWorldSpace));
    ndotl = saturate(dot(normalWorldSpace, lightDirectionWorldSpace));
    float fresnel = pow(ndotl, _SpecularPower);
    light.color = _LightColor0.rgb * attenuation * fresnel * _SpecularColorTint.rgb;
    //light.color = _LightColor0.rgb * attenuation; // ORIGINAL
    ndotl = abs(ndotl);
    light.ndotl = ndotl;
    return light;
}

UnityIndirect CreateIndirectLight (float3 worldPos, float3 worldNormal, float3 viewDir)
{
    UnityIndirect indirectLight;
    #ifdef UNITY_PASS_FORWARDADD
    indirectLight.diffuse = indirectLight.specular = 0.0;
    #else
    indirectLight.diffuse = GetVertexLightColor(worldPos, worldNormal) + max(0.0, ShadeSH9(float4(worldNormal, 1.0)));
    float3 reflectionDir = reflect(-viewDir, worldNormal);
    Unity_GlossyEnvironmentData envData;
    envData.roughness = 1.0 - GetSmoothness();
    envData.reflUVW = BoxProjection(
        reflectionDir, worldPos,
        unity_SpecCube0_ProbePosition,
        unity_SpecCube0_BoxMin, unity_SpecCube0_BoxMax);
    indirectLight.specular = Unity_GlossyEnvironment(UNITY_PASS_TEXCUBE(unity_SpecCube0), unity_SpecCube0_HDR, envData);
    float occlusion = GetCheapAO(worldPos, worldNormal);
    indirectLight.diffuse *= occlusion;
    indirectLight.specular *= occlusion;
    #endif
    return indirectLight;
}

float4 LightingAndShadowing (float3 pointObjectSpace, float3 normalObjectSpace, v2fColor i, float3 ro, float3 rd)
{
    float ambientOcclusion;
	#ifdef _AO_USE_NO
    ambientOcclusion = 1.0;
	#else
	ambientOcclusion = GetCheapAO(pointObjectSpace, normalObjectSpace);
	#endif
    #ifdef _AO_USE_PREVIEW
	#define ao ambientOcclusion
    return float4(ao, ao, ao, 1.0);
    #endif
    float3 pointWorldSpace = mul(unity_ObjectToWorld, float4(pointObjectSpace, 1.0));
    float3 normalWorldSpace = UnityObjectToWorldNormal(normalObjectSpace);
    float3 directionWorldSpace = UnityObjectToWorldDir(normalObjectSpace);
    float3 lightDirectionWorldSpace = normalize(UnityWorldSpaceLightDir(pointWorldSpace));
    float4 pointClipSpace = UnityWorldToClipPos(pointWorldSpace);
    float3 viewDirectionWorld = normalize(_WorldSpaceCameraPos - pointWorldSpace);

    float3 specularTint;
    float oneMinusReflectivity;
    float3 albedo = DiffuseAndSpecularFromMetallic(
    GetAlbedo()*ambientOcclusion,
    GetMetallic() * ambientOcclusion,
    specularTint,
    oneMinusReflectivity);
    float fresnel;
    //for better or worse, we're using unity's idea of pbs. maybe a custom implementation would work better ?
    // if so, consider it a homework assignment ;) i know i'll try it someday.
    float4 color = UNITY_BRDF_PBS(
        albedo,
        specularTint,
        oneMinusReflectivity,
        GetSmoothness() * ambientOcclusion, //didn't notice, maybe its too subtle for me. but there it is. multiplication could be removed if not needed.
        normalWorldSpace, viewDirectionWorld,
        CreateLight(pointClipSpace, pointWorldSpace, normalWorldSpace, fresnel),
        CreateIndirectLight(pointWorldSpace, normalWorldSpace, viewDirectionWorld));
    // added AO affecting emission. feels right to me, might feel right to you too.
    color.rgb += GetEmission() * ambientOcclusion;
    color.a = 0.0;
    //go to window > rendering > lighting settings > [scroll to bottom] enable fog & change density to 0.1 for immediate effect
    UNITY_APPLY_FOG_COLOR(i.fogDepth, color, unity_FogColor);
    return color;
}
#endif