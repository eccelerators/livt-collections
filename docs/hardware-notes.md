# Livt.Collections Hardware Notes

All `Livt.Collections` production components are synthesizable and use fixed
storage. This document records behavior that affects resource use, timing, and
safe maintenance of the implementations.

Production namespaces follow their source folders, for example
`Livt.Collections.Queue` and `Livt.Collections.Circular`. Tests mirror those
families below `Livt.Collections.Tests`.

## Fixed Storage

Queue, stack, circular-buffer, and fixed-list values are `byte` values. Their
component suffix is the storage capacity: `Queue8` contains eight bytes,
`Queue64` contains 64 bytes, and so on. `BitSet8` contains eight boolean flags.

Only instantiated components consume design resources. Installing the package
does not instantiate every capacity variant. Whether a byte array maps to
registers, distributed RAM, or block RAM is target- and synthesis-dependent;
verify inference and timing for the intended device.

Each concrete component exposes a public `CAPACITY` constant. The array extent
is currently repeated as a decimal literal because the compiler does not yet
accept named integral constants in array dimensions. Keep those two values
identical when editing or adding a variant.

## Full and Empty Behavior

| Family | Operation when full | Read when empty |
|---|---|---|
| Queue | `Enqueue` ignores the new value | `Dequeue` and `Peek` return `0x00` |
| Stack | `Push` ignores the new value | `Pop` and `Peek` return `0x00` |
| Circular buffer | `Write` accepts the value and discards the oldest | `Read` and `Peek` return `0x00` |
| Fixed list | `Add` ignores the new value | `RemoveLast` returns `0x00` |

Because `0x00` is also a valid stored value, callers that need to distinguish
an empty collection must check `IsEmpty()` before reading. Callers that need to
detect a rejected write must check `IsFull()` before writing.

`Clear()` resets pointers and logical size only. It does not erase the backing
array because inactive elements are not observable through the public API.
`BitSet8.Reset()` clears all flags because every flag remains directly
observable.

## Interface Dispatch

The `IQueue`, `IStack`, `ICircularBuffer`, `IFixedList`, and `IBitSet`
interfaces are storage-free contracts. A field typed as a concrete component,
such as `Queue16`, allows normal concrete calls. A field typed as `IQueue`
requires Livt's interface-reference dispatch and can add handshake states and
wiring. Prefer concrete field types in timing-sensitive code unless runtime
structural substitution is required.

## Array-Write Patterns

The circular-buffer `Write()` implementations intentionally perform their
array assignment on one unconditional path. Moving the assignment into separate
full/not-full branches can cause current compiler staging to lose previously
stored elements.

FixedList writes originate from both `Add()` and `Set()`. The regression
`TestAddPreservesValuesWrittenBySet` verifies that alternating those operations
preserves all live elements. Keep this regression when modifying list storage
or control flow.

Queue writes occur only in `Enqueue()`, and stack writes occur only in `Push()`.
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
