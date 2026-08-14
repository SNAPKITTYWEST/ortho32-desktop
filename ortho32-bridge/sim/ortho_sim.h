#ifndef ORTHO_SIM_H
#define ORTHO_SIM_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define ORTHO_TENSOR_DIM 4
#define ORTHO_TENSOR_SIZE 16
#define ORTHO_ARCH_CYCLES 768

typedef void* ortho_handle_t;

typedef enum {
    ORTHO_OP_NOP = 0x00,
    ORTHO_OP_TENSOR = 0x01,
    ORTHO_OP_DMA = 0x02
} ortho_opcode_t;

typedef struct {
    ortho_opcode_t opcode;
    float matrixA[ORTHO_TENSOR_SIZE];
    float matrixB[ORTHO_TENSOR_SIZE];
    uint32_t flags;
} ortho_command_t;

typedef struct {
    uint32_t cycles;
    uint32_t status; // 0=ok
    float result[ORTHO_TENSOR_SIZE];
    char resultHash[65]; // hex SHA256 of result bytes
    char traceRoot[65];  // alias same as resultHash (architectural)
    uint64_t timestamp;
} ortho_completion_t;

// ABI
ortho_handle_t ortho_sim_open(void);
int ortho_sim_submit(ortho_handle_t handle, const ortho_command_t* cmd, ortho_completion_t* completion);
void ortho_sim_close(ortho_handle_t handle);
const char* ortho_sim_version(void);

// internal
void ortho_sha256_hex(const uint8_t* data, size_t len, char out_hex[65]);

#ifdef __cplusplus
}
#endif

#endif
