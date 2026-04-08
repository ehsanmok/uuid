"""Throughput benchmarks for the uuid library.

Measures performance of UUID generation, parsing, and formatting using the
standard `std.benchmark` harness with anti-optimization guards (`keep`,
`clobber_memory`).

Run with:

    mojo -I . benchmark/bench.mojo

or via pixi:

    pixi run bench

Expected throughput targets on a modern CPU:

    | Operation           | Target    |
    |---------------------|-----------|
    | uuid4() generate    | < 100 ns  |
    | uuid7() generate    | < 150 ns  |
    | UUID.parse()        | < 80 ns   |
    | String(uuid)        | < 50 ns   |
    | uuid4_batch[100]()  | < 5 us    |
"""

from std.benchmark import (
    Bench,
    BenchConfig,
    Bencher,
    BenchId,
    ThroughputMeasure,
    BenchMetric,
    keep,
    clobber_memory,
)
from uuid import UUID, uuid4, uuid4_batch, uuid7

alias KNOWN_STR = "550e8400-e29b-41d4-a716-446655440000"


def main() raises:
    var bench = Bench(BenchConfig(max_iters=10_000))

    # =========================================================================
    # UUID v4 generation
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid4_gen(mut b: Bencher) raises:
        @parameter
        @always_inline
        def call_fn() raises:
            var u = uuid4()
            keep(u.bytes)

        b.iter[call_fn]()

    bench.bench_function[bench_uuid4_gen](
        BenchId("generate", "uuid4"),
        ThroughputMeasure(BenchMetric.bytes, 16),
    )

    # =========================================================================
    # UUID v7 generation
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid7_gen(mut b: Bencher) raises:
        @parameter
        @always_inline
        def call_fn() raises:
            var u = uuid7()
            keep(u.bytes)

        b.iter[call_fn]()

    bench.bench_function[bench_uuid7_gen](
        BenchId("generate", "uuid7"),
        ThroughputMeasure(BenchMetric.bytes, 16),
    )

    # =========================================================================
    # Batch v4 generation (100 at once)
    # =========================================================================

    @parameter
    @always_inline
    def bench_uuid4_batch(mut b: Bencher) raises:
        @parameter
        @always_inline
        def call_fn() raises:
            clobber_memory()
            var batch = uuid4_batch[100]()
            keep(batch[0].bytes)

        b.iter[call_fn]()

    bench.bench_function[bench_uuid4_batch](
        BenchId("generate", "uuid4_batch_100"),
        ThroughputMeasure(BenchMetric.bytes, 16 * 100),
    )

    # =========================================================================
    # Parse from string
    # =========================================================================

    @parameter
    @always_inline
    def bench_parse(mut b: Bencher) raises:
        @parameter
        @always_inline
        def call_fn() raises:
            clobber_memory()
            var u = UUID.parse(KNOWN_STR)
            keep(u.bytes)

        b.iter[call_fn]()

    bench.bench_function[bench_parse](
        BenchId("parse", "UUID.parse"),
        ThroughputMeasure(BenchMetric.bytes, 36),
    )

    # =========================================================================
    # Format to string
    # =========================================================================

    @parameter
    @always_inline
    def bench_format(mut b: Bencher) raises:
        var u = uuid4()

        @parameter
        @always_inline
        def call_fn() raises:
            clobber_memory()
            var s = String(u)
            keep(s.as_bytes().unsafe_ptr())

        b.iter[call_fn]()

    bench.bench_function[bench_format](
        BenchId("format", "String(UUID)"),
        ThroughputMeasure(BenchMetric.bytes, 36),
    )

    # =========================================================================
    # to_hex (no dashes)
    # =========================================================================

    @parameter
    @always_inline
    def bench_to_hex(mut b: Bencher) raises:
        var u = uuid4()

        @parameter
        @always_inline
        def call_fn() raises:
            clobber_memory()
            var h = u.to_hex()
            keep(h.as_bytes().unsafe_ptr())

        b.iter[call_fn]()

    bench.bench_function[bench_to_hex](
        BenchId("format", "UUID.to_hex"),
        ThroughputMeasure(BenchMetric.bytes, 32),
    )

    print(bench)
