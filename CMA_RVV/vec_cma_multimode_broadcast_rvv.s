# =========================================================================
# CMA MULTI-MODE BROADCAST - RISC-V VECTOR 1.0 (64-bit) LMUL=4
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
# Operação: Versão otimizada com LMUL=4 para maior throughput vetorial
#           Para cada par (m, n) de modos:
#           err = R[m] - |outEq[m]|²
#           term = mu * err * outEq[m] (broadcast em registradores vetoriais)
#           h[m][n] += term * conj(x[n])
# =========================================================================

.section .text
.align 2
.globl vec_cma_multimode_broadcast_rvv

vec_cma_multimode_broadcast_rvv:
    # Salvamento de contexto (Standard ABI 64-bit)
    addi sp, sp, -112
    sd ra, 0(sp); sd s0, 8(sp); sd s1, 16(sp); sd s2, 24(sp)
    sd s3, 32(sp); sd s4, 40(sp); sd s5, 48(sp); sd s6, 56(sp)
    sd s7, 64(sp); sd s8, 72(sp)
    fsd fs0, 80(sp); fsd fs1, 88(sp); fsd fs2, 96(sp)

    # Mapeamento de Argumentos
    mv s0, a0        # Base H
    mv s1, a1        # Base X
    mv s2, a2        # Base outEq
    mv s3, a3        # Base R
    mv s4, a4        # nTaps
    mv s5, a5        # nModes
    fmv.d fs0, fa0   # mu (Step size)

    li s6, 0         # m = 0 (Loop modo receptor)
.Louter_m_loop:
    bge s6, s5, .Ldone_all
    
    # --- CÁLCULO DO ERRO (MODO m) ---
    slli t0, s6, 4       
    add t1, s2, t0       
    fld fa1, 0(t1)       # outEq[m].re
    fld fa2, 8(t1)       # outEq[m].im
    slli t0, s6, 3       
    add t1, s3, t0       
    fld fa3, 0(t1)       # R[m]
    
    fmul.d ft0, fa1, fa1
    fmadd.d ft0, fa2, fa2, ft0 
    fsub.d ft1, fa3, ft0 # err = R - |outEq|^2
    
    # Termos de atualização (Broadcast Scaler)
    fmul.d fs1, ft1, fa1 
    fmul.d fs2, ft1, fa2 
    fmul.d fs1, fs1, fs0 # fs1 = mu * err * outEq.re
    fmul.d fs2, fs2, fs0 # fs2 = mu * err * outEq.im

    li s7, 0             # n = 0 (Loop modo transmissor)
.Linner_n_loop:
    bge s7, s5, .Lnext_m
    
    # --- CÁLCULO DE ENDEREÇOS ---
    mul t3, s7, s5
    add t3, t3, s6
    mul t4, t3, s4
    slli t4, t4, 4
    add t0, s0, t4       # t0 = h_ptr (H[m][n])

    slli t5, s7, 4
    add t1, s1, t5       # t1 = x_ptr (X[n])
    
    mv s8, s4            # s8 = nTaps_restantes
    slli t2, s5, 4       # t2 = Stride de X (nModes * 16 bytes)

.Lvector_core_m4:
    # --- NÚCLEO VETORIAL LMUL=4 ---
    # Com LMUL=4 e Double Precision (e64), usamos grupos de 4 registros:
    # v0, v4 para X (Re/Im) e v8, v12 para H (Re/Im)
    vsetvli t3, s8, e64, m4, ta, ma
    
    vlsseg2e64.v v0, (t1), t2   # Carga X[n] (Stride)
    vlseg2e64.v v8, (t0)        # Carga H[m][n] (Contíguo)
    
    # Aritmética: h = h + term * conj(x)
    # Re(h) = Re(h) + (term_re * Re(x) + term_im * Im(x))
    vfmacc.vf v8, fs1, v0       
    vfmacc.vf v8, fs2, v4       
    
    # Im(h) = Im(h) + (term_im * Re(x) - term_re * Im(x))
    vfmacc.vf v12, fs2, v0      
    vfnmsac.vf v12, fs1, v4     
    
    vsseg2e64.v v8, (t0)        # Store H atualizado
    
    # Atualização de ponteiros e contadores
    sub s8, s8, t3
    slli t4, t3, 4              # t4 = offset contíguo
    add t0, t0, t4              
    mul t4, t3, t2              # t4 = offset stride
    add t1, t1, t4              
    bnez s8, .Lvector_core_m4

    addi s7, s7, 1
    j .Linner_n_loop

.Lnext_m:
    addi s6, s6, 1
    j .Louter_m_loop

.Ldone_all:
    # Restauração de contexto
    ld ra, 0(sp); ld s0, 8(sp); ld s1, 16(sp); ld s2, 24(sp); ld s3, 32(sp)
    ld s4, 40(sp); ld s5, 48(sp); ld s6, 56(sp); ld s7, 64(sp); ld s8, 72(sp)
    fld fs0, 80(sp); fld fs1, 88(sp); fld fs2, 96(sp)
    addi sp, sp, 112
    ret