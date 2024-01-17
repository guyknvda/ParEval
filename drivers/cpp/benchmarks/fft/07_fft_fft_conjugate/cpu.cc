// Driver for 07_fft_fft_conjugate for Serial, OpenMP, MPI, and MPI+OpenMP
// /* Compute the fourier transform of x in-place. Return the imaginary conjugate of each value.
//    Example:
// 
//    input: [1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0, 0.0]
//    output: [{4,0}, {1,-2.41421}, {0,0}, {1,-0.414214}, {0,0}, {1,0.414214}, {0,0}, {1,2.41421}]
// */
// void fft(std::vector<std::complex<double>> &x) {

#include <algorithm>
#include <cmath>
#include <numeric>
#include <random>
#include <vector>

#include "utilities.hpp"
#include "baseline.hpp"
#include "generated-code.hpp"   // code generated by LLM

struct Context {
    std::vector<std::complex<double>> x;
    std::vector<double> real, imag;
};

void reset(Context *ctx) {
    fillRand(ctx->real, -1.0, 1.0);
    fillRand(ctx->imag, -1.0, 1.0);
    BCAST(ctx->real, DOUBLE);
    BCAST(ctx->imag, DOUBLE);

    for (size_t i = 0; i < ctx->x.size(); i += 1) {
        ctx->x[i] = std::complex<double>(ctx->real[i], ctx->imag[i]);
    }
}

Context *init() {
    Context *ctx = new Context();

    ctx->x.resize(DRIVER_PROBLEM_SIZE);
    ctx->real.resize(DRIVER_PROBLEM_SIZE);
    ctx->imag.resize(DRIVER_PROBLEM_SIZE);

    reset(ctx);
    return ctx;
}

void NO_OPTIMIZE compute(Context *ctx) {
    fft(ctx->x);
}

void NO_OPTIMIZE best(Context *ctx) {
    correctFft(ctx->x);
}

bool validate(Context *ctx) {
    const size_t TEST_SIZE = 1024;

    std::vector<double> real(TEST_SIZE), imag(TEST_SIZE);
    std::vector<std::complex<double>> x(TEST_SIZE);

    int rank;
    GET_RANK(rank);

    const size_t numTries = MAX_VALIDATION_ATTEMPTS;
    for (int i = 0; i < numTries; i += 1) {
        // set up input
        fillRand(real, -1.0, 1.0);
        fillRand(imag, -1.0, 1.0);
        BCAST(real, DOUBLE);
        BCAST(imag, DOUBLE);

        for (size_t j = 0; j < x.size(); j += 1) {
            x[j] = std::complex<double>(real[j], imag[j]);
        }

        // compute correct result
        std::vector<std::complex<double>> correct = x;
        fftCooleyTookey(correct);

        // compute test result
        std::vector<std::complex<double>> test = x;
        fft(test);
        SYNC();
        
        bool isCorrect = true;
        if (IS_ROOT(rank)) {
            for (int k = 0; k < TEST_SIZE; k += 1) {
                if (std::abs(correct[k].real() - test[k].real()) > 1e-3 || std::abs(correct[k].imag() - test[k].imag()) > 1e-3) {
                    isCorrect = false;
                    break;
                }
            }
        }
        BCAST_PTR(&isCorrect, 1, CXX_BOOL);
        if (!isCorrect) {
            return false;
        }
    }

    return true;
}

void destroy(Context *ctx) {
    delete ctx;
}
