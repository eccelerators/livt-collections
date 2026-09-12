# Livt.Collections

`Livt.Collections` provides fixed-size, synthesizable collection components
for Livt applications. It is part of the official Livt base library package
set and has no package dependencies.

The package contains generic FIFO/Queue components, LIFO stacks,
overwrite-on-full circular buffers, fixed-capacity lists, and an indexed flag
set. Element type and capacity are compile-time configuration for every storage
family except the intentionally specialized `BitSet8`. Named byte components are
thin inherited aliases and do not retain or duplicate another capacity's memory.

## 📦 Package

```toml
[dependencies]
Livt.Collections = "1.1.0"
```

`Livt.Collections` supersedes the standalone Queue, Stack, CircularBuffer, and
BitSet packages for new applications.

## 📚 Namespaces and Components

Namespaces follow the package's family folders:

| Folder | Production namespace | Test namespace |
|---|---|---|
| `fifo`, `queue` | `Livt.Collections` | `Livt.Collections.Tests`, `Livt.Collections.Tests.Queue` |
| `stack` | `Livt.Collections.Stack` | `Livt.Collections.Tests.Stack` |
| `circular` | `Livt.Collections.Circular` | `Livt.Collections.Tests.Circular` |
| `list` | `Livt.Collections.List` | `Livt.Collections.Tests.List` |
| `bitset` | `Livt.Collections.BitSet` | `Livt.Collections.Tests.BitSet` |

Interfaces describe behavior without owning storage. Generic implementations
select element type and capacity at compile time; named byte variants provide
convenient specializations.

| Contract | Component | Capacity | Behavior when full |
|---|---|---:|---|
| `IQueue<T>` | `Queue<T, CAPACITY>` | CAPACITY values (default 64) | TryEnqueue returns false |
| `IQueue<byte>` | `Queue8` | 8 bytes | TryEnqueue returns false |
| `IQueue<byte>` | `Queue16` | 16 bytes | TryEnqueue returns false |
| `IQueue<byte>` | `Queue32` | 32 bytes | TryEnqueue returns false |
| `IQueue<byte>` | `Queue64` | 64 bytes | TryEnqueue returns false |
| `IStack<T>` | `Stack<T, CAPACITY>` | CAPACITY values (default 64) | Additional push is ignored |
| `IStack<byte>` | `Stack8` / `Stack16` / `Stack32` / `Stack64` | Named byte capacities | Additional push is ignored |
| `ICircularBuffer<T>` | `CircularBuffer<T, CAPACITY>` | CAPACITY values (default 64) | Oldest element is overwritten |
| `ICircularBuffer<byte>` | `CircularBuffer8` / `16` / `32` / `64` | Named byte capacities | Oldest element is overwritten |
| `IList<T>` | `List<T, CAPACITY>` | CAPACITY values (default 64) | Additional add is ignored |
| `IList<byte>` | `List8` / `16` / `32` / `64` | Named byte capacities | Additional add is ignored |
| `IBitSet` | `BitSet8` | 8 flags | Out-of-range operations are ignored |

The `IQueue<T>`, `IStack<T>`, `ICircularBuffer<T>`, `IList<T>`, and
`IBitSet` interfaces are storage-free contracts. Generic backing storage declares
`T[CAPACITY]`; named byte capacities inherit the matching specialization.

The interfaces contain no storage. Applications may implement a contract with
another capacity without inheriting unused memory. Using a concrete
component type at the call site avoids interface-reference dispatch when
backend substitution is not required.

## 🔗 Dependency Policy

`Livt.Collections` has no dependencies on other Livt packages. It contains
general-purpose fixed-capacity storage structures only; protocol buffers,
device-specific FIFOs, caches, and domain algorithms belong in their respective
packages.

## 🗂️ Layout

```text
src/fifo/        signal-level FIFO storage and control
src/queue/       scheduled generic queue and thin byte specializations
src/stack/       generic LIFO storage and thin byte specializations
src/circular/    generic overwrite-on-full rings and thin byte specializations
src/list/        generic indexed lists, iterator, and thin byte specializations
src/bitset/      indexed flag sets
tests/<family>/  matching behavioral and boundary tests
docs/            usage, synthesis behavior, and compiler workarounds
```

Folders and namespaces use the same family names. Tests mirror production
families below `Livt.Collections.Tests`.

## 🔌 API Overview

### Generic FIFO and Queue

Use `Queue<byte, 64>` for scheduled application access and
`Fifo<byte, 64>` for cycle-level producer/consumer wiring. `CAPACITY` is a
positive compile-time storage extent and defaults to 64; non-power-of-two
capacities are supported.

- `TryEnqueue(value)` returns whether the value was accepted.
- `TryDequeue(value: out T)` returns whether an item was removed and assigns
  the type's zero value when empty. Zero is a valid payload on success.
- `Clear()` is serialized with both operations.
- `GetCount()` and `GetSpace()` are snapshots, not reservations.

Queue uses separate pending requests/results and one transaction arbiter.
Clear has priority; pending enqueue and dequeue alternate. Calls are scheduled
and multi-cycle, not one-clock transactions. Different public operations may
run concurrently; callers of the same method use the compiler's public-method
arbitration. There is no cross-clock FIFO guarantee.

