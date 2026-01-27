# =========================================================================
# CMA SINGLEMODE LOOP - RISC-V VECTOR 1.0 (64-bit)
# =========================================================================
# Entrada:
#   a0: complex64_t *h      (ponteiro para coeficientes)
#   a1: complex64_t *x      (ponteiro para entrada)
#   a2: int nTaps           (número de coeficientes)
#   fa0: double mu_re       (parte real do termo de atualização mu*err*y)
#   fa1: double mu_im       (parte imaginária)
# 
# Operação: h[i] += mu_prod * conj(x[i])
#           h[i].re += mu_re * x[i].re + mu_im * x[i].im
#           h[i].im += mu_im * x[i].re - mu_re * x[i].im
# =========================================================================

.section .text
.align 2
.globl vec_cma_singlemode_loop_rvv

vec_cma_singlemode_loop_rvv:
    # a0: ptr_h, a1: ptr_x, a2: nTaps
    # fa0: term_re, fa1: term_im
    
    beqz a2, end_func

loop_core:
    # t0 recebe o número de elementos processados nesta iteração
    vsetvli t0, a2, e64, m1, ta, ma

    # Cargas segmentadas: v0=Re(x), v1=Im(x) | v2=Re(h), v3=Im(h)
    vlseg2e64.v v0, (a1)      
    vlseg2e64.v v2, (a0)      

    # Aritmética: h = h + term * conj(x)
    # Re(h) = Re(h) + (term_re * Re(x) + term_im * Im(x))
    vfmacc.vf v2, fa0, v0
    vfmacc.vf v2, fa1, v1
    
    # Im(h) = Im(h) + (term_im * Re(x) - term_re * Im(x))
    vfmacc.vf v3, fa1, v0
    vfnmsac.vf v3, fa0, v1

    # Armazena os resultados atualizados
    vsseg2e64.v v2, (a0)

    # Incremento de ponteiros: (elementos * 2 doubles * 8 bytes) = t0 << 4
    slli t1, t0, 4            
    add a0, a0, t1            
    add a1, a1, t1
    sub a2, a2, t0
    bnez a2, loop_core

end_func:
    ret