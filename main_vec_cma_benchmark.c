// =====================================================
// main_vec_cma_benchmark.c 
// =====================================================
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <math.h> 

#define N_ITER_BENCH 10000

// Definição de PI para Box-Muller caso não esteja disponível no ambiente
#ifndef M_PI
    #define M_PI 3.14159265358979323846
#endif

typedef struct { 
    double re; 
    double im; 
} complex64_t;

// --- Protótipos das Funções Assembly RVV ---
extern void vec_cma_singlemode_loop_rvv(complex64_t *h, complex64_t *x, int nTaps, double mu_re, double mu_im);
extern void vec_cma_singlemode_broadcast_rvv(complex64_t *h, complex64_t *x, int nTaps, double mu_re, double mu_im);
extern void vec_cma_multimode_loop_rvv(complex64_t *h, complex64_t *x, complex64_t *outEq, double *R, int nTaps, int nModes, double mu);
extern void vec_cma_multimode_broadcast_rvv(complex64_t *h, complex64_t *x, complex64_t *outEq, double *R, int nTaps, int nModes, double mu);

// --- Parameters ---
#define N_TAPS 16
#define N_MODES 4
#define MU 1e-4
#define R_CMA 1.0

// --- Gerador Gaussiano (Box-Muller) para Requisitos CV-QKD ---
// Transforma distribuição uniforme em Gaussiana complexa com desvio padrão sigma
void generate_gaussian_complex(complex64_t *val, double sigma) {
    double u1 = (double)rand() / RAND_MAX;
    double u2 = (double)rand() / RAND_MAX;
    
    // Proteção contra log(0)
    if(u1 < 1e-12) u1 = 1e-12; 

    double mag = sigma * sqrt(-2.0 * log(u1));
    val->re = mag * cos(2.0 * M_PI * u2);
    val->im = mag * sin(2.0 * M_PI * u2);
}

// --- Função auxiliar para cálculo de tempo ---
double get_time_diff(struct timespec start, struct timespec end) {
    return (end.tv_sec - start.tv_sec) + (end.tv_nsec - start.tv_nsec) / 1e9;
}

// --- Funções de Salvamento ---
void save_multimode_res(const char *name, complex64_t *h, int nModes, int nTaps) {
    FILE *f = fopen(name, "w");
    if (!f) return;
    for(int idx = 0; idx < nModes * nModes; idx++) {
        for(int tap = 0; tap < nTaps; tap++) {
            int pos = idx * nTaps + tap;
            fprintf(f, "%.18f %.18f\n", h[pos].re, h[pos].im);
        }
    }
    fclose(f);
}

void save_singlemode_res(const char *name, complex64_t *h, int count) {
    FILE *f = fopen(name, "w");
    if (!f) return;
    for(int i = 0; i < count; i++) {
        fprintf(f, "%.18f %.18f\n", h[i].re, h[i].im);
    }
    fclose(f);
}

