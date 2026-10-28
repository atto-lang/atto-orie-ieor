# ORIE Simulation

Native Oreslang-only discrete-event and streaming reference models.

- `event_calendar`: stable sorted timestamp insertion and due count.
- `window_stats`: bounded batch rolling-sum reference.
- `queueing`: sorted-arrival deterministic FIFO G/G/1 queue trace.
- `stream_window`: bounded incremental sum with immutable snapshots.

No actual actor workers, `Channel<T>` backpressure, cancellation or physical
arena-retirement proof is claimed. Source prototypes remain unexecuted.
