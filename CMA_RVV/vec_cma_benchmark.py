# =====================================================
# vec_cma_benchmark.py
# =====================================================

import numpy as np
import matplotlib.pyplot as plt
from matplotlib.gridspec import GridSpec
import os

# =====================================================
# CONFIGURAÇÕES E DIRETÓRIOS
# =====================================================
N_TAPS = 16
N_MODES = 4
MU = 1e-4
R_CMA = 1.0
DATA_DIR = "data"

# Garante a existência da pasta para o salvamento do PNG e leitura dos dados
if not os.path.exists(DATA_DIR):
    os.makedirs(DATA_DIR)

plt.rcParams.update({
    "font.family": "serif",
    "font.size": 10,
    "axes.grid": True,
    "grid.linestyle": ":",
    "grid.alpha": 0.8
})

# =====================================================
# FUNÇÕES PYTHON PURO (Multi-Mode CMA)
# =====================================================
def cma_original_pure(x, R, outEq, mu, H_in, nModes):
    """Implementação original do CMA - versão simplificada"""
    nTaps = x.shape[0]
    h_list = H_in.tolist()
    out_list = [complex(outEq[i, 0]) for i in range(nModes)]
    r_list = [float(R[0, i]) for i in range(nModes)]
    x_list = x.tolist()
    
    err = [
        r_list[i] - (out_list[i].real ** 2 + out_list[i].imag ** 2)
        for i in range(nModes)
    ]
    prod = [err[i] * out_list[i] for i in range(nModes)]
    
    for N in range(nModes):
        for m in range(nModes):
            idx = m + N * nModes
            for tap in range(nTaps):
                val_x = complex(x_list[tap][N])
                h_list[idx][tap] += mu * prod[m] * val_x.conjugate()
    
    return np.array(h_list)

def cma_vector_broadcast_pure(x, R, outEq, mu, H_in, nModes):
    """Implementação vetorizada com broadcast do CMA"""
    nTaps = x.shape[0]
    h_list = H_in.tolist()
    
    for m in range(nModes):
        err_m = float(R[0, m]) - abs(complex(outEq[m, 0])) ** 2
        term = mu * err_m * complex(outEq[m, 0])
        
        for n in range(nModes):
            idx = m + n * nModes
            for tap in range(nTaps):
                x_val = complex(x[tap, n])
                h_list[idx][tap] += term * x_val.conjugate()
    
    return np.array(h_list)

# =====================================================
# REFERÊNCIA PYTHON (Single Mode - para RVV)
# =====================================================
def get_theoretical_reference():
    """Calcula referência para o teste single-mode RVV"""
    x = np.array([complex(1.0 + i * 0.02, 0.5 - i * 0.01) for i in range(N_TAPS)])
    out_eq = complex(0.9, 0.1)
    
    mag_sq = abs(out_eq)**2
    error = R_CMA - mag_sq
    term = MU * error * out_eq
    
    return term * np.conj(x)

# =====================================================
# CARREGAMENTO DE DADOS
# =====================================================
def load_rvv_singlemode(filename):
    """Carrega dados single-mode do RVV da subpasta data"""
    path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(path):
        print(f"⚠ Arquivo {path} não encontrado!")
        return np.zeros(N_TAPS, dtype=complex)
    
    try:
        data = np.loadtxt(path)
        return data[:N_TAPS, 0] + 1j * data[:N_TAPS, 1]
    except Exception as e:
        print(f"✗ Erro ao ler {path}: {e}")
        return np.zeros(N_TAPS, dtype=complex)

def load_rvv_multimode(filename):
    """Carrega dados multi-mode do RVV da subpasta data"""
    path = os.path.join(DATA_DIR, filename)
    if not os.path.exists(path):
        print(f"Arquivo {path} não encontrado!")
        return np.zeros((N_MODES * N_MODES, N_TAPS), dtype=complex)
    
    try:
        data = np.loadtxt(path)
        h = np.zeros((N_MODES * N_MODES, N_TAPS), dtype=complex)
        for idx in range(N_MODES * N_MODES):
            start = idx * N_TAPS
            end = start + N_TAPS
            h[idx] = data[start:end, 0] + 1j * data[start:end, 1]
        return h
    except Exception as e:
        print(f"Erro ao ler {path}: {e}")
        return np.zeros((N_MODES * N_MODES, N_TAPS), dtype=complex)

def load_multimode_inputs():
    """Carrega dados de entrada gerados pelo C na subpasta data"""
    try:
        x_path = os.path.join(DATA_DIR, "cma_multimode_input.txt")
        outeq_path = os.path.join(DATA_DIR, "cma_multimode_outeq.txt")
        
        x_data = np.loadtxt(x_path)
        x = np.zeros((N_TAPS, N_MODES), dtype=complex)
        for tap in range(N_TAPS):
            for mode in range(N_MODES):
                idx = tap * N_MODES + mode
                x[tap, mode] = x_data[idx, 0] + 1j * x_data[idx, 1]
        
        outeq_data = np.loadtxt(outeq_path)
        outEq = np.zeros((N_MODES, 1), dtype=complex)
        for m in range(N_MODES):
            outEq[m, 0] = outeq_data[m, 0] + 1j * outeq_data[m, 1]
        
        R = np.ones((1, N_MODES)) * R_CMA
        
        return x, R, outEq
    except Exception as e:
        print(f"Erro ao carregar inputs: {e}")
        return None, None, None

