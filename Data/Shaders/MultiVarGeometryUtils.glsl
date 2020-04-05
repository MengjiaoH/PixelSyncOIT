#if !defined NUM_SEGMENTS
    #define NUM_SEGMENTS 9
#endif

#if !defined(NUM_INSTANCES)
#define NUM_INSTANCES 10
#endif

void createTubeSegments(inout vec3 positions[NUM_SEGMENTS], inout vec3 normals[NUM_SEGMENTS],
                        in vec3 center, in vec3 normal, in vec3 tangent, in float curRadius)
{
    const float theta = 2.0 * 3.1415926 / float(NUM_SEGMENTS);
    const float tangetialFactor = tan(theta); // opposite / adjacent
    const float radialFactor = cos(theta); // adjacent / hypotenuse

    vec3 binormal = cross(tangent, normal);
    mat3 matFrame = mat3(normal, binormal, tangent);

    vec2 position = vec2(curRadius, 0.0);
    for (int i = 0; i < NUM_SEGMENTS; i++) {
        vec3 pointOnCricle = matFrame * vec3(position, 0.0);
        positions[i] = pointOnCricle + center;
        normals[i] = normalize(pointOnCricle);

        // Add the tangent vector and correct the position using the radial factor.
        vec2 circleTangent = vec2(-position.y, position.x);
        position += tangetialFactor * circleTangent;
        position *= radialFactor;
    }
}

void computeAABBFromNDC(inout vec3 positions[NUM_SEGMENTS],
                        inout mat2 invMatNDC, inout vec2 bboxMin,
                        inout vec2 bboxMax, inout vec2 tangentNDC,
                        inout vec2 normalNDC, inout vec2 refPointNDC)
{
    for (int i = 0; i < NUM_SEGMENTS; i++)
    {
        vec4 pointNDC = mvpMatrix * vec4(positions[i], 1);
        pointNDC.xyz /= pointNDC.w;
        pointNDC.xy = invMatNDC * pointNDC.xy;

        bboxMin.x = min(pointNDC.x, bboxMin.x);
        bboxMax.x = max(pointNDC.x, bboxMax.x);
        bboxMin.y = min(pointNDC.y, bboxMin.y);
        bboxMax.y = max(pointNDC.y, bboxMax.y);
    }

    refPointNDC = vec2(bboxMin.x, bboxMax.y);
    normalNDC = vec2(0, bboxMin.y - bboxMax.y);
    tangentNDC = vec2(bboxMax.x - bboxMin.x, 0);
}

void computeTexCoords(inout vec2 texCoords[NUM_SEGMENTS], inout vec3 positions[NUM_SEGMENTS],
                      inout mat2 invMatNDC, inout vec2 tangentNDC, inout vec2 normalNDC,
                      inout vec2 refPointNDC)
{
    for (int i = 0; i < NUM_SEGMENTS; i++)
    {
        vec4 pointNDC = mvpMatrix * vec4(positions[i], 1);
        pointNDC.xyz /= pointNDC.w;
        pointNDC.xy = invMatNDC * pointNDC.xy;

        vec2 offsetNDC = pointNDC.xy - refPointNDC;
        texCoords[i] = vec2(dot(offsetNDC, normalize(tangentNDC)) / length(tangentNDC),
        dot(offsetNDC, normalize(normalNDC)) / length(normalNDC));
    }
}

#if !defined(NUM_CIRCLE_POINTS_PER_INSTANCE)
    #define NUM_CIRCLE_POINTS_PER_INSTANCE 3
#endif

