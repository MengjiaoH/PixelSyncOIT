-- Vertex

#version 430 core

#include "VertexAttributeNames.glsl"

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec3 vertexLineNormal;
layout(location = 2) in vec3 vertexLineTangent;
layout(location = 3) in float vertexAttribute0;
layout(location = 4) in float vertexAttribute1;
layout(location = 5) in float vertexAttribute2;
layout(location = 6) in float vertexAttribute3;
layout(location = 7) in float vertexAttribute4;
layout(location = 8) in float vertexAttribute5;

const uint NUM_MULTI_ATTRIBUTES = 6;

out VertexData
{
    vec3 linePosition;
    vec3 lineNormal;
    vec3 lineTangent;
    float lineAttributes[NUM_MULTI_ATTRIBUTES];
};

void main()
{
    linePosition = vertexPosition;
    lineNormal = vertexLineNormal;
    lineTangent = vertexLineTangent;
    lineAttributes = float[NUM_MULTI_ATTRIBUTES](vertexAttribute0, vertexAttribute1, vertexAttribute2,
                                                 vertexAttribute3, vertexAttribute4, vertexAttribute5);
}

-- RibbonGeometry

#version 430 core

layout(lines) in;
layout(triangle_strip, max_vertices = 128) out;

uniform float radius = 0.001f;

const uint NUM_MULTI_ATTRIBUTES = 6;
const uint CUR_ATTRIBUTE = 1;
const float MIN_RIBBON_WIDTH_PERCENTAGE = 0.1;
uniform vec2 minMaxCriterionValues[NUM_MULTI_ATTRIBUTES];

in VertexData
{
    vec3 linePosition;
    vec3 lineNormal;
    vec3 lineTangent;
    float lineAttributes[NUM_MULTI_ATTRIBUTES];
} v_in[];

out vec3 fragmentNormal;
out vec3 fragmentTangent;
out vec3 fragmentPositionWorld;
out vec3 screenSpacePosition;
flat out float fragmentAttribute;

float computeRibbonWidth(in float maxWidth, in uint attributeIndex, in float attributeValue)
{
    return maxWidth * max(MIN_RIBBON_WIDTH_PERCENTAGE, min(1.0,(attributeValue - minMaxCriterionValues[attributeIndex].x)
    / (minMaxCriterionValues[attributeIndex].y - minMaxCriterionValues[attributeIndex].x)));
}

void main()
{
//    vec3 currentPoint = (vMatrix * mMatrix * vec4(v_in[0].linePosition, 1.0)).xyz;
//    vec3 nextPoint = (vMatrix * mMatrix * vec4(v_in[1].linePosition, 1.0)).xyz;
    vec3 currentPoint = (mMatrix * vec4(v_in[0].linePosition, 1.0)).xyz;
    vec3 nextPoint = (mMatrix * vec4(v_in[1].linePosition, 1.0)).xyz;

    //    vec3 normalCurrent = v_in[0].lineNormal;
    //    vec3 tangentCurrent = v_in[0].lineTangent;
    //    vec3 binormalCurrent = cross(tangentCurrent, normalCurrent);
    //    vec3 normalNext = v_in[1].lineNormal;
    //    vec3 tangentNext = v_in[1].lineTangent;
    //    vec3 binormalNext = cross(tangentNext, normalNext);

    vec3 tangent = nextPoint - currentPoint;
    vec3 normal = (inverse(vMatrix) * vec4(0, 0, -1, 0)).xyz;

    float diameter = radius * 2;
    float ribbonWidthPerVar = diameter / NUM_MULTI_ATTRIBUTES;
    vec3 up = normalize((inverse(vMatrix) * vec4(0, 1, 0, 0)).xyz);

    vec3 upRadius = up * radius;
    float currentWidth = 0;
    float nextWidth = 0;

    vec2 ribbonOffsets[] = vec2[](vec2(0.0, 1.0), vec2(0.0, -1.0), vec2(1.0, 1.0), vec2(1.0, -1.0));

    vec3 initCurrentPosLowerBottom = currentPoint - upRadius * up;
    vec3 initNextPosLowerBottom = nextPoint - upRadius * up;

    for (uint i = 0; i < NUM_MULTI_ATTRIBUTES; ++i)
    {
        float currentAttributeValue = v_in[0].lineAttributes[i];
        float nextAttributeValue = v_in[1].lineAttributes[i];

        float currentRibbonWidth = computeRibbonWidth(ribbonWidthPerVar, i, currentAttributeValue);
        float nextRibbonWidth = computeRibbonWidth(ribbonWidthPerVar, i, nextAttributeValue);
//        float ribbonWidth = computeRibbonWidth(ribbonWidthPerVar, i, attributeValue);
//        vec3 upRibbon = up * ribbonWidth;
//        if (ribbonWidth <= 0) { continue; }

        vec3 currentPosLowerBottom = initCurrentPosLowerBottom + currentWidth * up;
//        vec3 currentPosCenter = currentPosLowerBottom + upRibbon / 2 - normal * ribbonWidth / 2.0;
        vec3 nextPosLowerBottom = initNextPosLowerBottom + nextWidth * up;
//        vec3 nexttPosCenter = nextPosLowerBottom + upRibbon / 2 - normal * ribbonWidth / 2.0;
        vec3 posOffsets[] = vec3[](currentPosLowerBottom, currentPosLowerBottom,
        nextPosLowerBottom, nextPosLowerBottom);
        float attributes[] = float[](currentAttributeValue, currentAttributeValue,
        nextAttributeValue, nextAttributeValue);
        float widths[] = float[](currentRibbonWidth, currentRibbonWidth,
        nextRibbonWidth, nextRibbonWidth);
//        vec3 posCenters[] = vec3[](currentPosCenter, currentPosCenter, nexttPosCenter, nexttPosCenter);
        float ribbonOffsets[] = float[](1.0, 0.0, 1.0, 0.0);

        for (int j = 0; j < 4; ++j)
        {
            float attributeValue = attributes[j];

            float offset = ribbonOffsets[j];
            vec3 offsetPos = posOffsets[j];
//            vec3 center = posCenters[j];

            float ribbonWidth = widths[j];
            vec3 upRibbon = up * ribbonWidth;

            vec3 pos = offsetPos + upRibbon * offset;
            vec3 center = offsetPos + upRibbon / 2.0 - normal * ribbonWidth / 2.0;

            gl_Position = mvpMatrix * vec4(pos, 1.0);
            fragmentNormal = normalize(pos - center);
            fragmentTangent = tangent;
            fragmentPositionWorld = pos;
            screenSpacePosition = (vMatrix * mMatrix * vec4(pos, 1.0)).xyz;
            fragmentAttribute = float(i);
            EmitVertex();
        }

        EndPrimitive();

        currentWidth += currentRibbonWidth;
        nextWidth += nextRibbonWidth;
    }
}

