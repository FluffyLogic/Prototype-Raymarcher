// RAYCASTING/RAYMARCHING FUNCTIONS
#if !defined(MY_RAYCAST_INCLUDED)
#define MY_RAYCAST_INCLUDED

/* depth map value from object space */
float GetWorldDepthFromObject(float3 objectSpaceDepthPoint)
{
    float3 worldPos = mul(unity_ObjectToWorld, float4(objectSpaceDepthPoint, 1.0));
    float4 clipPos = UnityWorldToClipPos(worldPos);
    return clipPos.z / clipPos.w;
}

/* sample the depth texture and convert into point in object space. function currently not used. */

sampler2D _CameraDepthTexture;

float3 GetBGGeometryDepthPoint(v2fColor i)
{
    float cameraDepth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)).r;
    float linearDepth = Linear01Depth(cameraDepth);
    float3 ray = i.ray * (_ProjectionParams.z / i.ray.z);
    float4 viewSpacePosition = float4(ray * linearDepth, 1);
    float3 worldSpacePosition = mul(unity_CameraToWorld, viewSpacePosition).xyz;
    return mul(unity_WorldToObject, float4(worldSpacePosition, 1)).xyz; //objectSpacePosition
}

/* SDF (Signed Distance Field) functions for describing mathematical primitives to be displayed. */

float sdfBox(float3 position, float3 dimensions)
{
    float3 d = abs(position) - dimensions;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdfTorus(float3 p, float ringRadius, float mainRadius)
{
    return length(float2(length(p.xz) - mainRadius, p.y)) - ringRadius;
}

float sdfSphere(float3 p, float r)
{
    return length(p) - r;
}

//smooth minimum, inputs a/b, smoothing factor k
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return lerp(b, a, h) - k * h * (1.0 - h);
}

//smooth max, usage similar to smin() 
float smax(float a, float b, float k)
{
  return log(exp(k * a) + exp(k * b)) / k;
}

// build 3D rotation matrix for use in mul(point, matrix).
// three input angles along main axes.
float3x3 rot3(float alpha, float beta, float gamma)
{
    float sina = sin(alpha);
    float cosa = cos(alpha);
    float sinb = sin(beta);
    float cosb = cos(beta);
    float sing = sin(gamma);
    float cosg = cos(gamma);
    
    float3x3 ra = float3x3
       (1, 0, 0,
        0, cosa, -sina,
        0, sina, cosa);
    float3x3 rb = float3x3
       (cosb, 0, sinb,
        0, 1, 0,
        -sinb, 0, cosb);
    float3x3 rg = float3x3
       (cosg, -sing, 0,
        sing, cosg, 0,
        0, 0, 1);
    return mul(rg, mul(rb, ra));
}

// build 2D rotation matrix for use in mul(point, matrix)
// two input angles along main axes
float2x2 rot2 (float theta)
{
    float sint = sin(theta);
    float cost = cos(theta);
    float2x2 rt = float2x2
        (cost, -sint,
        sint, cost);
    return (rt);
}

#define mod(x, y) ((x) - (y) * floor ((x) / (y)))

float3 hash33(float3 p)
{
  return frac(sin(float3(dot(p, float3(1.0, 57.0, 113.0)), dot(p, float3(57.0, 113.0, 1.0)),dot(p, float3(113.0, 1.0, 57.0)))) *43758.5453);
}

float voronoi31(float3 pCoordinate, float jitter)
{
    float3 iuv = floor(pCoordinate); //gets integer value without fraction
    float3 fuv = frac(pCoordinate); // gets only the fractional part
    float minDist = 1.0; // minimum distance
    for (int y = -1; y <= 1; y++)
        for (int x = -1; x <= 1; x++)
            for (int z = -1; z <= 1; z++)
            {
                // position of neighbour on the grid
                float3 neighbour = float3(float(x), float(y), float(z));
                // pandom position from current + neighbour place in the grid
                float3 pointv = hash33(iuv + neighbour);
                // move the point with time
                pointv = 0.5 + 0.5 * sin(jitter * 12.0 + 6.2236 * pointv); //each point moves in a certain way
                // vector between the pixel and the point
                float3 diff = neighbour + pointv - fuv;
                // distance to the point, standard euclidean
                float dist = length(diff);
                // distance, manhattan
                //float dist = abs(diff.x) + abs(diff.y) + abs(diff.z);
                // keep the closer distance
                minDist = min(minDist, dist);
            }
    //return the min distance (distance field)
    return minDist;
}

#define MOD3 float3(.1031,.11369,.13787)

float hash31(float3 p3)
{
    p3 = frac(p3 * MOD3);
    p3 += dot(p3, p3.yzx + 19.19);
    return -1.0 + 2.0 * frac((p3.x + p3.y) * p3.z);
}

