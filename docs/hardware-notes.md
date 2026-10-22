# Livt.Collections Hardware Notes

All `Livt.Collections` production components are synthesizable and use fixed
storage. This document records behavior that affects resource use, timing, and
safe maintenance of the implementations.

FIFO and Queue types live directly in `Livt.Collections`. Other families retain
their existing sub-namespaces, such as `Livt.Collections.Circular`.

## Generic FIFO contract and verification

`Fifo<T, CAPACITY>` has one clocked owner for storage, pointers and occupancy.
Requests and acceptance are sampled together at the active edge. Reset wins
over clear; both suppress push/pop. Clear logically empties the FIFO. A full
simultaneous pop/push returns the old head, while an empty simultaneous request
accepts only push. Rejected transfers do not mutate storage or occupancy.

`Queue<T, CAPACITY>` adds scheduled, per-operation request/completion toggles.
One explicit arbiter selects clear first, otherwise alternating pending enqueue
and dequeue. Results remain separate until the corresponding next call. Clear
does not cancel other pending calls: they may execute after clear, so concurrent
clear and enqueue can leave zero or one new value depending on arrival order.

Run `livt test` for the shipped Livt tests. Independent development checks at
capacities 1, 3 and 64 exercised 271, 279 and 523 cycles, including reset, clear,
full/empty simultaneous requests and wrapping. That external development harness
is not distributed with the library.

FIFO pointers and occupancy use capacity-derived widths, and eligible
single-owner indexed writes lower without a secondary whole-array mutation
shadow. RAM inference, area, and Fmax remain target- and contract-dependent.
UART uses the signal-level FIFO directly rather than scheduled Queue calls on
its byte-rate path.

## Scheduled Queue measurements

Development-only generated-method handshake measurements also checked reset
recovery. At 100 MHz, the 2026-09-16 Queue8 run measured
16 edges for TryEnqueue (accepted or full), 13 for TryDequeue (accepted or empty),
11 for Clear and 7 for GetCount/GetSpace. Counting is inclusive from the first
edge sampling the one-cycle run request through observed busy deassertion.
These are uncontended boundary measurements, not caller-to-caller latency or
throughput guarantees; scheduled callers and contention add costs.

That development probe also interrupted enqueue, dequeue and clear at 25 offsets
each, checking busy release, empty occupancy, absence of delayed operations after
reset, and successful reuse. Generated Queue8 must contain exactly one FIFO instance
and no nested Queue entity. Named-capacity and generic-interface behavioral
tests run in the ordinary package suite.

## Fixed Storage

Generic queue, stack, circular-buffer, and fixed-list components store
`T[CAPACITY]`. Named variants store `byte` values and use their suffix as the
capacity: `Queue8` contains eight bytes, `Stack64` contains 64 bytes, and so on.
`BitSet8` contains eight boolean flags.

Only instantiated components consume design resources. Installing the package
does not instantiate every capacity variant. Whether a byte array maps to
registers, distributed RAM, or block RAM is target- and synthesis-dependent;
verify inference and timing for the intended device.

All generic storage is specialized at compile time. Occupancy and ring indices
use widths derived from `CAPACITY`; for example, a 64-entry address uses six bits
and an occupancy count uses seven. Named queue, stack, circular-buffer, and
fixed-list components inherit one matching specialization and own no additional
storage.

## Full and Empty Behavior

| Family | Operation when full | Read when empty |
|---|---|---|
| Queue | `TryEnqueue` returns false | `TryDequeue` assigns zero and returns false |
| Stack | `Push` ignores the new value | `Pop` and `Peek` return zero |
| Circular buffer | `Write` accepts the value and discards the oldest | `Read` and `Peek` return zero |
| Fixed list | `Add` ignores the new value | `RemoveLast` returns zero |

Queue's success result distinguishes empty from a valid zero payload and rejection
from acceptance atomically. Its status methods cannot reserve a slot. The older
stack, circular-buffer and list APIs use sentinel values; separate status checks
are only meaningful when another caller cannot change contents between calls.

`Clear()` resets pointers and logical size only. It does not erase the backing
array because inactive elements are not observable through the public API.
Backing arrays are marked `@UninitializedStorage`, so generated reset logic
does not write their cells. Cell values are unspecified after
power-up and reset. A cell becomes valid when an accepted FIFO push or queue
enqueue, stack push, list add, or circular-buffer write stores an element and
updates the collection's logical state. List `Set()` replaces an already-valid
element without changing the logical size.
`BitSet8.Reset()` clears all flags because every flag remains directly
observable.

## Interface Dispatch

The `IQueue<T>`, `IStack<T>`, `ICircularBuffer<T>`, `IList<T>`, and `IBitSet`
interfaces are storage-free contracts. A field typed as a concrete component,
such as `Queue16`, allows normal concrete calls. A field typed as `IQueue<byte>`
requires Livt's interface-reference dispatch and can add handshake states and
wiring. Prefer concrete field types in timing-sensitive code unless runtime
structural substitution is required.

## Array-Write Patterns

The shared circular-buffer `Write()` implementation intentionally performs its
array assignment on one unconditional path. Moving the assignment into separate
full/not-full branches can cause current compiler staging to lose previously
stored elements.

List writes originate from both `Add()` and `Set()`. The regression
`TestAddPreservesValuesWrittenBySet` verifies that alternating those operations
preserves all live elements. Keep this regression when modifying list storage
or control flow.

Queue storage writes occur only in its FIFO's owner process; stack writes occur only in `Push()`.
Avoid duplicating their array assignments across alternative branches without
adding a simulation regression for state preservation.

## BitSet8 Representation

`BitSet8` uses eight independent `bool` fields instead of a shared `logic[8]`
field. With the current compiler, multiple functions performing indexed writes
to one logic-vector field can retain stale per-function staging values. A later
operation can then restore bits cleared by `Reset()` or `Clear()`.

Do not replace the independent fields or add larger vector-backed BitSets until
the generated VHDL has a regression proving that sequences of `Set`, `Clear`,
`Toggle`, and `Reset` preserve every unaffected bit.

## Dual-clock FIFO

Use `DualClockFifo` to pass an ordered stream between independent clocks.
See [usage and transfer timing](dual-clock-fifo.md) and
[backing storage selection](fifo-storage.md).

For hardware integration:

1. Declare both clocks and check that write/read state and destination
   synchronizers use their intended clocks and resets.
2. Identify the two pointer-synchronization stages in the synthesized netlist.
   Preserve their registers and placement; prevent retiming, merging or
   shift-register extraction from changing the chain.
3. Constrain source Gray-pointer paths to the destination first stage for maximum
   delay and bus skew, bounded by the minimum source pointer-update period.
   An asynchronous false-path exception alone does not constrain Gray-bit skew;
   ensure clock-group exceptions do not override the intended constraints.
4. Keep first-to-second-stage paths locally timed. Check the payload read path,
   read-register timing and actual inferred memory resource.
5. Synchronize reset release and the surrounding controller's clear/acknowledgment
   signals in the appropriate domains. Review CDC and post-fit timing reports.

Memory styles express intent, not guaranteed block-RAM allocation. The built-in
storage has a combinational read tap with response registration in the read
endpoint. Verify that synthesis maps this structure as intended for the target.