-- Geometry

#version 430 core

layout(lines) in;
layout(triangle_strip, max_vertices = 128) out;

uniform float radius = 0.001f;

const uint NUM_MULTI_ATTRIBUTES = 6;
const uint CUR_ATTRIBUTE = 1;

in VertexData
{
    vec3 linePosition;
    vec3 lineNormal;
    vec3 lineTangent;
    float lineAttributes[NUM_MULTI_ATTRIBUTES];
} v_in[];

out vec3 fragmentNormal;
out vec3 fragmentTangent;
out vec3 fragmentPositionWorld;
out vec3 screenSpacePosition;
flat out float fragmentAttribute;

#define NUM_SEGMENTS 5

void main()
{
    vec3 currentPoint = (mMatrix * vec4(v_in[0].linePosition, 1.0)).xyz;
    vec3 nextPoint = (mMatrix * vec4(v_in[1].linePosition, 1.0)).xyz;

    vec3 circlePointsCurrent[NUM_SEGMENTS];
    vec3 circlePointsNext[NUM_SEGMENTS];
    vec3 vertexNormalsCurrent[NUM_SEGMENTS];
    vec3 vertexNormalsNext[NUM_SEGMENTS];

    vec3 normalCurrent = v_in[0].lineNormal;
    vec3 tangentCurrent = v_in[0].lineTangent;
    vec3 binormalCurrent = cross(tangentCurrent, normalCurrent);
    vec3 normalNext = v_in[1].lineNormal;
    vec3 tangentNext = v_in[1].lineTangent;
    vec3 binormalNext = cross(tangentNext, normalNext);

    vec3 tangent = normalize(nextPoint - currentPoint);

    mat3 tangentFrameMatrixCurrent = mat3(normalCurrent, binormalCurrent, tangentCurrent);
    mat3 tangentFrameMatrixNext = mat3(normalNext, binormalNext, tangentNext);

    const float theta = 2.0 * 3.1415926 / float(NUM_SEGMENTS);
    const float tangetialFactor = tan(theta); // opposite / adjacent
    const float radialFactor = cos(theta); // adjacent / hypotenuse

    vec2 position = vec2(radius, 0.0);
    for (int i = 0; i < NUM_SEGMENTS; i++) {
        vec3 point2DCurrent = tangentFrameMatrixCurrent * vec3(position, 0.0);
        vec3 point2DNext = tangentFrameMatrixNext * vec3(position, 0.0);
        circlePointsCurrent[i] = point2DCurrent.xyz + currentPoint;
        circlePointsNext[i] = point2DNext.xyz + nextPoint;
        vertexNormalsCurrent[i] = normalize(circlePointsCurrent[i] - currentPoint);
        vertexNormalsNext[i] = normalize(circlePointsNext[i] - nextPoint);

        // Add the tangent vector and correct the position using the radial factor.
        vec2 circleTangent = vec2(-position.y, position.x);
        position += tangetialFactor * circleTangent;
        position *= radialFactor;
    }

    // Emit the tube triangle vertices
    for (int i = 0; i < NUM_SEGMENTS; i++) {
        gl_Position = mvpMatrix * vec4(circlePointsCurrent[i], 1.0);
        fragmentNormal = vertexNormalsCurrent[i];
        fragmentTangent = tangent;
        fragmentPositionWorld = (mMatrix * vec4(circlePointsCurrent[i], 1.0)).xyz;
        screenSpacePosition = (vMatrix * mMatrix * vec4(circlePointsCurrent[i], 1.0)).xyz;
        fragmentAttribute = v_in[0].lineAttributes[CUR_ATTRIBUTE];
        EmitVertex();

        gl_Position = mvpMatrix * vec4(circlePointsCurrent[(i+1)%NUM_SEGMENTS], 1.0);
        fragmentNormal = vertexNormalsCurrent[(i+1)%NUM_SEGMENTS];
        fragmentPositionWorld = (mMatrix * vec4(circlePointsCurrent[(i+1)%NUM_SEGMENTS], 1.0)).xyz;
        screenSpacePosition = (vMatrix * mMatrix * vec4(circlePointsCurrent[(i+1)%NUM_SEGMENTS], 1.0)).xyz;
        fragmentTangent = tangent;
        fragmentAttribute = v_in[0].lineAttributes[CUR_ATTRIBUTE];
        EmitVertex();

        gl_Position = mvpMatrix * vec4(circlePointsNext[i], 1.0);
        fragmentNormal = vertexNormalsNext[i];
        fragmentPositionWorld = (mMatrix * vec4(circlePointsNext[i], 1.0)).xyz;
        screenSpacePosition = (vMatrix * mMatrix * vec4(circlePointsNext[i], 1.0)).xyz;
        fragmentTangent = tangent;
        fragmentAttribute = v_in[1].lineAttributes[CUR_ATTRIBUTE];
        EmitVertex();

        gl_Position = mvpMatrix * vec4(circlePointsNext[(i+1)%NUM_SEGMENTS], 1.0);
        fragmentNormal = vertexNormalsNext[(i+1)%NUM_SEGMENTS];
        fragmentPositionWorld = (mMatrix * vec4(circlePointsNext[(i+1)%NUM_SEGMENTS], 1.0)).xyz;
        screenSpacePosition = (vMatrix * mMatrix * vec4(circlePointsNext[(i+1)%NUM_SEGMENTS], 1.0)).xyz;
        fragmentAttribute = v_in[1].lineAttributes[CUR_ATTRIBUTE];
        fragmentTangent = tangent;
        EmitVertex();

        EndPrimitive();
    }
}


