# fathom-gate (reference backend)

A small Node service that acts as the relying party (RP) backend for the
Fathom Club app's World ID Proof of Presence factor.

## What it does

- `GET /health` returns the configured RP and app ids and whether a
  member is enrolled.
- `POST /rp-context` returns a fresh signed `rp_context` (signed with
  `@worldcoin/idkit-core`'s `signRequest`). The enrollment flow signs
  its action (`fathom-enroll`); session create/prove flows do not.
- `POST /verify` forwards the complete IDKit result to the World
  Developer Portal verify endpoint for this RP, then:
  - on `flow: "enroll"`, records the session id and the SHA-256 hash of
    the nullifier (first proof wins; a different human is rejected);
  - on `flow: "prove"`, requires the enrolled session id and rejects
    replayed session nullifiers.
- `POST /reset-enrollment` clears the enrolled binding and the replay
  store. This is a prototype affordance for a single-member deployment
  (the app's Reset enrollment calls it); it is not a production reset
  ceremony.

All POSTs require `Authorization: Bearer <FATHOM_GATE_TOKEN>`.
The service stores a session id and a nullifier hash only. A World ID
humanId never reaches it.

## Register your own portal app and RP

1. Create a World Developer Portal account and a team.
2. Create an app (mode: external, verification: cloud) named whatever
   you want your World App consent screen to show.
3. Configure World ID for the app. This creates a managed RP and
   returns the RP signing private key exactly once. Capture it into
   your secrets manager immediately; it cannot be shown again (it can
   be rotated, which invalidates the old key).
4. Wait until the RP registration status reads registered and synced
   in both production and staging.
5. Note the `app_…` id and the `rp_…` id.

## Run it

```
cp .env.example .env   # fill in your ids, signing key, and a bearer token
npm install
node server.mjs
```

Serve it over HTTPS to the phone. The app will not talk plain HTTP to a
remote host under iOS App Transport Security; put the service behind a
TLS-terminating proxy or tunnel you control, on a hostname the phone
can reach.

## Configure the app

At release time, inject (never commit):

- the gate base URL (the HTTPS origin above),
- the same bearer token as `FATHOM_GATE_TOKEN`,
- your portal app id.

See `project.yml` (the values arrive as build settings referenced from
the Info plist) and `scripts/release-ota.sh` (`EXTRA_BUILD_SETTINGS`).
