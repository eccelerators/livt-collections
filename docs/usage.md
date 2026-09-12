# Livt.Collections Usage

## Queue

```livt
using Livt.Collections

component QueueExample
{
	queue: Queue<byte, 32>

	new()
	{
		this.queue = new Queue<byte, 32>()
	}

	public fn TryStore(value: byte) bool
	{
		return this.queue.TryEnqueue(value)
	}
}
```

Use `Queue<T, CAPACITY>` for scheduled application-level access. Capacity is a
positive compile-time value, defaults to 64, and need not be a power of two.
`Queue8`, `Queue16`, `Queue32`, and `Queue64` are thin byte specializations
with the same `IQueue<byte>` contract, not separate storage implementations.

`TryDequeue(value: out T)` returns success and assigns zero on failure. A
successful zero payload is therefore distinguishable from an empty queue.
`GetCount()` and `GetSpace()` are snapshots, not reservations: use the Try
operation's result rather than a separate check followed by a mutation.

For hardware-level producer/consumer wiring, use `Fifo<T, CAPACITY>` directly.
It accepts requests at a clock edge and can push and pop together. Queue wraps
that core with scheduled calls and arbitration; it is more convenient for
application logic but introduces additional control state and call latency.
Neither component crosses clock domains.

## Stack

```livt
using Livt.Collections.Stack

component StackExample
{
	stack: Stack<int, 12>

	new()
	{
		this.stack = new Stack<int, 12>()
	}

	public fn Store(value: int)
	{
		if (this.stack.IsFull() == false) {
			this.stack.Push(value)
		}
	}
}
```

Use `Stack<T, CAPACITY>` for custom element types or capacities. `Stack8`,
`Stack16`, `Stack32`, and `Stack64` are thin byte specializations implementing
`IStack<byte>`.

## Circular Buffer

```livt
using Livt.Collections.Circular

component RecentBytes
{
	buffer: CircularBuffer<byte, 12>

	new()
	{
		this.buffer = new CircularBuffer<byte, 12>()
	}

	public fn Record(value: byte)
	{
		this.buffer.Write(value)
	}
}
```

Writing to a full circular buffer accepts the new value and discards the oldest
value. Capacity need not be a power of two. The named 8/16/32/64 components are
thin byte specializations implementing `ICircularBuffer<byte>`.

## List

```livt
using Livt.Collections.List

component Samples
{
	values: List<int, 12>

	new()
	{
		this.values = new List<int, 12>()
	}

	public fn Add(value: int)
	{
		if (this.values.IsFull() == false) {
			this.values.Add(value)
		}
	}
}
```

A fixed list maintains a logical count over fixed storage. `Get` and `Set` only
address elements below the current count. `List8`, `List16`,
`List32`, and `List64` remain convenient byte specializations.

## Bit Set

```livt
using Livt.Collections.BitSet

component StatusFlags
{
	flags: BitSet8

	new()
	{
		this.flags = new BitSet8()
	}

	public fn MarkReady()
	{
		this.flags.Set(0)
	}
}
```

`BitSet8` provides eight independently addressable boolean flags, reports its
fixed size through `GetCapacity()`, and exposes an integer bit-mask view through
`GetValue()`.
