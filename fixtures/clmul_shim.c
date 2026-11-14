#include <stdint.h>
#include <wmmintrin.h>

uint64_t hs_clmul64(uint64_t a, uint64_t b) {
    __m128i va = _mm_cvtsi64_si128((long long)a);
    __m128i vb = _mm_cvtsi64_si128((long long)b);
    __m128i res = _mm_clmulepi64_si128(va, vb, 0x00);
    return (uint64_t)_mm_cvtsi128_si64(res);
}
