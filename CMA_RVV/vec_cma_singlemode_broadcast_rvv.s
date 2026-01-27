# =========================================================================
# CMA SINGLEMODE BROADCAST - RISC-V VECTOR 1.0 (64-bit)
# =========================================================================
# Entrada:
#   a0: complex64_t *h      (ponteiro para coeficientes)
#   a1: complex64_t *x      (ponteiro para entrada)
#   a2: int nTaps           (número de coeficientes)
#   fa0: double term_re     (parte real do broadcast mu*err*y)
#   fa1: double term_im     (parte imaginária)
# 
# Operação: Atualização vetorial usando broadcast dos termos escalares
#           h = h + term * conj(x)
# =========================================================================

.section .text
.align 2
.globl vec_cma_singlemode_broadcast_rvv

vec_cma_singlemode_broadcast_rvv:
    # a0=ptr_h, a1=ptr_x, a2=nTaps
    # fa0=term_re, fa1=term_im
    beqz a2, end_broad

loop_broad:
    vsetvli t0, a2, e64, m1, ta, ma
    vlseg2e64.v v0, (a1)      
    vlseg2e64.v v2, (a0)      

    vfmacc.vf v2, fa0, v0
    vfmacc.vf v2, fa1, v1
    vfmacc.vf v3, fa1, v0
    vfnmsac.vf v3, fa0, v1

    vsseg2e64.v v2, (a0)
    slli t1, t0, 4
    add a0, a0, t1
    add a1, a1, t1
    sub a2, a2, t0
    bnez a2, loop_broad

end_broad:
    ret