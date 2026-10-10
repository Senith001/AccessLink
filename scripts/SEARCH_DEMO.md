# Search Discovery Demo Data

The dataset in `lib/tools/search_demo_places.json` contains 18 fictional places
across Colombo, Malabe, Battaramulla, Nugegoda, Gampaha, Negombo, Kandy, Galle,
Matara, Kurunegala and Jaffna. Documents have `isDemo: true` and descriptions
identify them as fictional. Accessibility features, coordinates and opening hours are sample
scenarios. They do not describe verified real businesses.

The seeder targets Firebase project `access-link-005` and uses the existing
`places` schema: GeoPoint location, nested accessibility maps, feature flags,
score, category, city/district, contact, opening hours and timestamps. Scores
use the app's current formula: available features / 7, rounded to a percentage.
Every demo feature and place is unverified.

Validate locally (no credentials or network required):

```sh
node scripts/seed_search_demo.mjs --dry-run
```

Add data using an authorized Firebase CLI login with Firestore write access:

```sh
firebase login
node scripts/seed_search_demo.mjs --write
```

The script reuses the installed CLI's login, or accepts a short-lived
`FIRESTORE_ACCESS_TOKEN` environment variable. No credentials are stored in the
repository. Existing documents are skipped, missing categories are created,
and all writes use create-only preconditions. Re-running does not overwrite
existing places, categories or demo documents. It reads back the demo records
to check names, coordinates, scores and verification status.

Update only the names of the existing sample places to match the dataset:

```sh
node scripts/seed_search_demo.mjs --rename
```

This updates `name` and `nameLower` only, checks the sample-data markers before
writing, and verifies that every other field is unchanged. Document IDs stay
the same, preserving favourite references.

Suggested demonstration:

- Search `hospital` and compare accessibility scores.
- Choose Colombo district, then Malabe city, to narrow results.
- Filter by Bank or Restaurant and combine accessibility filters.
- Sort by best score and save/remove a favourite.
- Show nearby results with GPS around Colombo or Malabe. Other areas need a
  device location near those demo coordinates to appear as nearby results.

The original database records are kept. This script does not add users,
reviews, favourites, or verification records.
