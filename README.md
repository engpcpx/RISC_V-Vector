
### Descrição dos arquivos

- **`vec_add_rvv.s`**
  - Kernel em Assembly RVV
  - Implementa a soma vetorial:
    ```
    dst[i] = src1[i] + src2[i]
    ```

- **`main_vec_add.c`**
  - Código C intermediário
  - Inicializa vetores
  - Chama o kernel RVV
  - Imprime resultados e grava `rvv_output.txt`

- **`vec_add_benchmark.py`**
  - Benchmark funcional em Python
  - Implementa a soma vetorial em Python
  - Compara os resultados com os produzidos pelo RVV
  - Gera visualização gráfica

- **`run_rvv_benchmark.sh`**
  - Script Bash que automatiza todo o fluxo:
    - Compilação do Assembly RVV
    - Compilação do código C
    - Ligação (linkedição)
    - Execução via QEMU
    - Execução do benchmark em Python

- **`README.md`**
  - Documentação do projeto

---

## 3. Finalidade do Script `run_rvv_benchmark.sh`

O script Bash foi criado para:

- Eliminar a necessidade de digitar vários comandos no terminal
- Evitar erros comuns de compilação e execução
- Tornar o fluxo do projeto claro e organizado
- Automatizar todo o pipeline de desenvolvimento

O script executa, **em ordem**, as seguintes etapas:

1. Compilação do kernel Assembly RVV  
2. Compilação do código C intermediário  
3. Ligação dos arquivos objeto em um executável RISC-V  
4. Execução do programa RISC-V usando QEMU (em ambiente x86-64)  
5. Execução do benchmark funcional em Python  

Se qualquer etapa falhar, o script é interrompido e uma mensagem de erro é exibida.

---

## 4. Pré-requisitos

Antes de executar o projeto, certifique-se de que os seguintes componentes
estão instalados no sistema:

- **Compilador cruzado RISC-V**
