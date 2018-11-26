#ifndef TRAVERSAL_GLSL
#define TRAVERSAL_GLSL

#define MAX_STACK_SIZE (GRID_RESOLUTION_LOG2+1)

bool isPositionOutsideOfParent(ivec3 lodIndex, ivec3 parentStack[MAX_STACK_SIZE], int stackSize) {
	if (stackSize == 0) {
		return true;
	}

	ivec3 parentIndex = parentStack[stackSize-1];
	return parentIndex != lodIndex;
}

int intlog2(int x) {
	int log2x = 0;
	while ((x >>= 1) != 0) {
		++log2x;
	}
	return log2x;
}

ivec3 getNextVoxelIndex(ivec3 voxelIndex, float tMaxX, float tMaxY, float tMaxZ, int stepX, int stepY, int stepZ) {
    ivec3 nextVoxelIndex = voxelIndex;
    if (tMaxX < tMaxY) {
        if (tMaxX < tMaxZ) {
            nextVoxelIndex.x += stepX;
        } else {
            nextVoxelIndex.z += stepZ;
        }
    } else {
        if (tMaxY < tMaxZ) {
            nextVoxelIndex.y += stepY;
        } else {
            nextVoxelIndex.z += stepZ;
        }
    }
    return nextVoxelIndex;
}

/**
 * Code inspired by "A Fast Voxel Traversal Algorithm for Ray Tracing" written by John Amanatides, Andrew Woo.
 * http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.42.3443&rep=rep1&type=pdf
 * Value initialization code adapted from: https://stackoverflow.com/questions/12367071/how-do-i-initialize-the-t-
 * variables-in-a-fast-voxel-traversal-algorithm-for-ray
 *
 * Traverses the voxel grid from "startPoint" until "endPoint".
 * Calls "nextVoxel" each time a voxel is entered.
 * Returns the accumulated color using voxel raytracing.
 */
