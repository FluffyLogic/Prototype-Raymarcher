#if !defined(MY_LIGHTING_INCLUDED)
#define MY_LIGHTING_INCLUDED

#include "TransparentRaymarcher_RAYCAST.cginc"

// NEEDED FOR UNITY_APPLY_FOG_COLOR MACRO TO WORK PROPERLY
#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
    #if !defined(FOG_DISTANCE)
        #define FOG_DEPTH 1
    #endif
    #define FOG_ON 1
#endif

sampler2D _GrabTexture;
//float4 _GrabTexture_TexelSize; // ALWAYS ZERO, NOT WORKING !?
uniform float4 _AlbedoColor;
uniform float _MetallicFactor;
uniform float _SmoothnessFactor;
uniform float4 _EmissionColor;
uniform float _TransparencyFactor;
uniform float _AOIntensity;

uniform float _SpecularPower;
uniform float4 _SpecularColorTint;

uniform float _IOR;
uniform float _ChromaticAberration;
uniform float _OpticalDensity;
uniform float _FakeRefractionMultiplier;


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

// SOURCE https://catlikecoding.com/unity/tutorials/rendering/part-8/
float3 BoxProjection (float3 direction, float3 position, float4 cubemapPosition, float3 boxMin, float3 boxMax)
{
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
            unity_4LightAtten0, worldPos, world);
    #endif
    return float3(0.0, 0.0, 0.0);
}

