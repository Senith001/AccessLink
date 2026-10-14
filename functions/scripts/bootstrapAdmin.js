/**
 * ⚠️  CRITICAL SECURITY WARNING ⚠️
 * 
 * This script is for ONE-TIME MANUAL bootstrapping of the first admin user only.
 * 
 * REQUIREMENTS:
 * 1. Set GOOGLE_APPLICATION_CREDENTIALS environment variable to your service account key
 * 2. NEVER commit the service account JSON file to version control
 * 3. Run this script locally only, never in production environments
 * 4. Delete or secure the service account key after use
 * 
 * USAGE:
 *   export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"
 *   node scripts/bootstrapAdmin.js <target-uid>
 * 
 * This script will:
 * - Set custom claims role:'admin' for the target user
 * - Mirror the role to Firestore users/{uid}.role  
 * - Enable the user to call setUserRole/removeUserRole functions
 * 
 * After bootstrapping, all subsequent admin role changes should use the Cloud Functions.
 */

const {initializeApp, applicationDefault} = require('firebase-admin/app');
const {getAuth} = require('firebase-admin/auth');
const {getFirestore} = require('firebase-admin/firestore');

// Validate environment and arguments
if (!process.env.GOOGLE_APPLICATION_CREDENTIALS) {
  console.error('❌ ERROR: GOOGLE_APPLICATION_CREDENTIALS environment variable not set');
  console.error('Set it to point to your service account JSON file:');
  console.error('export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccount.json"');
  process.exit(1);
}

const targetUid = process.argv[2];
if (!targetUid) {
  console.error('❌ ERROR: Target UID is required');
  console.error('Usage: node scripts/bootstrapAdmin.js <target-uid>');
  process.exit(1);
}

// Initialize Firebase Admin SDK with application default credentials
initializeApp({
  credential: applicationDefault()
});

const auth = getAuth();
const db = getFirestore();

async function bootstrapFirstAdmin(uid) {
  try {
    console.log(`🔄 Bootstrapping admin role for user: ${uid}`);
    
    // Verify user exists
    const userRecord = await auth.getUser(uid);
    console.log(`✅ User found: ${userRecord.email || userRecord.uid}`);
    
    // Set custom claims
    await auth.setCustomUserClaims(uid, {role: 'admin'});
    console.log('✅ Custom claims set: role = admin');
    
    // Mirror to Firestore
    await db.collection('users').doc(uid).set({
      role: 'admin',
      bootstrappedAt: new Date(),
      bootstrappedBy: 'manual-script'
    }, {merge: true});
    console.log('✅ Firestore user document updated');
    
    console.log('🎉 SUCCESS: Admin role bootstrapped successfully');
    console.log('');
    console.log('NEXT STEPS:');
    console.log('1. The user must sign out and sign back in (or call getIdToken(true))');
    console.log('2. Secure or delete the service account key file');
    console.log('3. Use the Cloud Functions for all subsequent role changes');
    
  } catch (error) {
    console.error('❌ ERROR during bootstrap:', error.message);
    
    if (error.code === 'auth/user-not-found') {
      console.error('The specified user UID does not exist in Firebase Auth');
    } else if (error.code === 'auth/invalid-uid') {
      console.error('The provided UID is invalid');
    }
    
    process.exit(1);
  }
}

// Confirm before proceeding
console.log('⚠️  ADMIN BOOTSTRAP SCRIPT');
console.log(`Target UID: ${targetUid}`);
console.log('This will grant ADMIN privileges to the specified user.');
console.log('');

// Run the bootstrap
bootstrapFirstAdmin(targetUid);