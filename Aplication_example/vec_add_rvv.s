###############################################################################
# Nome da função : vec_add_rvv
#
# Descrição:
#   Realiza a soma elemento a elemento de dois vetores de inteiros
#   utilizando a extensão vetorial do RISC-V (RVV).
#
#   O algoritmo é independente do comprimento físico do vetor
#   (vector-length agnostic). Em cada iteração, o hardware define
#   dinamicamente quantos elementos serão processados (VL).
#
# Protótipo em C:
#   void vec_add_rvv(int *dst, int *src1, int *src2, int n);
#
# Parâmetros (convenção de chamada RISC-V):
#   a0 : ponteiro para o vetor destino (dst)
#   a1 : ponteiro para o primeiro vetor de entrada (src1)
#   a2 : ponteiro para o segundo vetor de entrada (src2)
#   a3 : número total de elementos a processar (n)
#
# Registradores utilizados:
#   t0 : VL (número de elementos processados na iteração atual)
#   t1 : deslocamento em bytes (VL * sizeof(int))
#   v0 : registrador vetorial com elementos de src1
#   v1 : registrador vetorial com elementos de src2
#   v2 : registrador vetorial com o resultado da soma (v0 + v1)
#
###############################################################################

.globl vec_add_rvv
.type vec_add_rvv, @function

vec_add_rvv:
    ###########################################################################
    # Loop principal do algoritmo
    #
    # O loop é executado enquanto ainda existirem elementos a serem
    # processados. A cada iteração:
    #   1) Define-se o comprimento do vetor (VL)
    #   2) Carregam-se VL elementos dos vetores de entrada
    #   3) Executa-se a soma vetorial
    #   4) Armazenam-se os resultados
    #   5) Atualizam-se ponteiros e contador
    ###########################################################################

loop:
    ###########################################################################
    # Configuração da unidade vetorial
    #
    # A instrução vsetvli configura o comprimento do vetor (VL)
    # com base no número de elementos restantes (a3 = n).
    #
    # Parâmetros:
    #   e32 : elementos de 32 bits (int)
    #   m1  : uso de um grupo de registradores vetoriais
    #   ta  : tail agnostic (valores residuais não importam)
    #   ma  : mask agnostic
    #
    # O valor efetivo de VL é retornado no registrador t0.
    ###########################################################################
    vsetvli t0, a3, e32, m1, ta, ma

    ###########################################################################
    # Carregamento dos vetores de entrada
    #
    # São carregados VL elementos consecutivos da memória
    # para os registradores vetoriais.
    #
    # v0 <- src1[0 : VL-1]
    # v1 <- src2[0 : VL-1]
    ###########################################################################
    vle32.v v0, (a1)
    vle32.v v1, (a2)

    ###########################################################################
    # Operação vetorial
    #
    # Soma elemento a elemento dos vetores:
    #   v2[i] = v0[i] + v1[i], para i = 0 .. VL-1
    ###########################################################################
    vadd.vv v2, v0, v1

    ###########################################################################
    # Armazenamento do resultado
    #
    # Os VL elementos resultantes são escritos de volta
    # na memória apontada por dst.
    ###########################################################################
    vse32.v v2, (a0)

    ###########################################################################
    # Cálculo do deslocamento em bytes
    #
    # Cada inteiro ocupa 4 bytes.
    # Portanto: deslocamento = VL * 4.
    ###########################################################################
    slli t1, t0, 2        # t1 = VL * 4 bytes

    ###########################################################################
    # Atualização dos ponteiros
    #
    # Avança os ponteiros para a próxima posição não processada
    # dos vetores.
    ###########################################################################
    add  a0, a0, t1       # dst  += VL
    add  a1, a1, t1       # src1 += VL
    add  a2, a2, t1       # src2 += VL

    ###########################################################################
    # Atualização do contador de elementos restantes
    #
    # Após processar VL elementos, subtrai-se VL de n.
    ###########################################################################
    sub  a3, a3, t0       # n -= VL

    ###########################################################################
    # Controle do loop
    #
    # Se ainda existirem elementos a processar (n != 0),
    # o loop é repetido.
    ###########################################################################
    bnez a3, loop

    ###########################################################################
    # Retorno da função
    #
    # Todos os elementos foram processados com sucesso.
    ###########################################################################
    ret