//SOURCE https://github.com/SCRN-VRC/Raymarching-with-ShadowCaster/blob/main/Dice.shader
float GetCheapAO(float3 p, float3 n)
{
    float ao;
    float v1 = 0.4, v2 = 0.6, v3 = 0.02, v4 = 0.025;
    ao = v1 + v2 * map(p + n * v3) / v4;
    for (int i = 1; i <= AO_RAY_CASTS; i++)
    {
        v1+= 0.1;
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
        return 1.0; // no attenuation ie no shadowing
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

float GetTransparency()
{
    return _TransparencyFactor;
}

UnityLight CreateLight(float4 pointClipSpace, float3 pointWorldSpace, float3 normalWorldSpace, out float ndotl)
{
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
    //float
    ndotl = saturate(dot(normalWorldSpace, lightDirectionWorldSpace));
    float fresnel = pow(ndotl, _SpecularPower);
    light.color = _LightColor0.rgb * attenuation * fresnel * _SpecularColorTint.rgb;
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
    #endif

    float occlusion = GetCheapAO(worldPos, worldNormal);
    indirectLight.diffuse *= occlusion;
    indirectLight.specular *= occlusion;


    return indirectLight;
}

struct RefractionData
{
    float3 rdAirBehindRed;
    float3 rdAirBehindGreen;
    float3 rdAirBehindBlue;
    float3 rdReflection;
    float fresnel;
    float opticalDistance;
    float3 nEnter;
    float3 colors;
};

#define GETPROBEMAP0(RD) DecodeHDR(UNITY_SAMPLE_TEXCUBE(unity_SpecCube0, RD), unity_SpecCube0_HDR)

float SchlickFresnel(float3 rd, float3 normal, float IOR)
{
    float r0 = (1.0 - IOR) / (1.0 + IOR);
    r0 = r0 * r0;
    float cosine = max(0.0, dot(-rd, normal));
    float f = r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0);
    return f;
}

#define GETBGCOLOR(UV) tex2Dproj(_GrabTexture, UNITY_PROJ_COORD(UV))

// SOURCE https://www.shadertoy.com/view/sls3WN // TUT 1
// SOURCE https://www.shadertoy.com/view/sllGDN // TUT 2
// REFRACTION DEMO
// https://www.shadertoy.com/view/sllGDN
// REFRACTION TUTORIAL PART 1
// https://youtu.be/NCpaaLkmXI8
// REFRACTION TUTORIAL PART 2
// https://youtu.be/0RWaR7zApEo

RefractionData GetRefractionReflection(float3 roAirFront, float3 rdAirFront, float IOR, float chromaticAberration, float density, float4 uvGrab, bool doGrab)
{
    RefractionData refraction_data;
    float dAirFront;
    Raymarch(roAirFront, rdAirFront, dAirFront);
    float3 pEnter = roAirFront + rdAirFront * dAirFront; // find air-to-material entry point
    refraction_data.nEnter = GetNormal(pEnter); // surface normal at entry point
    float3 rdInside = refract(rdAirFront, refraction_data.nEnter, 1.0 / IOR); // ray direction change air-to-material
    float3 roFindExit = pEnter + rdInside * (MAX_DIST - 1.0); // setup a backtrace point far away
    float dFindExit;
    Raymarch(roFindExit, -rdInside, dFindExit); // find by backtracing a distance to exit point air-to-material on other side of SDF
    float3 pExit = roFindExit - rdInside * dFindExit; // setup material-to-air exit point
    float3 nExit = -GetNormal(pExit); // surface normal at material-to-air exit point, INVERTED
    // red
    refraction_data.rdAirBehindRed = refract(rdInside, nExit, IOR - chromaticAberration);
    if (dot(refraction_data.rdAirBehindRed, refraction_data.rdAirBehindRed) == 0.) refraction_data.rdAirBehindRed = reflect(rdInside, nExit); // total internal reflection
    refraction_data.rdAirBehindRed = UnityObjectToWorldDir(refraction_data.rdAirBehindRed);
    // green
    refraction_data.rdAirBehindGreen = refract(rdInside, nExit, IOR);
    if (dot(refraction_data.rdAirBehindGreen, refraction_data.rdAirBehindGreen) == 0.) refraction_data.rdAirBehindGreen = reflect(rdInside, nExit);
    refraction_data.rdAirBehindGreen = UnityObjectToWorldDir(refraction_data.rdAirBehindGreen);
    // blue
    refraction_data.rdAirBehindBlue = refract(rdInside, nExit, IOR + chromaticAberration);
    if (dot(refraction_data.rdAirBehindBlue, refraction_data.rdAirBehindBlue) == 0.) refraction_data.rdAirBehindBlue = reflect(rdInside, nExit);
    refraction_data.rdAirBehindBlue = UnityObjectToWorldDir(refraction_data.rdAirBehindBlue);
    // refracted color diminishing relative to material density and path length travelled by internal ray
    refraction_data.opticalDistance = exp(-length(pExit - pEnter) * density);
    // fresnel
    refraction_data.fresnel = SchlickFresnel(rdAirFront, refraction_data.nEnter, IOR);
    refraction_data.rdReflection = UnityObjectToWorldDir(reflect(rdAirFront, refraction_data.nEnter));
    float3 refractionColor = 0.0;
    if (doGrab)
    {
        #ifdef _REFRACTION_PROBE
        // refraction via grabbing reflection probe 0 at required angles 
        refractionColor.r = GETPROBEMAP0(refraction_data.rdAirBehindRed).r;
        refractionColor.g = GETPROBEMAP0(refraction_data.rdAirBehindGreen).g;
        refractionColor.b = GETPROBEMAP0(refraction_data.rdAirBehindBlue).b;
        float opticalDistance = exp(-length(pExit - pEnter) * density);
        refractionColor = refractionColor * opticalDistance;
        float3 reflectionColor = GETPROBEMAP0(refraction_data.rdReflection).rgb;
        refraction_data.colors = lerp(refractionColor, reflectionColor, refraction_data.fresnel);
        #else // _REFRACTION_FAKE
        // fake refraction via background color, grabbed at UV.xy shifted location.
        // SOURCE https://gist.github.com/smokelore/5e40fdcf36bea1e506586de44cfadb9c
        // SOURCE https://www.youtube.com/watch?v=aX7wIp-r48c
        float4 uvOffset = 0.0;
        uvOffset = uvGrab;
        uvOffset.xy += refraction_data.rdAirBehindRed.xy * _FakeRefractionMultiplier;
        refraction_data.colors.r = GETBGCOLOR(uvOffset).r;
        uvOffset = uvGrab;
        uvOffset.xy += refraction_data.rdAirBehindGreen.xy * _FakeRefractionMultiplier;
        refraction_data.colors.g = GETBGCOLOR(uvOffset).g;
        uvOffset = uvGrab;
        uvOffset.xy += refraction_data.rdAirBehindBlue.xy * _FakeRefractionMultiplier;
        refraction_data.colors.b = GETBGCOLOR(uvOffset).b;
        #endif
        refraction_data.colors *= refraction_data.opticalDistance;
    }
    else
    {
        refraction_data.colors = 0.0;
    }
    return refraction_data;
}

//SOURCE https://catlikecoding.com/unity/tutorials/rendering/part-4/
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
    RefractionData rrData = GetRefractionReflection(ro,rd,_IOR,_ChromaticAberration,_OpticalDensity,i.uvgrab, true);
    float3 specularTint;
    float oneMinusReflectivity;
    float3 albedo = DiffuseAndSpecularFromMetallic(
    lerp(GetAlbedo()*ambientOcclusion, rrData.colors*ambientOcclusion, GetTransparency()),
    GetMetallic() * ambientOcclusion,
    specularTint,
    oneMinusReflectivity);
    float fresnel;
    //for better or worse, we're using of unity's idea of pbs. maybe a custom implementation would work better ?
    //if so, consider it a homework assignment ;) i know i'll try someday.
    float4 color = UNITY_BRDF_PBS(
        albedo,
        specularTint,
        oneMinusReflectivity, GetSmoothness()*ambientOcclusion,
        normalWorldSpace, viewDirectionWorld,
        CreateLight(pointClipSpace, pointWorldSpace, normalWorldSpace, fresnel),
        CreateIndirectLight(pointWorldSpace, normalWorldSpace, viewDirectionWorld));
    color.rgb = lerp(color.rgb, rrData.colors, GetTransparency());
    color.rgb += GetEmission();
    //this one has a quite pronounced visual effect ! could be more elaborate than this, if so desired.
    color.a = GetTransparency();    
    //go to window > rendering > lighting settings > [scroll to bottom] enable fog & change density to 0.1 for immediate effect
    UNITY_APPLY_FOG_COLOR(i.fogDepth, color, unity_FogColor);
    return color;
}
#endif
