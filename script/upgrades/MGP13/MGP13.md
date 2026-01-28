### MGP-13: Update spreads for selected pools

This proposal updates the spread for selected BiPoolManager exchanges using the new `setSpread` function.

#### Changes

- Temporarily upgrade the BiPoolManager implementation to enable `setSpread`, then revert to the prior implementation.
- Update pool spreads as defined in `MGP13Config`.
