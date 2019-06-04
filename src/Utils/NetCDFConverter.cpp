//
// Created by christoph on 25.09.18.
//

#include <iostream>
#include <vector>
#include <memory>
#include <fstream>
#include <iomanip>
#include <cassert>

#include <glm/glm.hpp>
#include <netcdf.h>

#include "NetCDFConverter.hpp"

#if defined(DEBUG) || !defined(NDEBUG)
#define myassert assert
#else
#define myassert(x)                                   \
	if (!(x))                                         \
	{                                                 \
		std::cerr << "assertion failed" << std::endl; \
		exit(1);                                      \
	}
#endif

/// Sets pointer to NULL after deletion.
#define SAFE_DELETE(x) (if (x != NULL) { delete x; x = NULL; })
#define SAFE_DELETE_ARRAY(x) if (x != NULL) { delete[] x; x = NULL; }

const float MISSING_VALUE = -999.E9;


/**
 * Queries a global string attribute.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the global variable.
 * @return The content of the variable.
 */
std::string getGlobalStringAttribute(int ncid, const char *varname)
{
    size_t stringLength = 0;
    myassert(nc_inq_attlen(ncid, NC_GLOBAL, varname, &stringLength) == NC_NOERR);
    char *stringVar = new char[stringLength + 1];
    nc_get_att_text(ncid, NC_GLOBAL, varname, stringVar);
    stringVar[stringLength] = '\0';
    std::string retString(stringVar);
    delete[] stringVar;
    return retString;
}

/**
 * Returns the size of a dimension as an integer.
 * @param ncid The NetCDF file ID.
 * @param dimname The name of the dimension, e.g. "time".
 * @return The dimension size.
 */
size_t getDim(int ncid, const char *dimname)
{
    int dimid;
    size_t dimlen;
    myassert(nc_inq_dimid(ncid, dimname, &dimid) == 0);
    myassert(nc_inq_dimlen(ncid, dimid, &dimlen) == 0);
    return dimlen;
}

/**
 * Loads a 1D floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param len The dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadFloatArray1D(int ncid, const char *varname, size_t len, float **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new float[len];
    size_t startp[] = {0};
    size_t countp[] = {len};
    myassert(nc_get_vara_float(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 1D floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param start Offset from start of file buffer.
 * @param len Number of values to read.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadFloatArray1D(int ncid, const char *varname, size_t start, size_t len, float **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new float[len];
    size_t startp[] = {start};
    size_t countp[] = {len};
    myassert(nc_get_vara_float(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 1D double-precision floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param len The dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadDoubleArray1D(int ncid, const char *varname, size_t len, double **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new double[len];
    size_t startp[] = {0};
    size_t countp[] = {len};
    myassert(nc_get_vara_double(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 2D double-precision floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param ylen Dimension size queried by @ref getDim.
 * @param xlen Dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadDoubleArray2D(int ncid, const char *varname, size_t ylen, size_t xlen, double **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new double[ylen * xlen];
    size_t startp[] = {0, 0};
    size_t countp[] = {ylen, xlen};
    myassert(nc_get_vara_double(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 2D floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param ylen Dimension size queried by @ref getDim.
 * @param xlen Dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadFloatArray2D(int ncid, const char *varname, size_t ylen, size_t xlen, float **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new float[ylen * xlen];
    size_t startp[] = {0, 0};
    size_t countp[] = {ylen, xlen};
    myassert(nc_get_vara_float(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 3D floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param zlen Dimension size queried by @ref getDim.
 * @param ylen Dimension size queried by @ref getDim.
 * @param xlen Dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadFloatArray3D(int ncid, const char *varname, size_t zlen, size_t ylen, size_t xlen, float **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new float[zlen * ylen * xlen];
    size_t startp[] = {0, 0, 0};
    size_t countp[] = {zlen, ylen, xlen};
    myassert(nc_get_vara_float(ncid, varid, startp, countp, *array) == 0);
}

/**
 * Loads a 3D floating point variable.
 * @param ncid The NetCDF file ID.
 * @param varname The name of the variable, e.g. "time".
 * @param zstart Dimension size queried by @ref getDim.
 * @param ystart Dimension size queried by @ref getDim.
 * @param xstart Dimension size queried by @ref getDim.
 * @param zlen Dimension size queried by @ref getDim.
 * @param ylen Dimension size queried by @ref getDim.
 * @param xlen Dimension size queried by @ref getDim.
 * @param array A pointer to a float array where the variable data is to be stored.
 *              The function will automatically allocate the memory.
 *              The caller needs to deallocate the allocated memory using "delete[]".
 */
void loadFloatArray3D(int ncid, const char *varname, size_t zstart, size_t ystart, size_t xstart,
        size_t zlen, size_t ylen, size_t xlen, float **array)
{
    int varid;
    myassert(nc_inq_varid(ncid, varname, &varid) == 0);
    *array = new float[zlen * ylen * xlen];
    size_t startp[] = {zstart, ystart, xstart};
    size_t countp[] = {zlen, ylen, xlen};
    myassert(nc_get_vara_float(ncid, varid, startp, countp, *array) == 0);
}