-- Fragment

#version 430 core

in vec3 screenSpacePosition;

#if !defined(DIRECT_BLIT_GATHER) || defined(SHADOW_MAPPING_MOMENTS_GENERATE)
#include OIT_GATHER_HEADER
#endif

#if defined(USE_PROGRAMMABLE_FETCH) || defined(BILLBOARD_LINES)
in float fragmentNormalFloat;
in vec3 normal0;
in vec3 normal1;
#else
in vec3 fragmentNormal;
#endif
in vec3 fragmentTangent;
in vec3 fragmentPositionWorld;
flat in float fragmentAttribute;

#ifdef DIRECT_BLIT_GATHER
out vec4 fragColor;
#endif


#include "AmbientOcclusion.glsl"
#include "Shadows.glsl"

const uint NUM_MULTI_ATTRIBUTES = 6;
const uint CUR_ATTRIBUTE = 1;

#define M_PI 3.14159265358979323846

uniform vec3 lightDirection = vec3(1.0,0.0,0.0);
uniform vec3 cameraPosition; // world space
uniform float aoFactorGlobal = 1.0f;
uniform float shadowFactorGlobal = 1.0f;


uniform float minCriterionValue = 0.0;
uniform float maxCriterionValue = 1.0;
uniform vec2 minMaxCriterionValues[NUM_MULTI_ATTRIBUTES];
uniform bool transparencyMapping = true;

// Color of the object
uniform vec4 colorGlobal;


// Transfer function color lookup table
uniform sampler1D transferFunctionTexture;

vec4 transferFunction(float attr, uint index)
{
    // Transfer to range [0,1]
    float posFloat = clamp((attr - minMaxCriterionValues[index].x)
    / (minMaxCriterionValues[index].y - minMaxCriterionValues[index].x), 0.0, 1.0);
    // Look up the color value
    return texture(transferFunctionTexture, posFloat);
}

