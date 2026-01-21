import matplotlib.pyplot as plt

# ------------------------------------------------------------
# CONFIGURAÇÕES DO BENCHMARK
# ------------------------------------------------------------

N = 8  # Número de elementos (deve coincidir com o código C)

# ------------------------------------------------------------
# VETORES DE ENTRADA (MESMA LÓGICA DO C)
# ------------------------------------------------------------

# a = [1, 2, 3, ..., N]
a = [i for i in range(1, N + 1)]

# b = [10, 20, 30, ..., 10*N]
b = [i * 10 for i in range(1, N + 1)]

# ------------------------------------------------------------
# IMPLEMENTAÇÃO DE REFERÊNCIA EM PYTHON (ESCALAR)
# ------------------------------------------------------------

c_python = []
for i in range(N):
    c_python.append(a[i] + b[i])

# ------------------------------------------------------------
# LEITURA DO RESULTADO PRODUZIDO PELO RVV
# ------------------------------------------------------------

c_rvv = []
with open("rvv_output.txt", "r") as f:
    for line in f:
        c_rvv.append(int(line.strip()))

# ------------------------------------------------------------
# VERIFICAÇÃO MATEMÁTICA RIGOROSA
# ------------------------------------------------------------

assert len(c_python) == len(c_rvv), \
    "Erro: tamanhos dos vetores não coincidem!"

for i in range(N):
    assert c_python[i] == c_rvv[i], \
        f"Erro no índice {i}: Python={c_python[i]}, RVV={c_rvv[i]}"

print("Verificação funcional bem-sucedida: RVV == Python")

# ------------------------------------------------------------
# VISUALIZAÇÃO GRÁFICA
# ------------------------------------------------------------

indices = list(range(N))

plt.figure()
plt.plot(indices, c_python, 'o-', label='Python')
plt.plot(indices, c_rvv, 'x--', label='RVV')
plt.xlabel('Índice do vetor')
plt.ylabel('Valor')
plt.title('Benchmark Funcional: RVV vs Python (sem NumPy)')
plt.legend()
plt.grid(True)
plt.show()
