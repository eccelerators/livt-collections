# Changelog

## 1.4.0

### Changed

- **Breaking API rename:** the asynchronous FIFO is now named
  `AsyncFifo<T, CAPACITY, STORAGE>`. Update declarations and constructor calls
  when upgrading from 1.3.0; no compatibility alias is provided.
- Storage-provider names are now `AsyncFifoArray`, `AsyncFifoBlockRam` and
  `AsyncFifoDistributedRam`. The default remains `AsyncFifoArray<T, CAPACITY>`.
- Renamed internal clock-domain components and native test helpers consistently;
  the FIFO test component is now `AsyncFifoTest`.
- Updated README examples, storage guidance and FIFO documentation. The usage
  guide is now `docs/async-fifo.md`.

Constructor parameters, generic storage selection, clock-domain behavior,
transfer timing and coordinated-clear semantics are unchanged. Existing
single-clock collection APIs are unchanged.

## 1.3.0

### Added

- An asynchronous FIFO for independent write/read clocks, with conservative
  full/empty signals, edge-level acceptance, registered read responses and
  coordinated-clear acknowledgments.
- Default array storage and optional block-memory and distributed-memory
  specializations for the asynchronous FIFO.
- Compile-time storage selection through `IFifoStorage<T, GEOMETRY>`,
  `FifoStorageGeometry<CAPACITY>` and a parameterless-construction constraint.
- Native Livt tests under `tests/fifo` covering two clock contexts, FIFO fill/drain,
  coordinated clear and reuse.
- FIFO usage, storage-selection, timing and clock-domain-crossing guidance.

### Changed

- Separated FIFO payload ownership from pointer/clear control without adding
  another public FIFO API or a runtime storage selector.
- Applied the Livt Design Guide to the new FIFO sources, with one component per
  file, documented responsibilities and explicit test initialization.

### Fixed

- Qualified five pre-existing Stack/List/Queue test constructors to resolve
  ambiguous names with the installed compiler; production behavior is unchanged.

### Known limitations

- Memory styles are hints. MAX 10 M9K mapping, resource counts, timing and
  physical CDC sign-off require a selected device and vendor-tool reports.
- Storage providers must have a combinational read tap. Scheduled or registered
  read RAMs from Livt.IO cannot be passed directly to this interface.
- Existing single-clock Fifo/Queue/Stack/List/CircularBuffer storage APIs are unchanged.