// collective mesh scene for all SDFs. put here all math primitives you want displayed
float map(float3 p)
{
    // each example is in its own code block. to avoid confusion, please comment out all other unused examples to have a clear visual display
    float d1, d2, d3;
    //example : ring and moving sphere
    /*
    d1 = sdfSphere(p + float3(0.0, -0.5 + (sin(_Time.z) * 0.5 + 0.5), -0.1+ (cos(_Time.z) * 0.5 + 0.5)), 0.5);
    d2 = sdfTorus(p - float3(0.0, -0.1, +0.1), 0.3, 1.1);
    return smin(d1, d2, 0.2);
    */

    //return sdfBox(p, float3(1.2, 1.2, 1.2)); // example : just a box
    //return sdfBox(p, float3(1.0, 1.0, 1.0))-0.01; // example : box with slight beveling
    //return sdfSphere(p, 1.49); // example : just a sphere

    /*
    WARNING : SCALING UP XYZ COMPONENTS OF P TO >1 CAUSES RAY-MISSING-ARTEFACTS
    SOLUTION: find largest per-axis scale factor and if that max is >1, divide resulting distance by that factor
    WARNING : never tested against <0 factors, probably needs abs() in max() factor finder and a *sgn() in final output
    float3 componentFactors = float3(0.5, 1.1, 2.2);
    float3 rayPoint = float3(1.0, 2.0, 3.0);
    rayPoint = rayPoint * componentFactor;
    dist = mappingFunc(rayPoint);
    dist = dist / max(max(max(componentFactors.x, componentFactors.y), componentFactors.z), 1.0);
    */
    // example :  twisting torus and twisting moving box
    float time = _Time.y;
    float3 pTorus = p;
    pTorus.yz = mul(rot2(sin(time / 0.66) * pTorus.x), pTorus.yz); // twist shapes along x
    float3 factors = float3(0.6, 0.8, 1.0); // rescale
    pTorus.x *= factors.x;
    pTorus.y *= factors.y;
    pTorus.z *= factors.z;
    d1 = sdfTorus(pTorus, 0.2, 0.6);
	d1 /= max(max(max(factors.x, factors.y), factors.z), 1.0); // divide output with the largest factor, if factor is > 1.0
    float3 pBox = p;
    pBox.x += 0.65 * sin(time); // periodic move
    pBox.y += 0.7; // translate in space
    pBox.y /= 2.0; // stretch in Y
    pBox.xz = mul(rot2(sin(time/0.66) * pBox.y * 4.0), pBox.xz); // twist shapes on y axis
    d2 = sdfBox(pBox, float3(0.3, 0.3, 0.3)) - 0.005; // mildly rounded edges
    return smin(d1, d2, 0.2); // smooth merger between two primitives
}
// max drawing distance. this is 1600 units in unscaled object space, so same as worldspace
// this means if object in world space covers 1600 units in world space, the raymarcher will still cover that space
#define MAX_DIST 1600.0
//SOURCE https://www.shadertoy.com/view/llKfD1
bool Raymarch(float3 ro, float3 rd, out float t)
{
    float eps = 1e-4; // 0.0001f;
    t = map(ro);
    float dt = 0.0f;
    //float w = 1.2f; // ORIGINAL
    float w = 0.0;
    //float dw = 1.8f; // ORIGINAL
    float dw = 1.8f;
    float prevF = 0.0f;
    float prevDt = 0.0f;
    bool relaxed = true;
    int SANITY = 0; // integer hard limit for number of loops to avoid shader stalling
    while (t > eps && t < MAX_DIST && SANITY++ < 100)
    {
        float3 p = ro + rd * t;
        float f = map(p);
        dt = f * w;
        if (prevF + f < prevDt && relaxed)
        {
            relaxed = false;
            t += prevDt * (1.0f - w);
            p = ro + rd * t;
            f = map(p);
            dt = f * w;
        }
        if (f < eps)
        {
            return true;
        }
        else
        {
            t += dt;
            prevF = f;
            prevDt = dt;
            if (relaxed)
            {
                w = mod(frac(w) * dw, 1.0f) + 1.0f;
            }
            else
            {
                w = 1.2f;
            }
            eps *= 1.125f;
        }
    }
    return false;
}

// extended 4-tap normal calculation
float3 GetNormal(in float3 p)
{
    const float2 e = float2(15e-4, -15e-4);
    return normalize(
        e.xyy * map(p + e.xyy).x +
        e.yyx * map(p + e.yyx).x +
        e.yxy * map(p + e.yxy).x +
        e.xxx * map(p + e.xxx).x);
}

/* universal view functions for ray direction and target that work both in perspective and ortographic space projections */

float3 GetRayToCamera(float3 worldPos)
{
    return unity_OrthoParams.w > 0 ? -UNITY_MATRIX_V[2].xyz : worldPos - _WorldSpaceCameraPos;
}

float3 GetObjectSpaceRayDirection (v2fColor i)
{
    return UnityWorldToObjectDir(normalize(i.rayWDir));  // placing normalize() in vert() or getViewRay() messes up calculation ???
}

float3 GetObjectSpaceRayOrigin (v2fColor i)
{
    return mul(unity_WorldToObject, float4(i.rayWPos - MAX_DIST * normalize(i.rayWDir), 1.0));
}
float3 GetObjectSpaceRayDirection (v2fShadow i)
{
    return UnityWorldToObjectDir(normalize(i.rayWDir));  // placing normalize() in vert() or getViewRay() messes up calculation ???
}

float3 GetObjectSpaceRayOrigin (v2fShadow i)
{
    return mul(unity_WorldToObject, float4(i.rayWPos - MAX_DIST * normalize(i.rayWDir), 1.0));
}

/*
For unknown reason, this is order-dependent. 
Moving GetRayToLight() before lighting functions breaks the shader.
*/

#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

float3 GetRayToLight(float3 worldPos)
{
    if (_WorldSpaceLightPos0.w > 0)
        return worldPos.xyz - _WorldSpaceLightPos0.xyz;
    else
    #if defined(DIRECTIONAL)
        return UNITY_MATRIX_P._m33 == 1.0 ? -UNITY_MATRIX_V[2].xyz : GetRayToCamera(worldPos);
    #else
        return GetRayToCamera(worldPos);
    #endif
}

float3 GetViewRay(float3 worldPos)
{
    #if defined(UNITY_PASS_SHADOWCASTER)
        return GetRayToLight(worldPos);
    #else
        return GetRayToCamera(worldPos);
    #endif
}

#endif
