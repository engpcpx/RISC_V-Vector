# =========================================================================
# CMA MULTI-MODE LOOP - RISC-V VECTOR 1.0 (64-bit)
# =========================================================================
# Entrada:
#   a0: complex64_t *h      (ponteiro para h[N_MODES*N_MODES][N_TAPS])
#   a1: complex64_t *x      (ponteiro para x[N_TAPS][N_MODES])
#   a2: complex64_t *outEq  (ponteiro para outEq[N_MODES])
#   a3: double *R           (ponteiro para R[N_MODES])
#   a4: int nTaps           (número de coeficientes por filtro)
#   a5: int nModes          (número de modos)
#   fa0: double mu          (step size / passo de adaptação)
#
# Operação: Para cada par (m, n) de modos:
#           err = R[m] - |outEq[m]|²
#           term = mu * err * outEq[m]
#           h[m][n] += term * conj(x[n])
# =========================================================================

.section .text
.align 2
.globl vec_cma_multimode_loop_rvv

vec_cma_multimode_loop_rvv:
    # Salvamento de contexto
    addi sp, sp, -112
    sd ra, 0(sp)
    sd s0, 8(sp)   # h base
    sd s1, 16(sp)  # x base
    sd s2, 24(sp)  # outEq base
    sd s3, 32(sp)  # R base
    sd s4, 40(sp)  # nTaps
    sd s5, 48(sp)  # nModes
    sd s6, 56(sp)  # m
    sd s7, 64(sp)  # n
    sd s8, 72(sp)  # nTaps temp
    fsd fs0, 80(sp) # mu
    fsd fs1, 88(sp) # term_re
    fsd fs2, 96(sp) # term_im

    mv s0, a0
    mv s1, a1
    mv s2, a2
    mv s3, a3
    mv s4, a4      # nTaps
    mv s5, a5      # nModes
    fmv.d fs0, fa0 # mu

    li s6, 0       # m = 0
.Louter_m_loop:
    bge s6, s5, .Ldone_multimode
    
    # Cálculo do Erro
    slli t0, s6, 4       
    add t1, s2, t0       
    fld fa1, 0(t1)       # outEq[m].re
    fld fa2, 8(t1)       # outEq[m].im
    slli t0, s6, 3       
    add t1, s3, t0       
    fld fa3, 0(t1)       # R[m]
    
    fmul.d ft0, fa1, fa1
    fmadd.d ft0, fa2, fa2, ft0 
    fsub.d ft1, fa3, ft0        
    
    fmul.d fs1, ft1, fa1        
    fmul.d fs2, ft1, fa2        
    fmul.d fs1, fs1, fs0        
    fmul.d fs2, fs2, fs0        

    li s7, 0                    # n = 0
.Linner_n_loop:
    bge s7, s5, .Lnext_m_loop
    
    # Cálculo de endereços para H[m][n] e X[n]
    mul t3, s7, s5
    add t3, t3, s6
    mul t4, t3, s4       
    slli t4, t4, 4       
    add t0, s0, t4       # t0 = h_ptr

    slli t5, s7, 4       
    add t1, s1, t5       # t1 = x_ptr
    
    mv s8, s4            # contador de taps
    slli t2, s5, 4       # x_stride

.Lloop_vector_core: # NÚCLEO INLINED (Antigo process_taps)
    vsetvli t3, s8, e64, m1, ta, ma
    vlsseg2e64.v v0, (t1), t2   # Carga X com stride
    vlseg2e64.v v2, (t0)        # Carga H contígua
    
    vfmacc.vf v2, fs1, v0       
    vfmacc.vf v2, fs2, v1       
    vfmacc.vf v3, fs2, v0       
    vfnmsac.vf v3, fs1, v1      
    
    vsseg2e64.v v2, (t0)
    
    sub s8, s8, t3
    slli t4, t3, 4              
    add t0, t0, t4
    mul t4, t3, t2              
    add t1, t1, t4
    bnez s8, .Lloop_vector_core

    addi s7, s7, 1
    j .Linner_n_loop

.Lnext_m_loop:
    addi s6, s6, 1
    j .Louter_m_loop

.Ldone_multimode:
    ld ra, 0(sp)
    ld s0, 8(sp)
    ld s1, 16(sp)
    ld s2, 24(sp)
    ld s3, 32(sp)
    ld s4, 40(sp)
    ld s5, 48(sp)
    ld s6, 56(sp)
    ld s7, 64(sp)
    ld s8, 72(sp)
    fld fs0, 80(sp)
    fld fs1, 88(sp)
    fld fs2, 96(sp)
    addi sp, sp, 112
    ret