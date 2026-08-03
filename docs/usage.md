# Livt.Collections Usage

## Queue

```livt
using Livt.Collections.Queue

component QueueExample
{
	queue: Queue32

	new()
	{
		this.queue = new Queue32()
	}

	public fn Store(value: byte)
	{
		if (this.queue.IsFull() == false) {
			this.queue.Enqueue(value)
		}
	}
}
```

Select `Queue8`, `Queue16`, `Queue32`, or `Queue64` according to the required
capacity. All four components implement `IQueue` and have identical behavior.

## Stack

```livt
using Livt.Collections.Stack

component StackExample
{
	stack: Stack32

	new()
	{
		this.stack = new Stack32()
	}

	public fn Store(value: byte)
	{
		if (this.stack.IsFull() == false) {
			this.stack.Push(value)
		}
	}
}
```

Select `Stack8`, `Stack16`, `Stack32`, or `Stack64` according to the required
capacity. All four components implement `IStack` and have identical behavior.

## Circular Buffer

```livt
using Livt.Collections.Circular

component RecentBytes
{
	buffer: CircularBuffer16

	new()
	{
		this.buffer = new CircularBuffer16()
	}

	public fn Record(value: byte)
	{
		this.buffer.Write(value)
	}
}
```

Writing to a full circular buffer accepts the new value and discards the oldest
value. Select `CircularBuffer8`, `CircularBuffer16`, `CircularBuffer32`, or
`CircularBuffer64` according to the required history length.

## Fixed List

```livt
using Livt.Collections.List

component Samples
{
	values: FixedList16

	new()
	{
		this.values = new FixedList16()
	}

	public fn Add(value: byte)
	{
		if (this.values.IsFull() == false) {
			this.values.Add(value)
		}
	}
}
```

A fixed list maintains a logical count over fixed storage. `Get` and `Set` only
address elements below the current count.

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
