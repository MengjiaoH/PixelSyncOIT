-- Vertex

#version 430 core

layout(location = 0) in vec3 vertexPosition;
layout(location = 1) in vec4 vertexNormal;

//out vec4 fragmentColor;
out vec4 fragmentNormal;

// Model-view-projection matrix
uniform mat4 mvpMatrix;

void main()
{
	fragmentColor = vertexColor;
	gl_Position = mvpMatrix * vertexPosition;
}


-- Fragment

#version 430 core

// See https://www.khronos.org/registry/OpenGL/extensions/ARB/ARB_shader_image_load_store.txt
#extension GL_ARB_shader_image_load_store : require

// See https://www.khronos.org/registry/OpenGL/extensions/ARB/ARB_fragment_shader_interlock.txt
#extension GL_ARB_fragment_shader_interlock : require

// Use early z-test to cull transparent fragments occluded by opaque fragments.
// Additionaly, use fragment interlock.
layout(early_fragment_tests, pixel_interlock_unordered) in;

// gl_FragCoord will be used for pixel centers at integer coordinates.
// See https://www.khronos.org/registry/OpenGL-Refpages/gl4/html/gl_FragCoord.xhtml
layout(pixel_center_integer) in vec3 gl_FragCoord;

// A fragment node stores rendering information about one specific fragment
layout (std430) struct FragmentNode
{
	// RGBA color of the node
	vec4 color;
	// Depth value of the fragment (in view space)
	float depth;
	// Whether the node is empty or used
	uint used;
	
	// Padding to 2*vec4
	//uint padding1;
	//uint padding2;
};

// Stores renderTargetWidth * renderTargetHeight * nodesPerPixel fragments.
// Access fragment i at screen position (x,y) using "nodes[w*npp*y + npp*x + i]".
layout (std430, binding = 0) buffer FragmentNodes
{
	FragmentNode nodes[];
};

//in vec4 fragmentColor;
in vec4 fragmentNormal;

// Number of transparent pixels we can store per node
uniform int nodesPerPixel;

uniform int viewportW;
uniform int viewportH;

// Color of the object
uniform vec4 color;

void main()
{
	int x = int(gl_FragCoord.x);
	int y = int(gl_FragCoord.y);
	int index = nodesPerPixel*(renderTargetWidth*y + x);

	FragmentNode frag;
	// Pseudo Phong shading
	frag.color = vec4(color.rgb * (dot(normal, vec3(1.0,0.0,0.0))/4.0+0.75), color.a);
	frag.depth = gl_FragCoord.z;
	frag.used = 1;
	
	// Area of mutual exclusion for fragments mapping to same pixel
	beginInvocationInterlockARB();
	
	// Use bubble sort to insert new fragment
	for (int i = 0; i < nodesPerPixel; i++)
	{
		if (nodes[index].used == 0)
		{
			nodes[index] = frag;
			break;
		}
		else if (frag.depth < nodes[index].depth)
		{
			FragmentNode temp = frag;
			frag = nodes[index];
			nodes[index] = temp;
		}
		index++;
	}
	
	// If no space was left to store the last fragment, simply discard it.
	// TODO: Merge nodes with least visual impact.
	
	endInvocationInterlockARB();
}