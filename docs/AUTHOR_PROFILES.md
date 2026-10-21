# Public author profiles

Avatar and name navigation uses `video.author.id`. Property contact navigation
uses `property.consultantId`. These are independent relationships and may refer
to different people. An ordinary poster does not need a consultant row.

## Required backend contract

- `GET /api/v1/authors/:authorId` returns the public profile, public video count,
  follower count, caller's follow state and nullable `consultantId`.
- `GET /api/v1/authors/:authorId/videos` returns a cursor-paginated list filtered
  by `videos.author_id`, ordered by published time and ID. Visibility is enforced
  by PostgreSQL RLS. The request-query allowlist permits pagination on this route.
- A profile's `consultantId`, when present, is that author's own identity. It is
  never copied from the property. Public profiles contain no private contacts.

The app requires these endpoints. There is no compatibility scan of the public
feed, no reconstruction of profiles from a video, and no fallback to a property
consultant. Missing endpoints and server failures remain visible errors with a
retry action. Counts come from the backend and are required integers.

## Rollout status — 21 October 2026

The original error was a rollout mismatch: the client used the new endpoints
while the deployed backend still lacked them. Production returned 404 for the
profile and 400 for the paginated author-video URL. Database records were intact.

The temporary Android compatibility path has been removed from source at the
owner's request. Its earlier 0.2.2+4 APK is a historical workaround build, not
acceptance of this final implementation. No app installation or emulator change
is part of the backend-only completion work.

Production completion requires deploying the backend commit and passing the
direct endpoint acceptance check. Local test success or a Git push alone does
not prove production is fixed. Railway previously used CLI uploads; automatic
deployment also requires a verified GitHub source connection to the correct
repository and branch. Until both deployment and live acceptance succeed, the
production fix is **incomplete**. No database migration or seed is required.

## Verification

From `xland-server`, `npm run test:authors` provisions an isolated local test
database and checks non-consultant profiles, consultant identity, public video
filtering, pagination, missing IDs and caller-specific follow state.

From `xland-mobile`, run the author data and widget tests. They verify direct
endpoint use, error propagation without fallback, correct avatar/name routing,
follow state and property contact routing. The opt-in production check is:

```powershell
flutter test --no-pub --dart-define=XLAND_LIVE_API_BASE_URL=https://xland-server-production.up.railway.app/api/v1 test/data/author_profile_live_test.dart
```

This check performs GET requests only, requires the real author endpoints and
must fail against the old server. Without the define it is skipped.