void createPartialTubeSegments(inout vec3 positions[NUM_CIRCLE_POINTS_PER_INSTANCE],
                                inout vec3 normals[NUM_CIRCLE_POINTS_PER_INSTANCE],
                                in vec3 center, in vec3 normal,
                                in vec3 tangent, in float curRadius, in int varID)
{
    float theta = 2.0 * 3.1415926 / float(NUM_INSTANCES);
    float tangetialFactor = tan(theta); // opposite / adjacent
    float radialFactor = cos(theta); // adjacent / hypotenuse

    // Set position to the offset for ribbons (and rolls for varying radius)
    vec2 position = vec2(curRadius, 0.0);

    for (int i = 0; i < varID; i++) {
        vec2 circleTangent = vec2(-position.y, position.x);
        position += tangetialFactor * circleTangent;
        position *= radialFactor;
    }

    vec3 binormal = cross(tangent, normal);
    mat3 matFrame = mat3(normal, binormal, tangent);

    // Subdivide theta in number of segments per instance
    theta /= float(NUM_CIRCLE_POINTS_PER_INSTANCE - 1);
    tangetialFactor = tan(theta); // opposite / adjacent
    radialFactor = cos(theta); // adjacent / hypotenuse

    for (int i = 0; i < NUM_CIRCLE_POINTS_PER_INSTANCE; i++) {
        vec3 pointOnCricle = matFrame * vec3(position, 0.0);
        positions[i] = pointOnCricle + center;
        normals[i] = normalize(pointOnCricle);

        // Add the tangent vector and correct the position using the radial factor.
        vec2 circleTangent = vec2(-position.y, position.x);
        position += tangetialFactor * circleTangent;
        position *= radialFactor;
    }
}

void drawTangentLid(in vec3 p0, in vec3 p1, in vec3 p2)
{
    gl_Position = mvpMatrix * vec4(p0, 1.0);
    fragWorldPos = (mMatrix * vec4(p0, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(p0, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(p1, 1.0);
    fragWorldPos = (mMatrix * vec4(p1, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(p1, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(p2, 1.0);
    fragWorldPos = (mMatrix * vec4(p2, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(p2, 1.0)).xyz;
    EmitVertex();

    EndPrimitive();
}

void drawPartialCircleLids(inout vec3 circlePointsCurrent[NUM_CIRCLE_POINTS_PER_INSTANCE],
                            inout vec3 vertexNormalsCurrent[NUM_CIRCLE_POINTS_PER_INSTANCE],
                            inout vec3 circlePointsNext[NUM_CIRCLE_POINTS_PER_INSTANCE],
                            inout vec3 vertexNormalsNext[NUM_CIRCLE_POINTS_PER_INSTANCE],
                            in vec3 centerCurrent, in vec3 centerNext, in vec3 tangent)
{
    vec3 pointCurFirst = circlePointsCurrent[0];
    vec3 pointNextFirst = circlePointsNext[0];

    vec3 pointCurLast = circlePointsCurrent[NUM_CIRCLE_POINTS_PER_INSTANCE - 1];
    vec3 pointNextLast = circlePointsNext[NUM_CIRCLE_POINTS_PER_INSTANCE - 1];

    // 1) First half
    gl_Position = mvpMatrix * vec4(pointCurFirst, 1.0);
    fragNormal = normalize(cross(normalize(pointCurFirst - centerCurrent), normalize(tangent)));
    fragTangent = tangent;//normalize(cross(tangent, fragNormal));
    fragWorldPos = (mMatrix * vec4(pointCurFirst, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(pointCurFirst, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(pointNextFirst, 1.0);
    fragWorldPos = (mMatrix * vec4(pointNextFirst, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(pointNextFirst, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(centerCurrent, 1.0);
    fragWorldPos = (mMatrix * vec4(centerCurrent, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(centerCurrent, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(centerNext, 1.0);
    fragWorldPos = (mMatrix * vec4(centerNext, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(centerNext, 1.0)).xyz;
    EmitVertex();

    EndPrimitive();

    // 2) Second half
    gl_Position = mvpMatrix * vec4(pointCurLast, 1.0);
    fragNormal = normalize(cross(normalize(tangent), normalize(pointCurLast - centerCurrent)));
    fragTangent = -tangent;//normalize(cross(tangent, fragNormal)); //! TODO compute actual tangent
    fragWorldPos = (mMatrix * vec4(pointCurLast, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(pointCurLast, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(centerCurrent, 1.0);
    fragWorldPos = (mMatrix * vec4(centerCurrent, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(centerCurrent, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(pointNextLast, 1.0);
    fragWorldPos = (mMatrix * vec4(pointNextLast, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(pointNextLast, 1.0)).xyz;
    EmitVertex();

    gl_Position = mvpMatrix * vec4(centerNext, 1.0);
    fragWorldPos = (mMatrix * vec4(centerNext, 1.0)).xyz;
    screenSpacePosition = (vMatrix * mMatrix * vec4(centerNext, 1.0)).xyz;
    EmitVertex();

    EndPrimitive();
}