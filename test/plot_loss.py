import matplotlib.pyplot as plt

# --- DATI ---
tempi = [4.0, 8.0, 12.0, 16.0, 20.0, 24.0]
loss_taprio = [0.0, 0.0, 0.0, 1.3, 0.0, 0.0]
loss_pfifo = [0.0, 0.0, 0.0, 46.2, 45.0, 0.0]

totale_taprio = 0.2
totale_pfifo = 15.9

# --- COLORI ACCADEMICI ---
# Colori ad alto contrasto, adatti anche alla stampa in scala di grigi
color_taprio = '#1f4e79'  # Blu scuro / Navy
color_pfifo = '#b22222'   # Rosso mattone / Firebrick
color_bg_congestione = '#e8e8e8' # Grigio chiaro neutro

# Impostazioni di base del font e dello stile
plt.rcParams.update({
    'font.size': 12,
    'font.family': 'serif', # I font serif (come Times New Roman) sono standard nei paper
    'axes.labelsize': 12,
    'axes.titlesize': 14,
    'legend.fontsize': 11,
    'xtick.labelsize': 11,
    'ytick.labelsize': 11
})

# ==============================================================================
# GRAFICO 1: Andamento nel tempo (Line Chart)
# ==============================================================================
fig1, ax1 = plt.subplots(figsize=(8, 6))

ax1.plot(tempi, loss_pfifo, marker='o', linestyle='-', color=color_pfifo, 
         linewidth=2, markersize=7, label='Senza TAPRIO (pfifo_fast)')
ax1.plot(tempi, loss_taprio, marker='s', linestyle='-', color=color_taprio, 
         linewidth=2, markersize=7, label='Con TAPRIO (802.1Qbv)')

# Finestra di congestione (background shade)
ax1.axvspan(12, 20, color=color_bg_congestione, alpha=0.6, label='Finestra di Congestione BE')

ax1.set_title('Andamento del Packet Loss nel Tempo\n(Traffico Critico)', pad=15)
ax1.set_xlabel('Tempo (s)')
ax1.set_ylabel('Pacchetti Persi (%)')
ax1.set_xticks(tempi)
ax1.set_ylim(-2, 55)

# Griglia accademica (sottile e tratteggiata)
ax1.grid(True, linestyle='--', linewidth=0.5, alpha=0.7)
ax1.legend(loc='upper left', frameon=True, edgecolor='black')

# Annotazioni sui picchi
ax1.annotate('46.2%', xy=(16, 46.2), xytext=(15.2, 48), color=color_pfifo, weight='bold')
ax1.annotate('45.0%', xy=(20, 45.0), xytext=(19.2, 47), color=color_pfifo, weight='bold')
ax1.annotate('1.3%', xy=(16, 1.3), xytext=(16.2, 3), color=color_taprio, weight='bold')

fig1.tight_layout()
fig1.savefig('fig1_loss_tempo.png', dpi=300, bbox_inches='tight')
plt.close(fig1)

# ==============================================================================
# GRAFICO 2: Totale pacchetti persi (Bar Chart)
# ==============================================================================
fig2, ax2 = plt.subplots(figsize=(6, 6))

labels = ['Con TAPRIO\n(802.1Qbv)', 'Senza TAPRIO\n(pfifo_fast)']
valori = [totale_taprio, totale_pfifo]
colori_barre = [color_taprio, color_pfifo]

# Aggiunta di un bordo nero alle barre per maggiore definizione in stampa
bars = ax2.bar(labels, valori, color=colori_barre, width=0.4, edgecolor='black', linewidth=1)

ax2.set_title('Totale Pacchetti Persi\n(Intero Esperimento)', pad=15)
ax2.set_ylabel('Pacchetti Persi (%)')
ax2.set_ylim(0, 20)
ax2.grid(axis='y', linestyle='--', linewidth=0.5, alpha=0.7)

# Valori sopra le barre
for bar in bars:
    height = bar.get_height()
    ax2.annotate(f'{height}%',
                 xy=(bar.get_x() + bar.get_width() / 2, height),
                 xytext=(0, 5),  # offset verticale in punti
                 textcoords="offset points",
                 ha='center', va='bottom', weight='bold')

fig2.tight_layout()
fig2.savefig('fig2_loss_totale.png', dpi=300, bbox_inches='tight')
plt.close(fig2)

print("Generazione completata: 'fig1_loss_tempo.png' e 'fig2_loss_totale.png'")