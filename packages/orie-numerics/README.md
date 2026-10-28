# ORIE Numerics

Native Oreslang-only userland numerical methods.

- `dense_matrix`: bounded integer dot/multiply reference.
- `csr_matrix`: bounded integer CSR matvec.
- `linear_solve`: bounded f64 Gaussian elimination with partial pivoting
  and original-residual validation. No general purpose stable factorization.

Source prototypes, not native Oreslang compiler/guest verified.
