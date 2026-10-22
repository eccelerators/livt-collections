# Changelog

## 1.3.0

### Added

- `DualClockFifo<T, CAPACITY, STORAGE>` for independent write/read clocks,
  with conservative full/empty signals, edge-level acceptance, registered read
  responses and coordinated-clear acknowledgments.
- Default `DualClockFifoArray<T, CAPACITY>` storage; existing two-argument FIFO
  declarations retain their API and timing.
- Compile-time storage selection through `IFifoStorage<T, GEOMETRY>`,
  `FifoStorageGeometry<CAPACITY>` and a parameterless-construction constraint.
- `DualClockFifoBlockRam` and `DualClockFifoDistributedRam` specializations that
  request synthesis styles while preserving the array's access contract.
- Livt tests under `tests/fifo` covering two clock contexts, FIFO fill/drain, coordinated
  clear and reuse, registered in the package test suite.
- FIFO usage, storage-selection, timing and clock-domain-crossing guidance.

### Changed

- FIFO payload ownership is separated from pointer/clear control, without
  adding a second public FIFO API or a runtime storage selector.
- New FIFO sources follow the Livt Design Guide; each component has its own
  file, documented responsibilities and explicit test initialization.

### Fixed

- Qualified five pre-existing Stack/List/Queue test constructors to resolve
  ambiguous names with the installed compiler; production behavior is unchanged.

### Known limitations

- Memory styles are hints. MAX 10 M9K mapping, resource counts, timing and
  physical CDC sign-off require a selected device and vendor-tool reports.
- Storage providers must have a combinational read tap. Scheduled or registered
  read RAMs from Livt.IO cannot be passed directly to this interface.
- Run `livt test` for the package suite, including the dual-clock FIFO test.
- Existing single-clock Fifo/Queue/Stack/List/CircularBuffer storage APIs are unchanged.
