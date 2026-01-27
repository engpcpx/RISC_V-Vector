#!/bin/bash
# =====================================================
# run_cma_multimode_benchmark.sh 
# =====================================================

RISCV_GCC="riscv64-unknown-linux-gnu-gcc"
ARCH_FLAGS="-march=rv64gcv -mabi=lp64d"
QEMU_CMD="qemu-riscv64"
QEMU_LIB_PATH="/usr/riscv64-linux-gnu"

echo "=== COMPILAÇÃO MULTI-MODE CMA COM RVV ==="
echo "1. Verificando arquivos..."

ls -lh vec_cma_singlemode_loop_rvv.s vec_cma_singlemode_broadcast_rvv.s \
       vec_cma_multimode_loop_rvv.s vec_cma_multimode_broadcast_rvv.s \
       main_vec_cma_benchmark.c

echo ""
echo "2. Compilando..."
$RISCV_GCC $ARCH_FLAGS \
    -O2 \
    vec_cma_singlemode_loop_rvv.s \
    vec_cma_singlemode_broadcast_rvv.s \
    vec_cma_multimode_loop_rvv.s \
    vec_cma_multimode_broadcast_rvv.s \
    main_vec_cma_benchmark.c \
    -o cma_multimode_exec \
    -lm

if [ $? -ne 0 ]; then
    echo "ERRO na compilação!"
    exit 1
fi

echo ""
echo "3. Verificando símbolos no executável..."
riscv64-unknown-linux-gnu-nm cma_multimode_exec | grep "vec_cma"

echo ""
echo "4. Executando no QEMU..."
$QEMU_CMD -L $QEMU_LIB_PATH ./cma_multimode_exec

echo ""
echo "5. Verificando arquivos gerados..."
ls -lh cma_*.txt

echo ""
echo "--- Validando Resultados com Python ---"
python3 vec_cma_benchmark.py