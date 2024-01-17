// Driver for 37_search_find_the_closest_number_to_pi for CUDA and HIP
// /* Find the index of the value in the vector x that is closest to the math constant PI. Store the index in closestToPiIndex.
//    Use M_PI for the value of PI.
//    Use CUDA to search in parallel. The kernel is launched with at least N threads.
//    Example:
// 
//    input: [9.18, 3.05, 7.24, 11.3, -166.49, 2.1]
//    output: 1
// */
// __global__ void findClosestToPi(const double *x, size_t N, size_t *closestToPiIndex) {

#include <algorithm>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "baseline.hpp"
#include "generated-code.cuh"   // code generated by LLM


#if defined(USE_CUDA)
#include <thrust/device_vector.h>
#include <thrust/copy.h>
#include <thrust/sort.h>
#include <thrust/iterator/counting_iterator.h>
#include <thrust/iterator/permutation_iterator.h>
#endif

struct Context {
    double *d_x;
    size_t *closestToPiIndex;
    std::vector<double> h_x;
    size_t N;
    dim3 blockSize, gridSize;
};

void reset(Context *ctx) {
    fillRand(ctx->h_x, -100.0, 100.0);
    COPY_H2D(ctx->d_x, ctx->h_x.data(), ctx->N * sizeof(double));
}

Context *init() {
    Context *ctx = new Context();

    ctx->N = DRIVER_PROBLEM_SIZE;
    ctx->blockSize = dim3(1024);
    ctx->gridSize = dim3((ctx->N + ctx->blockSize.x - 1) / ctx->blockSize.x); // at least enough threads

    ALLOC(ctx->d_x, ctx->N * sizeof(double));
    ALLOC(ctx->closestToPiIndex, 1 * sizeof(size_t));
    ctx->h_x.resize(ctx->N);

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    findClosestToPi<<<ctx->gridSize, ctx->blockSize>>>(ctx->d_x, ctx->N, ctx->closestToPiIndex);
}

void NO_OPTIMIZE best(Context *ctx) {
    size_t idx = correctFindClosestToPi(ctx->h_x);
    (void)idx;
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;
    dim3 blockSize = dim3(1024);
    dim3 gridSize = dim3((TEST_SIZE + blockSize.x - 1) / blockSize.x); // at least enough threads

    double *d_x;
    ALLOC(d_x, TEST_SIZE * sizeof(double));

    size_t *d_closestToPiIndex;
    ALLOC(d_closestToPiIndex, 1 * sizeof(size_t));

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int i = 0; i < numTries; i += 1) {
        // set up input
        std::vector<double> h_x(TEST_SIZE);
        fillRand(h_x, -100.0, 100.0);
        COPY_H2D(d_x, h_x.data(), TEST_SIZE * sizeof(double));

        size_t tmpClosestToPiIndex = 0;
        COPY_H2D(d_closestToPiIndex, &tmpClosestToPiIndex, 1 * sizeof(size_t));

        // compute correct result
        size_t correctIdx = correctFindClosestToPi(h_x);

        // compute test result
        findClosestToPi<<<gridSize, blockSize>>>(d_x, TEST_SIZE, ctx->closestToPiIndex);
        SYNC();

        // copy result back
        size_t testIdx;
        COPY_D2H(&testIdx, d_closestToPiIndex, 1 * sizeof(size_t));
        
        if (correctIdx != testIdx) {
            FREE(d_x);
            FREE(d_closestToPiIndex);
            return false;
        }
    }

    FREE(d_x);
    FREE(d_closestToPiIndex);
    return true;
}

void destroy(Context *ctx) {
    FREE(ctx->d_x);
    FREE(ctx->closestToPiIndex);
    delete ctx;
}
