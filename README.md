# Livt.Collections

`Livt.Collections` provides fixed-size, synthesizable collection components
for Livt applications. It is part of the official Livt base library package
set and has no package dependencies.

The package contains byte-oriented FIFO queues, LIFO stacks, overwrite-on-full
circular buffers, fixed-capacity lists, and an indexed flag set. Storage is
declared independently by each concrete component so selecting a larger variant
does not retain or duplicate a smaller base component's memory. All collection
values use the Livt `byte` type.

## 📦 Package

```toml
[dependencies]
Livt.Collections = "1.0.1"
```

`Livt.Collections` supersedes the standalone Queue, Stack, CircularBuffer, and
BitSet packages for new applications.

## 📚 Namespaces and Components

Namespaces follow the package's family folders:

| Folder | Production namespace | Test namespace |
|---|---|---|
| `queue` | `Livt.Collections.Queue` | `Livt.Collections.Tests.Queue` |
| `stack` | `Livt.Collections.Stack` | `Livt.Collections.Tests.Stack` |
| `circular` | `Livt.Collections.Circular` | `Livt.Collections.Tests.Circular` |
| `list` | `Livt.Collections.List` | `Livt.Collections.Tests.List` |
| `bitset` | `Livt.Collections.BitSet` | `Livt.Collections.Tests.BitSet` |

Interfaces describe behavior without owning storage; concrete component names
include their fixed capacity.

| Contract | Component | Capacity | Behavior when full |
|---|---|---:|---|
| `IQueue` | `Queue8` | 8 bytes | Additional enqueue is ignored |
| `IQueue` | `Queue16` | 16 bytes | Additional enqueue is ignored |
| `IQueue` | `Queue32` | 32 bytes | Additional enqueue is ignored |
| `IQueue` | `Queue64` | 64 bytes | Additional enqueue is ignored |
| `IStack` | `Stack8` | 8 bytes | Additional push is ignored |
| `IStack` | `Stack16` | 16 bytes | Additional push is ignored |
| `IStack` | `Stack32` | 32 bytes | Additional push is ignored |
| `IStack` | `Stack64` | 64 bytes | Additional push is ignored |
| `ICircularBuffer` | `CircularBuffer8` | 8 bytes | Oldest element is overwritten |
| `ICircularBuffer` | `CircularBuffer16` | 16 bytes | Oldest element is overwritten |
| `ICircularBuffer` | `CircularBuffer32` | 32 bytes | Oldest element is overwritten |
| `ICircularBuffer` | `CircularBuffer64` | 64 bytes | Oldest element is overwritten |
| `IFixedList` | `FixedList8` | 8 bytes | Additional add is ignored |
| `IFixedList` | `FixedList16` | 16 bytes | Additional add is ignored |
| `IFixedList` | `FixedList32` | 32 bytes | Additional add is ignored |
| `IFixedList` | `FixedList64` | 64 bytes | Additional add is ignored |
| `IBitSet` | `BitSet8` | 8 flags | Out-of-range operations are ignored |

Every concrete component has an explicit capacity in its name. The `IQueue`,
`IStack`, `ICircularBuffer`, `IFixedList`, and `IBitSet` interfaces are
storage-free contracts; there are no ambiguous unsized base components. Each
concrete component exposes a public `CAPACITY` constant describing its allocated
storage. Array extents remain decimal literals until Livt supports named
compile-time constants in array declarations.

The interfaces contain no storage. Applications may implement a contract with
another literal capacity without inheriting unused memory. Using a concrete
component type at the call site avoids interface-reference dispatch when
backend substitution is not required.

## 🔗 Dependency Policy

`Livt.Collections` has no dependencies on other Livt packages. It contains
general-purpose fixed-capacity storage structures only; protocol buffers,
device-specific FIFOs, caches, and domain algorithms belong in their respective
packages.

## 🗂️ Layout

```text
src/queue/       FIFO queue interface and fixed-capacity implementations
src/stack/       LIFO stack interface and fixed-capacity implementations
src/circular/    overwrite-on-full circular buffers
src/list/        indexed fixed-capacity lists
src/bitset/      indexed flag sets
tests/<family>/  matching behavioral and boundary tests
docs/            usage, synthesis behavior, and compiler workarounds
```

Folders and namespaces use the same family names. Tests mirror production
families below `Livt.Collections.Tests`.

## 🔌 API Overview

### Queue

- `Enqueue(value)` appends a value when space is available.
- `Dequeue()` removes and returns the oldest element.
- `Peek()` returns the oldest element without removing it.
- `IsEmpty()`, `IsFull()`, and `GetSize()` report state.
- `Clear()` resets the queue.

### Stack

- `Push(value)` appends an element when space is available.
- `Pop()` removes and returns the newest element.
- `Peek()` returns the newest element without removing it.
- `IsEmpty()`, `IsFull()`, and `GetSize()` report state.
- `Clear()` resets the stack.

Empty `Dequeue()`, `Pop()`, and `Peek()` calls return `0x00`.

### Circular Buffer

- `Write(value)` appends an element and overwrites the oldest element when full.
- `Read()` removes and returns the oldest element.
- `Peek()` returns the oldest element without removing it.
- `IsEmpty()`, `IsFull()`, and `GetSize()` report state.
- `Clear()` resets the logical contents without erasing the storage array.

Empty `Read()` and `Peek()` calls return `0x00`.

### Fixed List

- `Add(value)` appends an element when space is available.
- `Get(index)` reads an element within the logical list length.
- `Set(index, value)` replaces an existing element.
- `RemoveLast()` removes and returns the final element.
- `GetSize()`, `IsEmpty()`, and `IsFull()` report state.
- `Clear()` resets the logical length without erasing the storage array.

Invalid reads and empty `RemoveLast()` calls return `0x00`. Invalid
writes and additions to a full list are ignored. Indexed insertion and removal
are intentionally omitted because they require shifting stored elements.

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
- Use `byte` for stored values and byte-oriented public APIs.
- Give every concrete collection an explicit capacity suffix.
- Keep all variants of one family behaviorally identical.
- Add boundary, full/empty, clear/reuse, and ordering tests for API changes.
- Preserve the array-write patterns described in `docs/hardware-notes.md`.

## 🚧 Outlook

Once Livt supports named integral constants in array extents, the repeated
capacity-specific implementations can be consolidated while retaining the
explicit public component names. Possible later additions include larger safe
BitSet variants and a fixed-capacity deque. Dynamic allocation, linked
structures, and software-style unbounded collections are outside this package's
scope.

## 📄 License

This project is licensed under the MIT License. See [LICENSE](LICENSE).
