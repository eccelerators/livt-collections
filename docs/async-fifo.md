# Asynchronous FIFO

A FIFO stores values in the order they arrive: the first value written is the
first value read. An **asynchronous FIFO**, lets the writer
and reader use independent clocks with unrelated frequencies or phases.

`Livt.Collections.AsyncFifo` transfers an ordered stream between those clock
domains and buffers temporary differences in their processing rates. Typical uses
include receiving sensor samples on an external clock, passing received network
data to a processing clock, or buffering pixels between an input and image pipeline.

The buffer has a fixed capacity. It can absorb bursts, but if the writer remains
faster than the reader, it eventually fills. The producer must handle rejected
writes or stop offering data until space becomes available.

## Choosing a FIFO

| Component | Use it for |
| --- | --- |
| `Fifo<T, CAPACITY>` | Cycle-level transfers within one clock domain |
| `AsyncFifo<T, CAPACITY, STORAGE>` | Cycle-level transfers between independent write/read clocks |
| `Queue<T, CAPACITY>` | Scheduled enqueue/dequeue calls within one clock domain |

`AsyncFifo` preserves payload values and ordering. It does not interpret
packets, pixels, frame boundaries or application commands.

## Configuration and wiring

- `T` is the synthesizable payload type, such as `byte` or `logic[12]`.
- `CAPACITY` is the number of stored values. It defaults to 256 and must be a
  power of two between 2 and 1,048,576. Choose a size that fits the target FPGA.
- `STORAGE` selects the backing component. It defaults to
  `AsyncFifoArray<T, CAPACITY>`; most callers can omit it.

The following fragment belongs inside the component that owns the FIFO:

```livt
fifo: AsyncFifo<logic[12], 256>

new(writeContext: IContext, readContext: IContext,
	writeClear: bool, readClear: bool,
	push: bool, token: logic[12], pop: bool)
{
	this.fifo = new AsyncFifo<logic[12], 256>(
		writeContext, readContext, writeClear, readClear, push, token, pop)
}
```

This creates a buffer for 256 twelve-bit values. Bind the producer to
`writeContext` and the consumer to `readContext`. Drive each request and clear
signal in its corresponding domain. The FIFO owns its storage and both endpoints.

## Writing and reading

| Signal | Clock domain | How to use it |
| --- | --- | --- |
| `push`, `data` | Write | Present a value and assert `push` before a rising write edge |
| `pushAccepted` | Write | Sample at that edge to determine whether the value was stored |
| `full` | Write | No writable space is currently visible to the writer |
| `pop` | Read | Assert before a rising read edge to request the next value |
| `popAccepted` | Read | Sample at that edge to determine whether the request was accepted |
| `popValid`, `popData` | Read | Response produced after an accepted read edge; consume at the next read edge |
| `empty` | Read | No readable value is currently visible to the reader |
| `writeClear`, `readClear` | Respective domains | Request coordinated clear as described below |
| `writeCleared`, `readCleared` | Respective domains | Acknowledge that the local clear request was sampled |

For each value the producer wants to write, keep `push` and `data` valid at the
write edge and advance only if `pushAccepted` is true. A rejected write stores
nothing. Keeping `push` asserted can transfer one value on every write edge when
space is available; holding the same data across accepted edges writes duplicates.

The consumer asserts `pop` only when it has room for the response. On an edge
where `popAccepted` is true, the FIFO captures the next value. During the following
cycle `popValid` is true and `popData` holds that value. The consumer samples it
at the next read edge. Consecutive accepted requests produce consecutive responses.

There is no response-ready input: an accepted read cannot be stalled or withdrawn.
Reserve space before requesting it, including room for any response already in
flight. Ignore `popData` when `popValid` is false. A rejected read produces no
valid response. Reset and clear suppress transfers.

## Status and latency

The FIFO supports up to one accepted write per write edge and one accepted read
per read edge. Empty FIFOs do not bypass newly written data directly to the reader.

Read/write positions cross through synchronization stages, so `full` and `empty`
are conservative: the writer may still see full briefly after a read, and the
reader may still see empty briefly after a write. Use the local acceptance signals
to decide whether transfers occurred. Do not treat either status as a global
occupancy count or sample it directly in another clock domain.

Capacity counts values in storage. A value already removed into the registered
read response is additional in-flight data outside that count.

## Startup, clear and reset

Clear discards buffered values and invalidates the read response. It resets
control state without erasing payload cells. The application must coordinate
both domains; independently resetting one side during active traffic is unsupported.

At startup, assert both context resets over active clock edges, then perform this
clear sequence before starting traffic. Use the same sequence for later clears:

1. Stop new writes and read requests. Consume or discard any outstanding response.
2. Assert `writeClear` and `readClear` as levels synchronized to their respective
   domains. Hold both until a controller has coherently observed both local
   acknowledgments, `writeCleared` and `readCleared`.
3. Release both clear requests synchronously in their respective domains. Wait
   for both acknowledgments to return false before enabling traffic again.

Synchronize the acknowledgment signals before observing them in another domain.
A stopped clock cannot newly acknowledge clear: keep traffic stopped and clear
asserted until both domains can participate. Condition physical reset release
for each domain, and stop traffic in both domains before changing either reset.

## Selecting storage

Omit the third argument for automatic memory inference, or request a storage style:

```livt
fifo: AsyncFifo<logic[12], 256, AsyncFifoBlockRam<logic[12], 256>>
```

`AsyncFifoDistributedRam` requests distributed memory. Compatible custom
providers can also be selected. Memory styles are synthesis preferences; verify
the actual mapping for your target. See [storage selection](fifo-storage.md) for
examples and the custom-provider contract.

For FPGA implementation, declare both clocks, preserve the pointer synchronizers
and constrain the clock-domain crossings. See [hardware integration](hardware-notes.md#asynchronous-fifo).

## Tests

The Livt test and read-domain monitor live in `tests/fifo`. Run the package suite:

```sh
livt test
```