Trajectories convertLatLonToCartesian(float *lat, float *lon, float *pressure, size_t trajectoryDim,
        size_t timeDim) {
    Trajectories trajectories;
    trajectories.reserve(timeDim);

    float minPressure = FLT_MAX;
    float maxPressure = -FLT_MAX;
    //float minPressure = 1200.0f;
    //float maxPressure = 0.0001f;
	#pragma omp parallel for reduction(min:minPressure) reduction(max:maxPressure)
	for (size_t idx = 0; idx < trajectoryDim*timeDim; idx++) {
	    if (pressure[idx] > 0.0f) {
            minPressure = std::min(minPressure, pressure[idx]);
	    }
		maxPressure = std::max(maxPressure, pressure[idx]);
	}
	float logMinPressure = log(minPressure);
	float logMaxPressure = log(maxPressure);

    for (int trajectoryIndex = 0; trajectoryIndex < trajectoryDim; trajectoryIndex++) {
        Trajectory trajectory;
        trajectory.attributes.resize(1);
        std::vector<glm::vec3> &cartesianCoords = trajectory.positions;
        std::vector<float> &pressureAttr = trajectory.attributes.at(0);
        cartesianCoords.reserve(trajectoryDim);
        pressureAttr.reserve(trajectoryDim);
        for (int i = 0; i < timeDim; i++) {
            int index = i + trajectoryIndex*timeDim;
            float pressureAtIdx = pressure[index];
            if (pressureAtIdx <= 0.0f) {
                continue;
            }
            //float normalizedPressure = (pressureAtIdx - minPressure) / (maxPressure - minPressure);
            float normalizedLogPressure = (log(pressureAtIdx) - logMaxPressure) / (logMinPressure - logMaxPressure);
            float x = lat[index]/100.0f;
            float y = normalizedLogPressure;
            float z = lon[index]/100.0f;

            glm::vec3 cartesianCoord = glm::vec3(x, y, z);

            cartesianCoords.push_back(cartesianCoord);
            pressureAttr.push_back(pressureAtIdx);
        }

        if (!trajectory.positions.empty()) {
            trajectories.push_back(trajectory);
        }
    }
    return trajectories;
}

/**
 * Exports the passed trajectories to an .obj file. The normalized pressure is stored as a texture coordinate.
 * @param trajectories The trajectory paths to export.
 * @param filename The filename of the .obj file.
 */
void exportObjFile(Trajectories &trajectories, const std::string &filename)
{
    std::ofstream outfile;
    outfile.open(filename.c_str());
    if (!outfile.is_open()) {
        std::cerr << "ERROR in exportObjFile: File \"" << filename << "\" couldn't be opened for writing!" << std::endl;
        exit(1);
        return;
    }

    // We want five digits in output file
    outfile << std::setprecision(5);

    // Index of the next point
    size_t objPointIndex = 1;

    size_t trajectoryFileIndex = 0;
    for (size_t trajectoryIndex = 0; trajectoryIndex < trajectories.size(); trajectoryIndex++) {
        Trajectory &trajectory = trajectories.at(trajectoryIndex);
        size_t trajectorySize = trajectory.positions.size();
        if (trajectorySize < 2) {
            continue;
        }

        for (size_t i = 0; i < trajectorySize; i++) {
            glm::vec3 &v = trajectory.positions.at(i);
            outfile << "v " << std::setprecision(5) << v.x << " " << v.y << " " << v.z << "\n";
            outfile << "vt " << std::setprecision(5) << trajectory.attributes.at(0).at(i) << "\n";
        }

        outfile << "g line" << trajectoryFileIndex << "\n";
        outfile << "l ";
        for (size_t i = 1; i < trajectorySize+1; i++) {
            outfile << objPointIndex << " ";
            objPointIndex++;
        }
        outfile << "\n\n";
        trajectoryFileIndex++;
    }
    outfile.close();
}

Trajectories loadNetCdfFile(const std::string &filename)
{
    Trajectories trajectories;

    // File handle
    int ncid;

    // Open the NetCDF file for reading
    int status = nc_open(filename.c_str(), NC_NOWRITE, &ncid);
    if (status != 0) {
        std::cerr << "ERROR in loadNetCdfFile: File \"" << filename << "\" couldn't be opened!" << std::endl;
        return trajectories;
    }

    // Load dimension data
    size_t timeDim = getDim(ncid, "time");
    size_t trajectoryDim = getDim(ncid, "trajectory");
    size_t ensembleDim = getDim(ncid, "ensemble");
    size_t startLonDim = getDim(ncid, "start_lon");
    size_t startLatDim = getDim(ncid, "start_lat");
    size_t timeIntervalDim = getDim(ncid, "time_interval");

    // Load data arrays
    double *time = NULL;
    float *lon = NULL, *lat = NULL, *pressure = NULL, *startLon = NULL, *startLat = NULL, *timeInterval = NULL;
    loadDoubleArray1D(ncid, "time", timeDim, &time);
    loadFloatArray3D(ncid, "lon", 1, trajectoryDim, timeDim, &lon);
    loadFloatArray3D(ncid, "lat", 1, trajectoryDim, timeDim, &lat);
    loadFloatArray3D(ncid, "pressure", 1, trajectoryDim, timeDim, &pressure);
    loadFloatArray1D(ncid, "start_lon", startLonDim, &startLon);
    loadFloatArray1D(ncid, "start_lat", startLatDim, &startLat);
    loadFloatArray1D(ncid, "time_interval", timeIntervalDim, &timeInterval);


    trajectories = convertLatLonToCartesian(lat, lon, pressure, trajectoryDim, timeDim);
    std::string outputFilename = filename.substr(0, filename.find_last_of(".")) + ".obj";
    //exportObjFile(trajectories, outputFilename);


    // Close the file
    myassert(nc_close(ncid) == NC_NOERR);

    SAFE_DELETE_ARRAY(time);
    SAFE_DELETE_ARRAY(lon);
    SAFE_DELETE_ARRAY(lat);
    SAFE_DELETE_ARRAY(pressure);
    SAFE_DELETE_ARRAY(startLon);
    SAFE_DELETE_ARRAY(startLat);
    SAFE_DELETE_ARRAY(timeInterval);

    return trajectories;
}

