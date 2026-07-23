# TSN-over-WiFi7

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
