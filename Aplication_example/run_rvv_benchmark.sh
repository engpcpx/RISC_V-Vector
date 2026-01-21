#!/bin/bash
# ============================================================
# Script: run_rvv_benchmark.sh
# Descrição:
#   Automatiza o fluxo completo do projeto de soma vetorial
#   usando RVV (RISC-V Vector Extension).
#
# Etapas:
#   1. Compilação do kernel Assembly RVV
#   2. Compilação do código C intermediário
#   3. Ligação (link) dos arquivos objeto
#   4. Execução via QEMU (ambiente x86-64)
#   5. Execução do benchmark funcional em Python
#
# Autor: (seu nome)
# ============================================================

# ------------------------------------------------------------
# CONFIGURAÇÕES GERAIS
# ------------------------------------------------------------

# Compilador cruzado RISC-V
RISCV_GCC="riscv64-unknown-linux-gnu-gcc"

# Arquitetura e ABI alvo
ARCH_FLAGS="-march=rv64gcv -mabi=lp64d"

# Emulador RISC-V em modo usuário
QEMU_CMD="qemu-riscv64"
QEMU_LIB_PATH="/usr/riscv64-linux-gnu"

# Nomes dos arquivos
ASM_SRC="vec_add_rvv.s"
C_SRC="main_vec_add.c"

ASM_OBJ="vec_add_rvv.o"
C_OBJ="main_vec_add.o"

EXECUTABLE="vec_add_rvv_exec"
PYTHON_BENCH="vec_add_benchmark.py"

# ------------------------------------------------------------
# ETAPA 1: COMPILAÇÃO DO KERNEL ASSEMBLY RVV
# ------------------------------------------------------------

echo "=== [1/5] Compilando kernel Assembly RVV ==="

$RISCV_GCC $ARCH_FLAGS -c $ASM_SRC -o $ASM_OBJ
if [ $? -ne 0 ]; then
    echo "Erro na compilação do Assembly RVV"
    exit 1
fi

# ------------------------------------------------------------
# ETAPA 2: COMPILAÇÃO DO CÓDIGO C INTERMEDIÁRIO
# ------------------------------------------------------------

echo "=== [2/5] Compilando código C intermediário ==="

$RISCV_GCC $ARCH_FLAGS -c $C_SRC -o $C_OBJ
if [ $? -ne 0 ]; then
    echo "Erro na compilação do código C"
    exit 1
fi

# ------------------------------------------------------------
# ETAPA 3: LIGAÇÃO DOS ARQUIVOS OBJETO
# ------------------------------------------------------------

echo "=== [3/5] Ligando objetos e gerando executável RISC-V ==="

$RISCV_GCC $ARCH_FLAGS $C_OBJ $ASM_OBJ -o $EXECUTABLE
if [ $? -ne 0 ]; then
    echo "Erro na etapa de linkedição"
    exit 1
fi

# ------------------------------------------------------------
# ETAPA 4: EXECUÇÃO DO PROGRAMA VIA QEMU
# ------------------------------------------------------------

echo "=== [4/5] Executando programa RISC-V via QEMU ==="

$QEMU_CMD -L $QEMU_LIB_PATH ./$EXECUTABLE
if [ $? -ne 0 ]; then
    echo "Erro durante a execução via QEMU"
    exit 1
fi

# ------------------------------------------------------------
# ETAPA 5: BENCHMARK FUNCIONAL EM PYTHON
# ------------------------------------------------------------

echo "=== [5/5] Executando benchmark funcional em Python ==="

python3 $PYTHON_BENCH
if [ $? -ne 0 ]; then
    echo "Erro no benchmark em Python"
    exit 1
fi

# ------------------------------------------------------------
# FINALIZAÇÃO
# ------------------------------------------------------------

echo "=== Fluxo completo executado com sucesso ==="
