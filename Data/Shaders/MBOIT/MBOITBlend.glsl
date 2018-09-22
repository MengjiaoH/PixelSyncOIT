-- Vertex

#version 430 core

layout(location = 0) in vec3 vertexPosition;

void main()
{
	gl_Position = mvpMatrix * vec4(vertexPosition, 1.0);
}


-- Fragment

#version 430 core

// See https://www.khronos.org/registry/OpenGL/extensions/ARB/ARB_shader_image_load_store.txt
#extension GL_ARB_shader_image_load_store : require

// gl_FragCoord will be used for pixel centers at integer coordinates.
// See https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/gl_FragCoord.xhtml
layout(pixel_center_integer) in vec4 gl_FragCoord;


out vec4 fragColor;

layout (binding = 0, r32f) coherent uniform image2DArray zeroth_moment; // float
#if SINGLE_PRECISION
#if NUM_MOMENTS == 6
layout (binding = 1, rg32f) coherent uniform image2DArray moments; // vec2
#if USE_R_RG_RGBA_FOR_MBOIT6
layout (binding = 2, rgba32f) coherent uniform image2DArray extra_moments; // vec4
#endif
#else
layout (binding = 1, rgba32f) coherent uniform image2DArray moments; // vec4
#endif
#else
#if NUM_MOMENTS == 6
layout (binding = 1, rg16) coherent uniform image2DArray moments;
#if USE_R_RG_RGBA_FOR_MBOIT6
layout (binding = 2, rgba16) coherent uniform image2DArray extra_moments;
#endif
#else
layout (binding = 1, rgba16) coherent uniform image2DArray moments;
#endif
#endif

uniform sampler2D transparentSurfaceAccumulator;

void clearMoments(ivec3 idx0)
{
	ivec3 idx1 = ivec3(idx0.xy, 1);
	ivec3 idx2 = ivec3(idx0.xy, 2);

    imageStore(zeroth_moment, idx0, vec4(0.0));
    imageStore(moments, idx0, vec4(0.0));
#if NUM_MOMENTS == 6
#if USE_R_RG_RGBA_FOR_MBOIT6
    imageStore(extra_moments, idx0, vec4(0.0));
#else
    imageStore(moments, idx1, vec4(0.0));
    imageStore(moments, idx2, vec4(0.0));
#endif
#elif NUM_MOMENTS == 8
    imageStore(moments, idx1, vec4(0.0));
#endif
}

void main()
{
    ivec3 idx0 = ivec3(ivec2(gl_FragCoord.xy), 0);
    vec4 color = texelFetch(transparentSurfaceAccumulator, idx0.xy, 0);
    ivec3 idx1 = ivec3(ivec2(gl_FragCoord.xy), 1);
    ivec3 idx2 = ivec3(ivec2(gl_FragCoord.xy), 2);
    vec4 color1 = imageLoad(moments, idx1);
    vec4 color2 = imageLoad(moments, idx2);
    float b_0 = imageLoad(zeroth_moment, idx0).x;
    if (b_0 < 0.00100050033f) {
        discard;
    }
    float total_transmittance = exp(-b_0);
    if (isinf(b_0)) {
        total_transmittance = 0.0f;
    }

    // Make sure data is cleared for next rendering pass
    clearMoments(idx0);

    //color_blend = exp(-b_0) * L_n + (1 - exp(-b_0)) * weighted_color
    fragColor = vec4(color.rgb / color.a, 1.0 - total_transmittance);
    //fragColor = vec4(color1.rg, color2.g, 1.0);
}

