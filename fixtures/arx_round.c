#include <stdint.h>

static inline uint32_t rotl32(uint32_t x, uint32_t n) {
    return (x << n) | (x >> (32 - n));
}

__attribute__((noinline))
void quarter_round(uint32_t state[4]) {
    state[0] += state[1]; state[3] ^= state[0]; state[3] = rotl32(state[3], 16);
    state[2] += state[3]; state[1] ^= state[2]; state[1] = rotl32(state[1], 12);
    state[0] += state[1]; state[3] ^= state[0]; state[3] = rotl32(state[3], 8);
    state[2] += state[3]; state[1] ^= state[2]; state[1] = rotl32(state[1], 7);
}

void double_round(uint32_t matrix[16]) {
    static const uint8_t idx[8][4] = {
        { 0,  4,  8, 12},
        { 1,  5,  9, 13},
        { 2,  6, 10, 14},
        { 3,  7, 11, 15},
        { 0,  5, 10, 15},
        { 1,  6, 11, 12},
        { 2,  7,  8, 13},
        { 3,  4,  9, 14}
    };
    uint32_t tmp[4];
    for (int r = 0; r < 8; r++) {
        for (int i = 0; i < 4; i++) tmp[i] = matrix[idx[r][i]];
        quarter_round(tmp);
        for (int i = 0; i < 4; i++) matrix[idx[r][i]] = tmp[i];
    }
}