Fifo accepts up to one push and one pop per edge. Reset and clear suppress
transfers. At full, simultaneous push/pop return the old head and preserve
count; at empty, only push succeeds (no bypass). Acceptance and head data are
combinational **pre-edge** signals and must be sampled at the transfer edge.
See [hardware notes](docs/hardware-notes.md) for the current resource limitations.

### Hardware-level and application-level access

`Fifo` is the hardware-level boundary for cycle-sensitive datapaths. `Queue`
is the application-level boundary for convenient scheduled transactions. Both
have FIFO ordering; the difference is access and timing, not ordering or whether
they synthesize to hardware. Queue adds arbitration and completion control around
one FIFO, so its convenience has explicit control-state and latency costs.

`Queue8`, `Queue16`, `Queue32`, and `Queue64` inherit from
`Queue<byte, 8>`, `Queue<byte, 16>`, `Queue<byte, 32>`, and
`Queue<byte, 64>`. They share the same Try-operation API and `IQueue<byte>`
contract. Use the generic form for other types or capacities. The former silent
`Enqueue`/`Dequeue` API is replaced, not retained as a second implementation.

### Stack

Use `Stack<T, CAPACITY>` for arbitrary element types and capacities.
`Stack8`, `Stack16`, `Stack32`, and `Stack64` are byte specializations.

- `Push(value)` appends an element when space is available.
- `Pop()` removes and returns the newest element.
- `Peek()` returns the newest element without removing it.
- `IsEmpty()`, `IsFull()`, and `GetSize()` report state.
- `Clear()` resets the stack.

Empty stack `Pop()` and `Peek()` calls return the element type's zero value.

### Circular Buffer

Use `CircularBuffer<T, CAPACITY>` for arbitrary element types and capacities.
The four capacity-suffixed components are byte specializations.

- `Write(value)` appends an element and overwrites the oldest element when full.
- `Read()` removes and returns the oldest element.
- `Peek()` returns the oldest element without removing it.
- `IsEmpty()`, `IsFull()`, and `GetSize()` report state.
- `Clear()` resets the logical contents without erasing the storage array.

Empty `Read()` and `Peek()` calls return the element type's zero value.

### List

Use `List<T, CAPACITY>` for arbitrary element types and capacities. The
four capacity-suffixed components are byte specializations.

- `Add(value)` appends an element when space is available.
- `Get(index)` reads an element within the logical list length.
- `Set(index, value)` replaces an existing element.
- `RemoveLast()` removes and returns the final element.
- `GetSize()`, `IsEmpty()`, and `IsFull()` report state.
- `Clear()` resets the logical length without erasing the storage array.

Invalid reads and empty `RemoveLast()` calls return the element type's zero value. Invalid
writes and additions to a full list are ignored. Indexed insertion and removal
are intentionally omitted because they require shifting stored elements.

### List iteration

`ListIterator<T>` implements the core `IResettableIterator<T>` contract and
borrows an `IList<T>`. Declare a cursor beside the list and bind it in the
constructor, for example `new ListIterator<byte>(this.values)`.

The cursor borrows list storage and owns only its position. `HasNext()` checks
the logical list size; `Next()` returns the current value and advances without
removing it. Call `Next()` only when `HasNext()` is true. `Reset()` rewinds
without changing the list. Two cursors can have independent positions, but
access to shared list hardware must still be serialized. Do not mutate the
list during a traversal.

Use the cursor directly with `foreach` or the `Iteration.Fold`, `Any`, `All`,
`CountWhere`, and `FindIndex` algorithms from `Livt.Base`. Both consume its
current position without an implicit reset. Algorithms live in `Livt.Base`;
this adapter adds no package dependency to `Livt.Collections`.

### Bit Set

- `Set(index)`, `Clear(index)`, and `Toggle(index)` modify one flag.
- `IsSet(index)` reads one flag.
- `Any()` and `None()` summarize the current flags.
- `GetValue()` returns the eight flags as an integer bit mask.
- `GetCapacity()` returns the number of addressable flags.
- `Reset()` clears every flag.

`BitSet8` uses independent boolean fields rather than indexed writes to a
`logic[8]` field. This avoids a current compiler staging limitation that can
restore stale bits after operations from different functions. Larger BitSet
variants should be added only after that compiler behavior is corrected.

## ⚙️ Hardware and Synthesis Notes

All production components are synthesizable. Capacity is structural: selecting
an 8-, 16-, 32-, or 64-entry component changes the allocated storage. `Clear()`
and `Reset()` clear logical state but do not erase inactive array elements.

Overflow, underflow, storage inference, interface-dispatch costs, and current
compiler workarounds are documented in
[`docs/hardware-notes.md`](docs/hardware-notes.md).

## 🧪 Build and Test

```sh
livt test
```

To force clean regeneration while preserving synchronized dependencies:

```sh
livt clean
livt test
```

See [`docs/usage.md`](docs/usage.md) for examples.

## 🛠️ Development Notes

- Keep namespaces aligned with their family folders.
- Keep generic storage typed; retain named byte aliases for common capacities.
- Use positive compile-time capacities and cover non-power-of-two boundaries.
- Keep all variants of one family behaviorally identical.
- Add boundary, full/empty, clear/reuse, and ordering tests for API changes.
- Preserve the array-write patterns described in `docs/hardware-notes.md`.

## 🚧 Outlook

Possible later additions include larger safe BitSet variants and a fixed-capacity
deque. Dynamic allocation, linked
structures, and software-style unbounded collections are outside this package's
scope.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
