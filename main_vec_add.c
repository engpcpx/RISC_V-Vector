#include <stdio.h>
#include <stdlib.h>

extern void vec_add_rvv(int *dst, int *src1, int *src2, int n);

#define N 8

int main(void) {
    int a[N] = {1,2,3,4,5,6,7,8};
    int b[N] = {10,20,30,40,50,60,70,80};
    int c[N];

    // Chamada do kernel RVV
    vec_add_rvv(c, a, b, N);

    // Impressão no terminal (didática)
    printf("Resultado da soma vetorial (RVV):\n");
    for (int i = 0; i < N; i++) {
        printf("%d + %d = %d\n", a[i], b[i], c[i]);
    }

    // Escrita do resultado em arquivo (para o benchmark em Python)
    FILE *f = fopen("rvv_output.txt", "w");
    if (!f) {
        perror("Erro ao criar rvv_output.txt");
        return 1;
    }

    for (int i = 0; i < N; i++) {
        fprintf(f, "%d\n", c[i]);
    }

    fclose(f);

    return 0;
}