# =====================================================
# GERAÇÃO DO RELATÓRIO COMPLETO
# =====================================================
def generate_full_report():
    """Gera relatório completo comparando Python e RVV"""
    
    print(f"\n{'='*60}")
    print(f"BENCHMARK CMA: PYTHON vs RVV (Pasta: {DATA_DIR})")
    print(f"{'='*60}\n")
    
    # --- PARTE 1: SINGLE-MODE ---
    print("=== SINGLE-MODE VALIDATION ===")
    h_ref_single = get_theoretical_reference()
    h_loop_single = load_rvv_singlemode("cma_singlemode_loop_output.txt")
    h_broad_single = load_rvv_singlemode("cma_singlemode_broadcast_output.txt")
    
    err_single_loop = np.abs(h_loop_single - h_ref_single)
    err_single_broad = np.abs(h_broad_single - h_ref_single)
    
    print(f"RVV Loop  → Max error: {err_single_loop.max():.2e} | Mean: {err_single_loop.mean():.2e}")
    print(f"RVV Broad → Max error: {err_single_broad.max():.2e} | Mean: {err_single_broad.mean():.2e}")
    
    # --- PARTE 2: MULTI-MODE ---
    print(f"\n{'='*60}")
    print(f"=== MULTI-MODE VALIDATION (N_MODES={N_MODES}, N_TAPS={N_TAPS}) ===")
    
    x, R, outEq = load_multimode_inputs()
    
    if x is not None:
        H_in = np.zeros((N_MODES * N_MODES, N_TAPS), dtype=complex)
        H_py_orig = cma_original_pure(x, R, outEq, MU, H_in.copy(), N_MODES)
        H_py_broad = cma_vector_broadcast_pure(x, R, outEq, MU, H_in.copy(), N_MODES)
        
        diff_py = np.abs(H_py_orig - H_py_broad)
        print(f"\nPython Original vs Broadcast:")
        print(f"Max diff: {diff_py.max():.2e} | Mean: {diff_py.mean():.2e}")
        
        H_rvv_loop = load_rvv_multimode("cma_multimode_loop_output.txt")
        H_rvv_broad = load_rvv_multimode("cma_multimode_broadcast_output.txt")
        
        err_loop_vs_py = np.abs(H_rvv_loop - H_py_orig)
        err_broad_vs_py = np.abs(H_rvv_broad - H_py_broad)
        
        print(f"\nRVV Loop vs Python Original:")
        print(f"Max error: {err_loop_vs_py.max():.2e} | Mean: {err_loop_vs_py.mean():.2e}")
        print(f"\nRVV Broadcast vs Python Broadcast:")
        print(f"Max error: {err_broad_vs_py.max():.2e} | Mean: {err_broad_vs_py.mean():.2e}")
    else:
        print("Não foi possível carregar inputs multi-mode")
        H_py_orig = H_py_broad = H_rvv_loop = H_rvv_broad = None
    
    print(f"{'='*60}\n")
    
    # =====================================================
    # GRÁFICOS
    # =====================================================
    fig = plt.figure(figsize=(16, 14))
    gs = GridSpec(4, 2, height_ratios=[1, 1, 1, 0.85], hspace=0.45, wspace=0.3, 
                  top=0.92, bottom=0.06, left=0.08, right=0.96)
    fig.suptitle("CMA Benchmark: RVV Validation & Python Multi-Mode Comparison", 
                 fontsize=14, fontweight="bold")

    # Estilos de plotagem (Ajustados para evitar conflito de 'label')
    kw_ref = dict(color='black', lw=1.5)
    kw_loop = dict(marker='o', ls='', mfc='none', mec='blue', ms=6) 
    kw_broad = dict(marker='x', ls='', color='red', ms=6)

    # ROW 1 & 2: SINGLE-MODE VALIDATION
    ax = fig.add_subplot(gs[0, 0])
    ax.plot(h_ref_single.real, label='Python Ref', **kw_ref)
    ax.plot(h_loop_single.real, label='RVV Loop', **kw_loop)
    ax.set_title("Single-Mode: Real Part — Loop"); ax.set_xlabel("Tap Index"); ax.legend()

    ax = fig.add_subplot(gs[0, 1])
    ax.plot(h_ref_single.real, label='Python Ref', **kw_ref)
    ax.plot(h_broad_single.real, label='RVV Broadcast', **kw_broad)
    ax.set_title("Single-Mode: Real Part — Broadcast"); ax.set_xlabel("Tap Index"); ax.legend()

    ax = fig.add_subplot(gs[1, 0])
    ax.plot(h_ref_single.imag, label='Python Ref', **kw_ref)
    ax.plot(h_loop_single.imag, label='RVV Loop', **kw_loop)
    ax.set_title("Single-Mode: Imaginary Part — Loop"); ax.set_xlabel("Tap Index"); ax.legend()

    ax = fig.add_subplot(gs[1, 1])
    ax.plot(h_ref_single.imag, label='Python Ref', **kw_ref)
    ax.plot(h_broad_single.imag, label='RVV Broadcast', **kw_broad)
    ax.set_title("Single-Mode: Imaginary Part — Broadcast"); ax.set_xlabel("Tap Index"); ax.legend()

    # ROW 3: MULTI-MODE COMPARISON
    if H_py_orig is not None and H_rvv_loop is not None:
        ax = fig.add_subplot(gs[2, 0])
        ax.plot(H_py_orig[0].real, label='Python Original', **kw_ref)
        ax.plot(H_rvv_loop[0].real, label='RVV Loop', **kw_loop)
        ax.set_title(f"Multi-Mode Loop: H[0] Real (N_MODES={N_MODES})"); ax.set_xlabel("Tap Index"); ax.legend()

        ax = fig.add_subplot(gs[2, 1])
        ax.plot(H_py_broad[0].imag, label='Python Broadcast', **kw_ref)
        ax.plot(H_rvv_broad[0].imag, label='RVV Broadcast', **kw_broad)
        ax.set_title(f"Multi-Mode Broadcast: H[0] Imag (N_MODES={N_MODES})"); ax.set_xlabel("Tap Index"); ax.legend()
    else:
        for col in [0, 1]:
            ax = fig.add_subplot(gs[2, col])
            ax.text(0.5, 0.5, "Multi-mode data unavailable", ha='center', va='center', transform=ax.transAxes)

    # ROW 4: PERFORMANCE COMPARISON (INTEGRIDADE TOTAL PRESERVADA)
    ax_perf = fig.add_subplot(gs[3, :])
    ax_perf.grid(False)
    ax_perf.set_xlim(0, 1.0); ax_perf.set_ylim(-0.6, 3.6)

    timing_path = os.path.join(DATA_DIR, "cma_timing.txt")
    if os.path.exists(timing_path):
        try:
            timing_raw = np.loadtxt(timing_path)
            if timing_raw.size >= 4:
                n_iters = int(timing_raw[4]) if timing_raw.size > 4 else 1
                times_us = (timing_raw[:4] / n_iters) * 1e6
                max_time = times_us.max()
                
                bars = ax_perf.barh(
                    ["Single Loop", "Single Broadcast", "Multi Loop", "Multi Broadcast"],
                    [(t / max_time) * 0.55 for t in times_us],
                    color="#7f7f7f", height=0.4, alpha=0.8
                )

                def format_label(t_us):
                    return f"{t_us*1000:.1f} ns" if t_us < 1.0 else f"{t_us:.2f} µs"
                labels = [format_label(t) for t in times_us]
                ax_perf.bar_label(bars, labels=labels, padding=12, fontsize=9, fontweight='bold')

                speedup_single = timing_raw[0] / timing_raw[1]
                speedup_multi = timing_raw[2] / timing_raw[3]

                # --- BLOCO INFO (RESTAURADO) ---
                info = (
                    f"Benchmark: {n_iters:,} iterations\n"
                    f"{'-'*30}\n"
                    f"SINGLE-MODE (SISO)\n"
                    f"Filtro: Vector [1 x {N_TAPS}]\n"
                    f"Dim: N_TAPS (Time-Delay)\n"
                    f"Speedup: {speedup_single:.2f}×\n\n"
                    f"MULTI-MODE (MIMO)\n"
                    f"Filtro: Matrix [{N_MODES}x{N_MODES} x {N_TAPS}]\n"
                    f"Dim: N_MODES (Spatial Sep.)\n"
                    f"Speedup: {speedup_multi:.2f}×"
                )

                ax_perf.text(0.92, 0.35, info, transform=ax_perf.transAxes, ha='center', va='center',
                            fontsize=9, linespacing=1.3, bbox=dict(boxstyle="round,pad=0.8", fc="white", ec="#333333", lw=1.5))

                ax_perf.set_title(f"CMA Performance: Avg Time per Iteration ({n_iters:,} runs)", fontweight="bold", pad=15)
                ax_perf.set_xticks([]); [s.set_visible(False) for s in ax_perf.spines.values()]
        except Exception as e:
            ax_perf.text(0.5, 0.5, f"Timing error: {e}", ha='center', transform=ax_perf.transAxes)
    else:
        ax_perf.text(0.5, 0.5, f"{timing_path} not found", ha='center', transform=ax_perf.transAxes)

    output_plot = os.path.join(DATA_DIR, "cma_full_equivalence_report.png")
    plt.savefig(output_plot, dpi=300, bbox_inches='tight')
    print(f"✓ Relatório visual salvo em: {output_plot}")
    plt.show()

if __name__ == "__main__":
    generate_full_report()