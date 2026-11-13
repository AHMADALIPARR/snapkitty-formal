# BLST-Verification integration

BLST-Verification is an external upstream proof effort. This scaffold does not
vendor it, invent a build target, or claim that the complete BLST implementation
has been proved.

- Clone the intended upstream repository at a reviewed commit.
- Record `git rev-parse HEAD`.
- Set `BLST_VERIFICATION_DIR` to that checkout.
- Read its current build instructions and run its documented verification target.
- Preserve commit identity, exact command, logs, and outputs in the assurance record.

The current adapter only checks that the checkout is configured. It deliberately
reports an adapter configuration check, not a cryptographic proof.
