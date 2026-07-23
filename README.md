# TSN-over-WiFi7
La letteratura economica moderna, in particolare i modelli di crescita endogena, suggerisce che lo sviluppo di lungo periodo di un sistema dipende soprattutto dalla capacità di generare e diffondere innovazione. In questo contesto, le infrastrutture di comunicazione non sono più semplici canali passivi, ma diventano attori centrali nel processo di crescita.

In campi come Industria 4.0 (ma anche automotive, difesa, audio/video, sanità ecc..) riscontriamo la necessità di migliorare l’accesso alle informazioni, dato che ciò porta a:

* Abbassare i costi
* Aumentare l’efficienza
* Garantire sicurezza

Questi sono gli obiettivi principali dei processi di convergenza IT/OT a cui stiamo assistendo oggi, che puntano ad un cambio di paradigma, passando da gerarchie rigide (si veda ISA 95) a modelli “piatti” che favoriscono l'interoperabilità e l'interazione diretta tra i diversi livelli della piramide industriale, e ci permettono di pensare alle informazioni come ad un flusso unico e continuo.

Per supportare questa convergenza è necessario far convivere le caratteristiche intrinseche dei due mondi, e gestire aspetti come:

* La presenza di più flussi di informazioni, ognuno con il proprio grado di “criticità”
* Comunicazione deterministica, e cosa ciò comporta nel “mondo” IT, ricordando che la semantica di comunicazione che prevale nelle reti è di tipo best-effort

Nei prossimi capitoli verranno presentate alcune delle tecnologie fondamentali per supportare questa transizione, e come queste possono essere usate in situazioni reali.
Nei prossimi capitoli verranno presentate alcune delle tecnologie fondamentali per supportare questa transizione, e come queste possono essere usate in situazioni reali.
Il prototipo realizzato a sostegno della tesi TSN-over-WiFi7 presenta la seguente struttura:
```text
[ Talker ]                                         [ Listener ]
 +--------------------------------+                 +--------------------------------+
 |  [ptp-tal1] < - - - > [wlan0]  |                 |  [wlan3] < - - - > [ptp-lis1]  |
 |      ^                   |     |                 |      |                   ^     |
 |     veth                 |     |                 |      |                  veth   |
 |      |              [wlan0.10] |                 |  [wlan3.20]              |     |
 |  [ptp-tal0]              |     |                 |      |             [ptp-lis0]  |
 |      ^                   |     |                 |      |                   ^     |
 |   [ptp4l]                |     |                 |      |                [ptp4l]  |
 +--------------------------------+                 +--------------------------------+
                            |                              |
                       WiFi 7 link                    WiFi 7 link
                            |                              |
                            v                              v
 +----------------------------------------+         +----------------------------------------+
 |                  [ptp-repl0] <-[ptp4l]-+->[mgmt]<--veth-->[mgmt]<-[ptp4l]-> [ptp-elim0]   |
 |                      |                 |         |                                |       |
 |                     veth               |         |                               veth     |
 |                      v                 |         |                                v       |
 | [wlan1] < - - - > [ptp-repl1]          |         |                    [ptp-elim1] < - - > [wlan2]
 |    |                                   |         |                                          ^ |
 |    + - - - - - > [vproxy-repl-in]      |         |                                          | |
 |    ^                    |              |         |  [veth-elimN] -+                         | |
 |    |                   veth            |         |        |       |                         | |
 |    |                    v              |         |  [veth-elim1] -+-> XDP/FRER              | |
 |    |             [vproxy-repl-out]     |         |        |              |                  | |
 |    |                 [taprio]          |         |  [veth-elim0] -+      v                  | |
 |    |                    |              |         |                   [vproxy-elim-in]       | |
 |    |                    v              |         |                          |               | |
 |    |                 XDP/FRER          |         |                         veth             | |
 |    |                    |              |         |                          v               | |
 |    |                    +->[veth-replN]<--veth-->[veth-elimN]      [vproxy-elim-out]- - - - + |
 |    |                    |              |         |                                            |
 |    |                    +->[veth-repl1]<--veth-->[veth-elim1]                                 |
 |    |                    |              |         |                                            |
 |    |                    +->[veth-repl0]<--veth-->[veth-elim0]                                 |
 |    |                                   |         |                                            |
 |    + - - - - - - - - - [veth-ret-repl] <--veth--> [veth-ret-elim] < - - - - - - - - - - - - - +
 +----------------------------------------+         +----------------------------------------+
           [ Bridge Replication ]                             [ Bridge Elimination ]
```
Per le motivazioni di tale architettura si faccia riferimento al capitolo 3 della tesi.
