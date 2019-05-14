struct LineSegment
{
    vec3 v1; // Vertex position
    float a1; // Vertex attribute
    vec3 v2; // Vertex position
    float a2; // Vertex attribute
    uint lineID;
};

// Works until quantization resolution of 64^2 (6 + 2 * 2log2(64) = 30)
struct LineSegmentCompressed
{
// Bit 0-2, 3-5: Face ID of start/end point.
// For c = log2(QUANTIZATION_RESOLUTION^2) = 2*log2(QUANTIZATION_RESOLUTION):
// Bit 6-(5+c), (6+c)-(5+2c): Quantized face position of start/end point.
    uint linePosition;
// Bit 11-15: Line ID (5 bits for bitmask of 2^5 bits = 32 bits).
// Bit 16-23, 24-31: Attribute of start/end point (normalized to [0,1]).
    uint attributes;
};

layout (std430, binding = 4) buffer NumSegmentsBuffer
{
    uint numSegments[];
};

// MAX_NUM_LINES_PER_VOXEL * "voxel grid size"
layout (std430, binding = 5) buffer LineSegmentsBuffer
{
    LineSegmentCompressed lineSegments[];
};

vec3 getQuantizedPositionOffset(uint faceIndex, uint quantizedPos1D)
{
    vec2 quantizedFacePosition = vec2(
    float(quantizedPos1D % quantizationResolution.x),
    float(quantizedPos1D / quantizationResolution.x))
    / float(quantizationResolution.x);

    // Whether the face is the face in x/y/z direction with greater dimensions (offset factor)
    float face0or1 = float(faceIndex % 2);

    vec3 offset;
    if (faceIndex <= 1) {
        offset = vec3(face0or1, quantizedFacePosition.x, quantizedFacePosition.y);
    } else if (faceIndex <= 3) {
        offset = vec3(quantizedFacePosition.x, face0or1, quantizedFacePosition.y);
    } else if (faceIndex <= 5) {
        offset = vec3(quantizedFacePosition.x, quantizedFacePosition.y, face0or1);
    }
    return offset;
}

void decompressLine(vec3 voxelPosition, LineSegmentCompressed compressedLine, out LineSegment decompressedLine)
{
    const uint c = 2*log2(quantizationResolution.x);
    const uint bitmaskQuantizedPos = quantizationResolution.x*quantizationResolution.x-1;
    uint faceStartIndex = compressedLine.linePosition & 0x7u;
    uint faceEndIndex = (compressedLine.linePosition >> 3) & 0x7u;
    uint quantizedStartPos1D = (compressedLine.linePosition >> 6) & bitmaskQuantizedPos;
    uint quantizedEndPos1D = (compressedLine.linePosition >> 6+c) & bitmaskQuantizedPos;
    uint lineID = (compressedLine.attributes >> 11) & 32u;
    uint attr1 = (compressedLine.attributes >> 16) & 0xFFu;
    uint attr2 = (compressedLine.attributes >> 24) & 0xFFu;

    decompressedLine.v1 = voxelPosition + getQuantizedPositionOffset(faceStartIndex, quantizedStartPos1D);
    decompressedLine.v2 = voxelPosition + getQuantizedPositionOffset(faceEndIndex, quantizedEndPos1D);
    decompressedLine.a1 = float(attr1) / 255.0f;
    decompressedLine.a2 = float(attr2) / 255.0f;
    decompressedLine.lineID = lineID;
}

#ifdef HAIR_RENDERING
uniform vec4 hairStrandColor = vec4(1.0, 0.0, 0.0, 1.0);
#endif