int main() {
    system("mkdir -p data");

    struct timespec start, end;
    int h_size_single = N_TAPS;
    int h_size_multi = N_MODES * N_MODES * N_TAPS;

    // --- Alocação ---
    complex64_t *x_single = (complex64_t *)malloc(N_TAPS * sizeof(complex64_t));
    complex64_t *h_loop_single = (complex64_t *)calloc(h_size_single, sizeof(complex64_t));
    complex64_t *h_broad_single = (complex64_t *)calloc(h_size_single, sizeof(complex64_t));
    complex64_t *h_bench = (complex64_t *)malloc(h_size_multi * sizeof(complex64_t)); 

    // --- Inicialização Single-Mode (Linear para debug básico) ---
    for(int i = 0; i < N_TAPS; i++) {
        x_single[i].re = 1.0 + (i * 0.02);
        x_single[i].im = 0.5 - (i * 0.01);
    }
    double t_re = 0.0000162, t_im = 0.0000018;

    // --- SINGLE-MODE BENCHMARK ---
    clock_gettime(CLOCK_MONOTONIC, &start);
    for(int i=0; i<N_ITER_BENCH; i++) vec_cma_singlemode_loop_rvv(h_bench, x_single, N_TAPS, t_re, t_im);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_single_loop = get_time_diff(start, end);

    clock_gettime(CLOCK_MONOTONIC, &start);
    for(int i=0; i<N_ITER_BENCH; i++) vec_cma_singlemode_broadcast_rvv(h_bench, x_single, N_TAPS, t_re, t_im);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_single_broad = get_time_diff(start, end);

    vec_cma_singlemode_loop_rvv(h_loop_single, x_single, N_TAPS, t_re, t_im);
    vec_cma_singlemode_broadcast_rvv(h_broad_single, x_single, N_TAPS, t_re, t_im);

    // --- MULTI-MODE PREPARATION (Com Dados Gaussianos) ---
    complex64_t *x_multi = (complex64_t *)malloc(N_TAPS * N_MODES * sizeof(complex64_t));
    complex64_t *h_loop_multi = (complex64_t *)calloc(h_size_multi, sizeof(complex64_t));
    complex64_t *h_broad_multi = (complex64_t *)calloc(h_size_multi, sizeof(complex64_t));
    complex64_t *outEq = (complex64_t *)malloc(N_MODES * sizeof(complex64_t));
    double *R = (double *)malloc(N_MODES * sizeof(double));

    srand(42); 

    // Implementação estrita: Dados agora seguem distribuição normal sigma=1.0
    for(int i = 0; i < N_TAPS * N_MODES; i++) {
        generate_gaussian_complex(&x_multi[i], 1.0); 
    }
    for(int m = 0; m < N_MODES; m++) {
        generate_gaussian_complex(&outEq[m], 1.0);
        R[m] = R_CMA;
    }

    // --- EXPORTAÇÃO DE INPUTS ---
    FILE *f_input = fopen("data/cma_multimode_input.txt", "w");
    if (f_input) {
        for(int tap = 0; tap < N_TAPS; tap++) {
            for(int mode = 0; mode < N_MODES; mode++) {
                int pos = tap * N_MODES + mode;
                fprintf(f_input, "%.18f %.18f\n", x_multi[pos].re, x_multi[pos].im);
            }
        }
        fclose(f_input);
    }

    FILE *f_outeq = fopen("data/cma_multimode_outeq.txt", "w");
    if (f_outeq) {
        for(int m = 0; m < N_MODES; m++) {
            fprintf(f_outeq, "%.18f %.18f\n", outEq[m].re, outEq[m].im);
        }
        fclose(f_outeq);
    }

    // --- BENCHMARK MULTI MODE ---
    clock_gettime(CLOCK_MONOTONIC, &start);
    for(int i=0; i<N_ITER_BENCH; i++) vec_cma_multimode_loop_rvv(h_bench, x_multi, outEq, R, N_TAPS, N_MODES, MU);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_multi_loop = get_time_diff(start, end);

    clock_gettime(CLOCK_MONOTONIC, &start);
    for(int i=0; i<N_ITER_BENCH; i++) vec_cma_multimode_broadcast_rvv(h_bench, x_multi, outEq, R, N_TAPS, N_MODES, MU);
    clock_gettime(CLOCK_MONOTONIC, &end);
    double time_multi_broad = get_time_diff(start, end);

    vec_cma_multimode_loop_rvv(h_loop_multi, x_multi, outEq, R, N_TAPS, N_MODES, MU);
    vec_cma_multimode_broadcast_rvv(h_broad_multi, x_multi, outEq, R, N_TAPS, N_MODES, MU);

    // --- SALVAMENTO E FINALIZAÇÃO ---
    save_singlemode_res("data/cma_singlemode_loop_output.txt", h_loop_single, N_TAPS);
    save_singlemode_res("data/cma_singlemode_broadcast_output.txt", h_broad_single, N_TAPS);
    save_multimode_res("data/cma_multimode_loop_output.txt", h_loop_multi, N_MODES, N_TAPS);
    save_multimode_res("data/cma_multimode_broadcast_output.txt", h_broad_multi, N_MODES, N_TAPS);

    FILE *f_time = fopen("data/cma_timing.txt", "w");
    if (f_time) {
        fprintf(f_time, "%.10f\n%.10f\n%.10f\n%.10f\n%d\n", 
                time_single_loop, time_single_broad,
                time_multi_loop, time_multi_broad, N_ITER_BENCH);
        fclose(f_time);
    }

    free(x_single); free(h_loop_single); free(h_broad_single);
    free(x_multi); free(h_loop_multi); free(h_broad_multi);
    free(h_bench); free(outEq); free(R);

    printf("Benchmark com Estatística Gaussiana concluído com sucesso.\n");
    return 0;
}