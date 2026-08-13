# Cryptographic Signing Chain

To guarantee the integrity of the MBSD overlay and prevent rogue firmware execution, all deployment artifacts must be cryptographically signed before deployment.

MBSD uses **`signify(1)`** (Ed25519) as the cryptographic root-of-trust, maintaining consistency with Timelabs-style minimalism.

## 1. Key Generation
The private signing key must be generated and stored securely off-device (e.g., in a secure vault or HSM).
```bash
# Generate the Ed25519 keypair
signify -G -p mbsd-release.pub -s mbsd-release.sec
```

## 2. Artifact Signing
The `make release` pipeline generates the final `mbsd-overlay.itb` FIT image. This image must be signed.
```bash
# Sign the FIT image
signify -S -s mbsd-release.sec -m release/mbsd-overlay.itb -x release/mbsd-overlay.itb.sig
```

## 3. Verification
During the `omnia-playbook` provisioning sequence, or before manual flash via TFTP/sysupgrade, the signature must be verified against the public key.
```bash
# Verify the FIT image
signify -V -p mbsd-release.pub -m release/mbsd-overlay.itb -x release/mbsd-overlay.itb.sig
```

## Key Rotation Protocol
In the event of key compromise, the following operational procedure must be strictly followed:
1. **Quorum Approval:** Generation of a new root keypair requires explicit `SA/MIO` owner approval via a `TRAE:` prefixed commit.
2. **Out-of-Band Distribution:** The new trusted public key must be distributed to all `omnia-playbook` provisioning servers out-of-band (i.e., not via the compromised channel).
3. **Implicit Revocation Semantic:** Active MBSD nodes running Model B (local SquashFS) will continue to boot and operate with the old firmware. Because local flashing is a human-gated operation on this hardware, a node cannot automatically detect a compromised key until a human initiates a re-image sequence. The old key is considered revoked purely by its removal from the trusted provisioning servers.
