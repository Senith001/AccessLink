# AccessLink Cloud Functions

## Overview

This directory contains Cloud Functions for AccessLink admin role management using Firebase Admin SDK.

## Deployment

Deploy the functions with:
```bash
firebase deploy --only functions
```

## Functions

### setUserRole
- **Type**: Callable HTTPS function
- **Purpose**: Sets user roles via custom claims and mirrors to Firestore
- **Security**: Only callable by existing admins
- **Parameters**:
  - `targetUid` (string): UID of user to modify
  - `role` (string): Role to assign ('admin', 'moderator', 'user')

### removeUserRole
- **Type**: Callable HTTPS function  
- **Purpose**: Removes elevated privileges (sets role to 'user')
- **Security**: Only callable by existing admins, cannot remove own admin role
- **Parameters**:
  - `targetUid` (string): UID of user to modify

## Bootstrap First Admin

**CRITICAL**: The first admin must be bootstrapped manually using a one-off script.

### Prerequisites
1. Obtain a Firebase service account key JSON file
2. Set `GOOGLE_APPLICATION_CREDENTIALS` environment variable to point to the key file
3. **NEVER commit the service account key to version control**

### Bootstrap Process
```bash
# Set environment variable (replace with your actual path)
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/your/serviceAccount.json"

# Run bootstrap script with target UID
node scripts/bootstrapAdmin.js <target-uid>
```

### Security Notes
- Custom claims are only settable server-side via Admin SDK
- Clients cannot grant themselves elevated permissions  
- After role changes, clients must refresh their ID token via `getIdToken(true)`
- Role revocation is effective on next token refresh
- The backend maintains dual consistency: custom claims + Firestore user docs