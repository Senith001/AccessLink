/**
 * AccessLink Cloud Functions - Admin Role Management
 * 
 * SECURITY NOTES:
 * - Custom claims are only settable server-side via Admin SDK
 * - Clients cannot grant themselves elevated permissions
 * - After role changes, clients must refresh their ID token via getIdToken(true)
 * - Role revocation is effective on next token refresh
 * - The backend maintains dual consistency: custom claims + Firestore user docs
 */

const {initializeApp} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');
const {onCall, HttpsError} = require('firebase-functions/v2/https');

// Initialize Firebase Admin SDK
initializeApp();
const auth = getAuth();
const db = getFirestore();

/**
 * Sets a user's role via custom claims and mirrors to Firestore
 * 
 * @param {Object} data - Request data
 * @param {string} data.targetUid - UID of user to modify
 * @param {string} data.role - Role to assign ('admin', 'moderator', 'user')
 * @param {Object} context - Function context with auth info
 */
exports.setUserRole = onCall(async (request) => {
  const {data, auth: context} = request;
  const {targetUid, role} = data;

  // Verify caller is authenticated
  if (!context || !context.uid) {
    throw new HttpsError('unauthenticated', 'Must be authenticated to call this function');
  }

  // Verify caller has admin role in their custom claims
  // This enforces that only existing admins can grant roles
  // The first admin must be bootstrapped manually via scripts/bootstrapAdmin.js
  if (!context.token || context.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only admins can modify user roles');
  }

  // Validate input parameters
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid must be a valid string');
  }

  const validRoles = ['admin', 'moderator', 'user'];
  if (!role || !validRoles.includes(role)) {
    throw new HttpsError('invalid-argument', `role must be one of: ${validRoles.join(', ')}`);
  }

  try {
    // Verify target user exists
    await auth.getUser(targetUid);

    // Set custom claims (for storage.rules and immediate token access)
    await auth.setCustomUserClaims(targetUid, {role});

    // Mirror role to Firestore users document (for firestore.rules)
    // This keeps both auth claims and Firestore docs in sync
    await db.collection('users').doc(targetUid).set({
      role: role,
      updatedAt: new Date(),
      updatedBy: context.uid
    }, {merge: true});

    return {
      success: true,
      message: `Successfully set role '${role}' for user ${targetUid}`,
      note: 'User must refresh their ID token via getIdToken(true) for changes to take effect'
    };

  } catch (error) {
    console.error('Error setting user role:', error);
    
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'Target user not found');
    }
    
    throw new HttpsError('internal', 'Failed to set user role');
  }
});

/**
 * Removes a user's role (sets to 'user') via custom claims and mirrors to Firestore
 * 
 * @param {Object} data - Request data
 * @param {string} data.targetUid - UID of user to modify
 * @param {Object} context - Function context with auth info
 */
exports.removeUserRole = onCall(async (request) => {
  const {data, auth: context} = request;
  const {targetUid} = data;

  // Verify caller is authenticated
  if (!context || !context.uid) {
    throw new HttpsError('unauthenticated', 'Must be authenticated to call this function');
  }

  // Verify caller has admin role in their custom claims
  if (!context.token || context.token.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Only admins can modify user roles');
  }

  // Validate input parameters
  if (!targetUid || typeof targetUid !== 'string') {
    throw new HttpsError('invalid-argument', 'targetUid must be a valid string');
  }

  // Prevent self-removal of admin privileges
  if (targetUid === context.uid) {
    throw new HttpsError('permission-denied', 'Cannot remove your own admin privileges');
  }

  try {
    // Verify target user exists
    await auth.getUser(targetUid);

    // Set role to 'user' (effectively removing elevated privileges)
    await auth.setCustomUserClaims(targetUid, {role: 'user'});

    // Mirror to Firestore
    await db.collection('users').doc(targetUid).set({
      role: 'user',
      updatedAt: new Date(),
      updatedBy: context.uid
    }, {merge: true});

    return {
      success: true,
      message: `Successfully removed elevated privileges for user ${targetUid}`,
      note: 'User role revocation is effective on next token refresh'
    };

  } catch (error) {
    console.error('Error removing user role:', error);
    
    if (error.code === 'auth/user-not-found') {
      throw new HttpsError('not-found', 'Target user not found');
    }
    
    throw new HttpsError('internal', 'Failed to remove user role');
  }
});