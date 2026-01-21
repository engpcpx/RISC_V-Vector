import numpy as np
import matplotlib.pyplot as plt

# ------------------------------------------------------------
# CONFIGURAÇÕES DO BENCHMARK
# ------------------------------------------------------------

N = 8  # Número de elementos (deve coincidir com o código C)

# ------------------------------------------------------------
# VETORES DE ENTRADA (MESMA LÓGICA DO C)
# ------------------------------------------------------------

a = np.arange(1, N + 1)
b = np.arange(1, N + 1) * 10

# ------------------------------------------------------------
# IMPLEMENTAÇÃO DE REFERÊNCIA EM PYTHON
# ------------------------------------------------------------

c_python = a + b

# ------------------------------------------------------------
# LEITURA DO RESULTADO PRODUZIDO PELO RVV
# ------------------------------------------------------------

c_rvv = []

with open("rvv_output.txt", "r") as f:
    for line in f:
        c_rvv.append(int(line.strip()))

c_rvv = np.array(c_rvv)

# ------------------------------------------------------------
# VERIFICAÇÃO MATEMÁTICA RIGOROSA
# ------------------------------------------------------------

assert np.array_equal(c_python, c_rvv), \
    "Erro: resultados do RVV e do Python não coincidem!"

print("Verificação funcional bem-sucedida: RVV == Python")

# ------------------------------------------------------------
# VISUALIZAÇÃO GRÁFICA
# ------------------------------------------------------------

plt.figure()
plt.plot(c_python, 'o-', label='Python')
plt.plot(c_rvv, 'x--', label='RVV')
plt.xlabel('Índice do vetor')
plt.ylabel('Valor')
plt.title('Benchmark Funcional: RVV vs Python')
plt.legend()
plt.grid(True)
plt.show()