void main()
{
#if !defined(SHADOW_MAP_GENERATE) && !defined(SHADOW_MAPPING_MOMENTS_GENERATE)
    float occlusionFactor = getAmbientOcclusionFactor(vec4(fragmentPositionWorld, 1.0));
    float shadowFactor = getShadowFactor(vec4(fragmentPositionWorld, 1.0));
    occlusionFactor = mix(1.0f, occlusionFactor, aoFactorGlobal);
    shadowFactor = mix(1.0f, shadowFactor, shadowFactorGlobal);
#else
    float occlusionFactor = 1.0f;
    float shadowFactor = 1.0f;
#endif

    vec4 colorAttribute = transferFunction(fragmentAttribute, CUR_ATTRIBUTE);
    if (fragmentAttribute == 0.0) { colorAttribute = vec4(1, 0, 0, 1); }
    if (fragmentAttribute == 1.0) { colorAttribute = vec4(0, 1, 0, 1); }
    if (fragmentAttribute == 2.0) { colorAttribute = vec4(0, 0, 1, 1); }
    if (fragmentAttribute == 3.0) { colorAttribute = vec4(1, 0, 1, 1); }
    if (fragmentAttribute == 4.0) { colorAttribute = vec4(1, 1, 0, 1); }
    if (fragmentAttribute == 5.0) { colorAttribute = vec4(0, 1, 1, 1); }

    #if defined(USE_PROGRAMMABLE_FETCH) || defined(BILLBOARD_LINES)
    vec3 fragmentNormal;
    float interpolationFactor = fragmentNormalFloat;
    vec3 normalCos = normalize(normal0);
    vec3 normalSin = normalize(normal1);
    if (interpolationFactor < 0.0) {
        normalSin = -normalSin;
        interpolationFactor = -interpolationFactor;
    }
    float angle = interpolationFactor * M_PI / 2.0;
    fragmentNormal = cos(angle) * normalCos + sin(angle) * normalSin;
    #endif

    #if REFLECTION_MODEL == 0 // PSEUDO_PHONG_LIGHTING
    const vec3 lightColor = vec3(1,1,1);
    const vec3 ambientColor = colorAttribute.rgb;
    const vec3 diffuseColor = colorAttribute.rgb;

    const float kA = 0.2 * occlusionFactor * shadowFactor;
    const vec3 Ia = kA * ambientColor;
    const float kD = 0.7;
    const float kS = 0.1;
    const float s = 10;

    const vec3 n = normalize(fragmentNormal);
    const vec3 v = normalize(cameraPosition - fragmentPositionWorld);
//    const vec3 l = normalize(lightDirection);
    const vec3 l = normalize(v);
    const vec3 h = normalize(v + l);

    #ifdef CONVECTION_ROLLS
    vec3 t = normalize(cross(vec3(0, 0, 1), n));
    #else
    vec3 t = normalize(cross(vec3(0, 0, 1), n));
    #endif

    vec3 Id = kD * clamp(abs(dot(n, l)), 0.0, 1.0) * diffuseColor;
    vec3 Is = kS * pow(clamp(abs(dot(n, h)), 0.0, 1.0), s) * lightColor;

    float haloParameter = 1;
    float angle1 = abs( dot( v, n));
    float angle2 = abs( dot( v, normalize(t))) * 0.7;
    float halo = mix(1.0f,((angle1)+(angle2)) , haloParameter);

    vec3 colorShading = Ia + Id + Is;
    colorShading *= clamp(halo, 0, 1) * clamp(halo, 0, 1);
    #elif REFLECTION_MODEL == 1 // COMBINED_SHADOW_MAP_AND_AO
    vec3 colorShading = vec3(occlusionFactor * shadowFactor);
    #elif REFLECTION_MODEL == 2 // LOCAL_SHADOW_MAP_OCCLUSION
    vec3 colorShading = vec3(shadowFactor);
    #elif REFLECTION_MODEL == 3 // AMBIENT_OCCLUSION_FACTOR
    vec3 colorShading = vec3(occlusionFactor);
    #elif REFLECTION_MODEL == 4 // NO_LIGHTING
    vec3 colorShading = colorAttribute.rgb;
    #endif
    vec4 color = vec4(colorShading, colorAttribute.a);

    //color.rgb = fragmentNormal;

    if (!transparencyMapping) {
        color.a = colorGlobal.a;
    }

    if (color.a < 1.0/255.0) {
        discard;
    }

#ifdef DIRECT_BLIT_GATHER
    // Direct rendering
    fragColor = color;
#else
#if defined(REQUIRE_INVOCATION_INTERLOCK) && !defined(TEST_NO_INVOCATION_INTERLOCK)
    // Area of mutual exclusion for fragments mapping to the same pixel
    beginInvocationInterlockARB();
    gatherFragment(color);
    endInvocationInterlockARB();
#else
    gatherFragment(color);
#endif
#endif
}
