# Firebase Security Rules Tests

This directory contains tests for Firebase Security Rules using the @firebase/rules-unit-testing package.

## Setup

```bash
npm install
```

## Running Tests

Run tests with the Firebase emulator:

```bash
firebase emulators:exec --only firestore,storage --project demo-accesslink 'npm test'
```

## Test Coverage

- **Firestore Rules**: Tests for contributions, accessibility_features, places, and reports collections
- **Storage Rules**: Tests for place_photo_submissions and place_photos storage paths (**OBSOLETE FOR PHOTOS** - Cloudinary now handles photo storage; these tests are retained for reference)

## Project Structure

- `firestore.test.js` - Firestore security rules tests
- `storage.test.js` - Storage security rules tests
- `package.json` - Dependencies and test scripts