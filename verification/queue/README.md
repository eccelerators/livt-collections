# Scheduled Queue boundary verification

Run from the Collections repository:

```sh
python3 verification/queue/verify.py
```

The bounded harness builds the production package, snapshots generated VHDL,
and directly drives Queue8's method run/busy ports with a 100 MHz context.
It measures uncontended enqueue, dequeue, clear, count and space calls, including
full enqueue and empty dequeue. It verifies results, then resets each mutating
method at offsets 0 through 24 after request assertion. After every reset it
checks idle handshakes, empty contents, no delayed transaction, and reuse.

The request pulse is sampled for one edge. Measurements count rising edges
inclusively from that edge through the observed busy deassertion. The caller
must first observe busy asserted; an initial idle value is not completion.
Each call has a 64-edge watchdog and the simulation has a 200 us watchdog.
This does not establish minimum initiation interval, contended latency, or the
cost of an additional Livt caller/interface-reference dispatch layer.

On 2026-09-16 the measured edge counts were:

| Operation | Edges |
|---|---:|
| TryEnqueue, accepted/full | 16 |
| TryDequeue, accepted/empty | 13 |
| Clear, empty/full | 11 |
| GetCount / GetSpace | 7 |

All 75 reset offsets passed. These are measured values, not an immutable API
promise. The primary contract remains correct acceptance, ordering and recovery.
The separate FIFO edge scoreboard checks the hardware-level transaction boundary;
the package tests check concurrent callers and capacity/type specializations.

The printed temporary directory retains the HDL snapshot, harness, tool-version
logs, simulation log and result.json with source/generated-file hashes. Review
private build logs before sharing; Java launch options can include credentials.
No area, RAM inference or physical clock-timing claim follows from these tests.
