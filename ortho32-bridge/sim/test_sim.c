#include "ortho_sim.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>
#include <ctype.h>

static int is_hex64(const char* s){
    if(strlen(s)!=64) return 0;
    for(int i=0;i<64;i++) if(!isxdigit((unsigned char)s[i])) return 0;
    return 1;
}

int main(void){
    printf("ortho_sim test: 4x4 identity matmul\n");
    ortho_handle_t h = ortho_sim_open();
    assert(h != NULL);

    ortho_command_t cmd;
    memset(&cmd, 0, sizeof(cmd));
    cmd.opcode = ORTHO_OP_TENSOR;
    // Identity 4x4
    float ident[16] = {1,0,0,0, 0,1,0,0, 0,0,1,0, 0,0,0,1};
    memcpy(cmd.matrixA, ident, sizeof(ident));
    memcpy(cmd.matrixB, ident, sizeof(ident));

    ortho_completion_t comp;
    int rc = ortho_sim_submit(h, &cmd, &comp);
    assert(rc==0);
    printf("cycles=%u expected 768\n", comp.cycles);
    assert(comp.cycles == 768);

    printf("resultHash=%s\n", comp.resultHash);
    printf("traceRoot=%s\n", comp.traceRoot);
    assert(is_hex64(comp.resultHash));
    assert(is_hex64(comp.traceRoot));
    assert(strcmp(comp.resultHash, comp.traceRoot)==0);

    // Verify result is identity (manual check)
    for(int i=0;i<16;i++){
        float expected = ident[i];
        if(comp.result[i] != expected){
            fprintf(stderr,"FAIL result[%d]=%f expected %f\n",i,comp.result[i],expected);
            return 1;
        }
    }
    printf("result matrix is identity - OK\n");

    // Verify hash is SHA-256 of actual output (recompute)
    char recomputed[65];
    ortho_sha256_hex((const uint8_t*)comp.result, sizeof(comp.result), recomputed);
    assert(strcmp(recomputed, comp.resultHash)==0);
    printf("SHA-256 verified over actual output bytes - OK\n");

    // Test with non-identity to ensure not canned
    float a[16] = {1,2,3,4, 5,6,7,8, 9,10,11,12, 13,14,15,16};
    float b[16] = {16,15,14,13, 12,11,10,9, 8,7,6,5, 4,3,2,1};
    memcpy(cmd.matrixA, a, sizeof(a));
    memcpy(cmd.matrixB, b, sizeof(b));
    rc = ortho_sim_submit(h, &cmd, &comp);
    assert(rc==0);
    assert(comp.cycles==768);
    assert(is_hex64(comp.resultHash));
    // Precomputed expected for above: check first element = 1*16+2*12+3*8+4*4=80
    assert(comp.result[0]==80.0f);
    printf("second matmul first element %f == 80 OK, hash %s\n", comp.result[0], comp.resultHash);

    ortho_sim_close(h);
    printf("ALL ASSERTS PASSED\n");
    return 0;
}
