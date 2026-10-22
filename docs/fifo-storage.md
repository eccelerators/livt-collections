# Selecting dual-clock FIFO storage

`DualClockFifo<T, CAPACITY, STORAGE>` owns its backing storage. The optional third
type argument selects the implementation at compile time; omitting it selects
`DualClockFifoArray<T, CAPACITY>`.

## Built-in choices

| Storage type | Use |
| --- | --- |
| `DualClockFifoArray<T, N>` | Let synthesis choose the memory resource; this is the default |
| `DualClockFifoBlockRam<T, N>` | Request block-memory storage |
| `DualClockFifoDistributedRam<T, N>` | Request distributed-memory storage |

For example, these are alternative declarations for a 256-value buffer:

```livt
fifo: DualClockFifo<logic[12], 256>
blockFifo: DualClockFifo<logic[12], 256, DualClockFifoBlockRam<logic[12], 256>>
distributedFifo: DualClockFifo<logic[12], 256, DualClockFifoDistributedRam<logic[12], 256>>
```

Use the selected type in the constructor as well. This fragment belongs inside
the owning component:

```livt
fifo: DualClockFifo<logic[12], 256, DualClockFifoBlockRam<logic[12], 256>>

new(writeContext: IContext, readContext: IContext,
	writeClear: bool, readClear: bool, push: bool, token: logic[12], pop: bool)
{
	this.fifo = new DualClockFifo<logic[12], 256, DualClockFifoBlockRam<logic[12], 256>>(
		writeContext, readContext, writeClear, readClear, push, token, pop)
}
```

All built-in choices preserve the FIFO's acceptance, response timing and clear
behavior. They allocate one payload store. See [using the FIFO](dual-clock-fifo.md)
for the transfer and reset protocols.

## Memory mapping

Array storage uses automatic inference; it does not force flip-flops. Block and
distributed types request a memory category without guaranteeing a particular
physical resource or resource count. Verify the mapping in the target tool's
memory and timing reports.

The provider exposes a combinational read tap, and the FIFO registers the response
in its read domain. Mapping this structure to synchronous block memory requires
the synthesis tool to recognize and combine the read register with the array.
Hierarchy and reset handling can affect that inference. Selecting the block type
alone is not proof of MAX 10 M9K mapping. If the target flow cannot map the structure,
a different storage integration must preserve the FIFO's timing contract.

## Custom storage providers

A custom provider must implement
`IFifoStorage<T, FifoStorageGeometry<CAPACITY>>` and support construction without
arguments. Supply its concrete type as `STORAGE`; the FIFO creates and exclusively
owns the instance in its write clock/reset context.

| Interface signal | Required behavior |
| --- | --- |
| `writeEnable` | Accept one write on a rising write edge when true and outside reset |
| `writeAddress` | Unsigned element index supplied by the FIFO, in 0..CAPACITY-1 |
| `writeData` | Payload to store at the accepting write edge |
| `readAddress` | Independent unsigned element index supplied by the FIFO |
| `readData` | Continuously expose the addressed element without a clocked delay |

Retain payload cells across reset; unwritten contents are unspecified. The FIFO
registers `readData` in its read context and handles clear through its pointers and
response validity. Its ownership protocol prevents reading unpublished cells or
overwriting unread cells; no additional read/write collision semantics are required.

Payload type, capacity identity and parameterless construction are checked at
compile time. Verify the provider's actual ordering, reset behavior and timing;
the interface type cannot establish those properties by itself.

A provider must not add read latency, scheduled calls or stalls. Livt.IO's
scheduled `BlockRam`/`DistributedRam` and registered-read `SynchronousRam` do not
meet this interface directly. Adding them behind a wrapper without adapting the
FIFO's internal timing would change its behavior.