vec4 traverseVoxelGrid(vec3 rayOrigin, vec3 rayDirection, vec3 startPoint, vec3 endPoint)
{
    vec4 color = vec4(0.0);

    // Bit-mask for already blended lines
    uint blendedLineIDs = 0;
    uint newBlendedLineIDs = 0;
    uint lastNewBlendedLineIDs = 0;


    float tMaxX, tMaxY, tMaxZ, tDeltaX, tDeltaY, tDeltaZ;
    ivec3 voxelIndex;

    int stepX = int(sign(endPoint.x - startPoint.x));
    if (stepX != 0)
        tDeltaX = min(stepX / (endPoint.x - startPoint.x), 1e7);
    else
        tDeltaX = 1e7; // inf
    if (stepX > 0)
        tMaxX = tDeltaX * (1.0 - fract(startPoint.x));
    else
        tMaxX = tDeltaX * fract(startPoint.x);
    voxelIndex.x = int(startPoint.x);

    int stepY = int(sign(endPoint.y - startPoint.y));
    if (stepY != 0)
        tDeltaY = min(stepY / (endPoint.y - startPoint.y), 1e7);
    else
        tDeltaY = 1e7; // inf
    if (stepY > 0)
        tMaxY = tDeltaY * (1.0 - fract(startPoint.y));
    else
        tMaxY = tDeltaY * fract(startPoint.y);
    voxelIndex.y = int(startPoint.y);

    int stepZ = int(sign(endPoint.z - startPoint.z));
    if (stepZ != 0)
        tDeltaZ = min(stepZ / (endPoint.z - startPoint.z), 1e7);
    else
        tDeltaZ = 1e7; // inf
    if (stepZ > 0)
        tMaxZ = tDeltaZ * (1.0 - fract(startPoint.z));
    else
        tMaxZ = tDeltaZ * fract(startPoint.z);
    voxelIndex.z = int(startPoint.z);

    if (stepX == 0 && stepY == 0 && stepZ == 0) {
        return vec4(0.0);
    }
    ivec3 step = ivec3(stepX, stepY, stepZ);
    vec3 tMax = vec3(tMaxX, tMaxY, tMaxZ);
    vec3 tDelta = vec3(tDeltaX, tDeltaY, tDeltaZ);

    /*if (getNumLinesInVoxel(voxelIndex) > 0) {
        vec4 voxelColor = nextVoxel(rayOrigin, rayDirection, voxelIndex, blendedLineIDs);
        if (blendPremul(voxelColor, color)) {
            // Early ray termination
            return color;
        }
    }*/


    ivec3 parentStack[MAX_STACK_SIZE];
    int stackSize = 0;

    int maxLod = GRID_RESOLUTION_LOG2;//intlog2(gridResolution.x);
    int lod = maxLod;
    ivec3 lodIndex = voxelIndex / (1 << lod);
    int iterationNum = 0;

    /*uint numElementsRoot = texelFetch(octreeTexture, ivec3(0,0,0), 6).x;
    if (numElementsRoot > 0u) {
        return vec4(vec3(1.0, 0.6, 0.0), 1.0);
    }*/

    while (true) {
        bool shallAdvance = false;

        uint numElements = texelFetch(octreeTexture, lodIndex, lod).x;
        // Is the current level voxel used?
        if (numElements > 0u) {
            if (lod == 0) {
                // Voxel level is leaf
                ivec3 nextVoxelIndex = getNextVoxelIndex(voxelIndex, tMaxX, tMaxY, tMaxZ, stepX, stepY, stepZ);
                vec4 voxelColor = nextVoxel(rayOrigin, rayDirection, voxelIndex, nextVoxelIndex,
                        blendedLineIDs, newBlendedLineIDs);
                iterationNum++;
                blendedLineIDs = newBlendedLineIDs | lastNewBlendedLineIDs;
                lastNewBlendedLineIDs = newBlendedLineIDs;
                newBlendedLineIDs = 0;
                if (blendPremul(voxelColor, color)) {
                    // Early ray termination
                    return color;
                }
                shallAdvance = true;
            } else {
                // Voxel level is node -> implicit push operation
                lod--;
                lodIndex = voxelIndex / (1 << lod);
                if (stackSize < MAX_STACK_SIZE) {
                    parentStack[stackSize] = lodIndex;
                    stackSize++;
                    //return vec4(vec3(0.0, 0.0, 1.0), 1.0);
                }
            }
            //return vec4(vec3(0.0, 0.0, 1.0), 1.0);
        } else {
            // Not used. Go to next neighbor at current LOD level.
            shallAdvance = true;
        }

        if (shallAdvance) {
            while (true) {
                if (tMaxX < tMaxY) {
                    if (tMaxX < tMaxZ) {
                        voxelIndex.x += stepX;
                        tMaxX += tDeltaX;
                    } else {
                        voxelIndex.z += stepZ;
                        tMaxZ += tDeltaZ;
                    }
                } else {
                    if (tMaxY < tMaxZ) {
                        voxelIndex.y += stepY;
                        tMaxY += tDeltaY;
                    } else {
                        voxelIndex.z += stepZ;
                        tMaxZ += tDeltaZ;
                    }
                }
                lodIndex = voxelIndex / (1 << lod);

                if (isPositionOutsideOfParent(lodIndex, parentStack, stackSize)) {
                    //return vec4(vec3(0.9, float(lod) / 6.0f,  0.0), 1.0);
                    break;
                } else {
                    //return vec4(vec3(0.9, mod(float(voxelIndex.x + voxelIndex.y + voxelIndex.z) * 0.39475587, 1.0), 0.0), 1.0);
                    //return vec4(vec3(0.9, float(lod) / 6.0f,  0.0), 1.0);
                }
            }
            /*ivec3 numSteps = ivec3(0,0,0);
            while (true) {
                if (tMaxX < tMaxY) {
                    if (tMaxX < tMaxZ) {
                        numSteps += ivec3(1,0,0);
                    } else {
                        numSteps += ivec3(0,0,1);
                    }
                } else {
                    if (tMaxY < tMaxZ) {
                        numSteps += ivec3(0,1,0);
                    } else {
                        numSteps += ivec3(0,0,1);
                    }
                }
                lodIndex = (voxelIndex + numSteps * step) / (1 << lod);

                if (isPositionOutsideOfParent(lodIndex, parentStack, stackSize)) {
                    break;
                }
            }
            voxelIndex += numSteps * step;
            tMax += vec3(numSteps) * tDelta;*/

            // Explicit pop operations while outside of parent octant
            while (stackSize != 0 && isPositionOutsideOfParent(lodIndex, parentStack, stackSize)) {
                lod++;
                lodIndex = voxelIndex / (1 << lod);
                stackSize--;
            }
        }

        // Termination condition
        if (any(lessThan(voxelIndex, ivec3(0))) || any(greaterThanEqual(voxelIndex, gridResolution)))
            break;
    }


    /*int iterationNum = 0;
    while (true) {


        int maxLod = log2(gridResolution.x);
        int lod = maxLod;
        ivec3 lodIndex = voxelIndex / (lod+1);

        int numElements = texelFetch(octreeTexture, lodIndex, lod).x;
        if (numElements == 0) {
            advance;
        } else if (lod > 0) {
            // Push (go to more detailed lod)
            pushOctree(voxelIndex, lod, lodIndex);
            popOctree(voxelIndex, lod, lodIndex);
        } else {
            // Process voxel
            vec4 voxelColor = nextVoxel(rayOrigin, rayDirection, voxelIndex, blendedLineIDs);
            iterationNum++;
            oldBlendedLineIDs1 = blendedLineIDs;
            blendedLineIDs &= ~oldBlendedLineIDs2;
            oldBlendedLineIDs2 = oldBlendedLineIDs1;
            if (blendPremul(voxelColor, color)) {
                // Early ray termination
                return color;
            }
        }

        // Advance
        numSkipsAtVoxel = (1 << lod) - lodIndex;
        for (int i = 0; i < numSkipsAtVoxel; i++) {
            if (tMaxX < tMaxY) {
                if (tMaxX < tMaxZ) {
                    voxelIndex.x += stepX;
                    tMaxX += tDeltaX;
                } else {
                    voxelIndex.z += stepZ;
                    tMaxZ += tDeltaZ;
                }
            } else {
                if (tMaxY < tMaxZ) {
                    voxelIndex.y += stepY;
                    tMaxY += tDeltaY;
                } else {
                    voxelIndex.z += stepZ;
                    tMaxZ += tDeltaZ;
                }
            }
        }

        if (any(lessThan(voxelIndex, ivec3(0))) || any(greaterThanEqual(voxelIndex, gridResolution)))
            break;

        int lodIndex
        int numNodes = texelFetch(octreeTexture, pos, lodIndex);
        if (numNodes == 0) {
            // Skip
        } else {
            //
            texelFetch();
        }

        if (tMaxX < tMaxY) {
            if (tMaxX < tMaxZ) {
                voxelIndex.x += stepX;
                tMaxX += tDeltaX;
            } else {
                voxelIndex.z += stepZ;
                tMaxZ += tDeltaZ;
            }
        } else {
            if (tMaxY < tMaxZ) {
                voxelIndex.y += stepY;
                tMaxY += tDeltaY;
            } else {
                voxelIndex.z += stepZ;
                tMaxZ += tDeltaZ;
            }
        }
        //if (!(any(lessThan(voxelIndex, ivec3(0))) || any(greaterThanEqual(voxelIndex, gridResolution)))
        //        && (tMaxX > 1.0 && tMaxY > 1.0 && tMaxZ > 1.0))
        //    return vec4(vec3(1.0, 0.0, 0.0), 1.0);

        //if (tMaxX > 1.0 && tMaxY > 1.0 && tMaxZ > 1.0)
        //    break;
        if (any(lessThan(voxelIndex, ivec3(0))) || any(greaterThanEqual(voxelIndex, gridResolution)))
            break;

        if (getNumLinesInVoxel(voxelIndex) > 0) {
            vec4 voxelColor = nextVoxel(rayOrigin, rayDirection, voxelIndex, blendedLineIDs);
            iterationNum++;
            oldBlendedLineIDs1 = blendedLineIDs;
            blendedLineIDs &= ~oldBlendedLineIDs2;
            oldBlendedLineIDs2 = oldBlendedLineIDs1;
            if (blendPremul(voxelColor, color)) {
                // Early ray termination
                return color;
            }
            //return vec4(vec3(1.0), 1.0);
        }
    }*/

    return color;
}

#endif