import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'fs';
import { doc, setDoc, getDoc, updateDoc, deleteDoc, collection, addDoc } from 'firebase/firestore';
import { afterAll, beforeAll, describe, it } from 'vitest';

const PROJECT_ID = 'demo-accesslink';

// Read the rules from the parent directory
const firestoreRules = readFileSync('../firestore.rules', 'utf8');

let testEnv;

beforeAll(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: firestoreRules,
    },
  });
});

afterAll(async () => {
  await testEnv.cleanup();
});

// Helper function to get authenticated context
function getFirestore(auth) {
  return testEnv.authenticatedContext(auth?.uid || 'anonymous', auth?.customClaims).firestore();
}

// Helper function to get unauthenticated context
function getUnauthenticatedFirestore() {
  return testEnv.unauthenticatedContext().firestore();
}

// Helper to create user doc (for role checking)
async function createUserDoc(uid, role = 'user') {
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const adminDb = context.firestore();
    await setDoc(doc(adminDb, 'users', uid), { role });
  });
}

describe('Firestore Security Rules', () => {
  beforeAll(async () => {
    await testEnv.clearFirestore();
  });

  describe('Contributions Collection', () => {
    describe('(a) Unauthenticated access', () => {
      it('should deny unauthenticated read of contributions', async () => {
        const db = getUnauthenticatedFirestore();
        await assertFails(getDoc(doc(db, 'contributions', 'test-contrib')));
      });

      it('should deny unauthenticated create of contributions', async () => {
        const db = getUnauthenticatedFirestore();
        await assertFails(setDoc(doc(db, 'contributions', 'test-contrib'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        }));
      });
    });

    describe('(b) Authenticated user creation rules', () => {
      it('should allow user to create contribution with their uid and pending status', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await assertSucceeds(setDoc(doc(db, 'contributions', 'contrib1'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1',
          description: 'Test contribution'
        }));
      });

      it('should deny user creating contribution with different uid', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await assertFails(setDoc(doc(db, 'contributions', 'contrib2'), {
          submittedBy: 'user2', // Different from authenticated user
          status: 'pending',
          placeId: 'place1'
        }));
      });

      it('should deny user creating contribution with non-pending status', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await assertFails(setDoc(doc(db, 'contributions', 'contrib3'), {
          submittedBy: 'user1',
          status: 'approved', // Not pending
          placeId: 'place1'
        }));
      });
    });

    describe('(c) User read access to own submissions', () => {
      it('should allow user to read their own contributions', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        // First create a contribution
        await setDoc(doc(db, 'contributions', 'contrib4'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // Then read it
        await assertSucceeds(getDoc(doc(db, 'contributions', 'contrib4')));
      });

      it('should deny user reading other user contributions', async () => {
        await createUserDoc('user1');
        await createUserDoc('user2');
        
        // User1 creates contribution
        const db1 = getFirestore({ uid: 'user1' });
        await setDoc(doc(db1, 'contributions', 'contrib5'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // User2 tries to read it
        const db2 = getFirestore({ uid: 'user2' });
        await assertFails(getDoc(doc(db2, 'contributions', 'contrib5')));
      });
    });

    describe('(d) Non-staff cannot update/delete submissions', () => {
      it('should deny non-staff user updating contributions', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        // Create contribution
        await setDoc(doc(db, 'contributions', 'contrib6'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // Try to update it (no self-approve)
        await assertFails(updateDoc(doc(db, 'contributions', 'contrib6'), {
          status: 'approved'
        }));
      });

      it('should deny non-staff user deleting contributions', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await setDoc(doc(db, 'contributions', 'contrib7'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        await assertFails(deleteDoc(doc(db, 'contributions', 'contrib7')));
      });

      it('should deny non-staff writing to places', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await assertFails(setDoc(doc(db, 'places', 'place1'), {
          name: 'Test Place',
          address: 'Test Address'
        }));
      });
    });

    describe('(e) Staff access via role doc and custom claims', () => {
      it('should allow admin (via role doc) to read all contributions', async () => {
        await createUserDoc('admin1', 'admin');
        
        // Create contribution as user
        await createUserDoc('user1');
        const userDb = getFirestore({ uid: 'user1' });
        await setDoc(doc(userDb, 'contributions', 'contrib8'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // Admin reads it
        const adminDb = getFirestore({ uid: 'admin1' });
        await assertSucceeds(getDoc(doc(adminDb, 'contributions', 'contrib8')));
      });

      it('should allow moderator (via custom claims) to update contributions', async () => {
        // Create contribution as user
        await createUserDoc('user1');
        const userDb = getFirestore({ uid: 'user1' });
        await setDoc(doc(userDb, 'contributions', 'contrib9'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // Moderator (via custom claim) updates it
        const modDb = getFirestore({ uid: 'mod1', customClaims: { role: 'moderator' } });
        await assertSucceeds(updateDoc(doc(modDb, 'contributions', 'contrib9'), {
          status: 'approved'
        }));
      });

      it('should allow staff to delete contributions', async () => {
        // Create contribution as user
        await createUserDoc('user1');
        const userDb = getFirestore({ uid: 'user1' });
        await setDoc(doc(userDb, 'contributions', 'contrib10'), {
          submittedBy: 'user1',
          status: 'pending',
          placeId: 'place1'
        });
        
        // Admin deletes it
        await createUserDoc('admin1', 'admin');
        const adminDb = getFirestore({ uid: 'admin1' });
        await assertSucceeds(deleteDoc(doc(adminDb, 'contributions', 'contrib10')));
      });

      it('should allow staff to update places', async () => {
        await createUserDoc('admin1', 'admin');
        const adminDb = getFirestore({ uid: 'admin1' });
        
        await assertSucceeds(setDoc(doc(adminDb, 'places', 'place2'), {
          name: 'Staff Place',
          address: 'Staff Address'
        }));
      });
    });
  });

  describe('Accessibility Features Collection', () => {
    describe('Similar rules as contributions', () => {
      it('should deny unauthenticated read/create', async () => {
        const db = getUnauthenticatedFirestore();
        await assertFails(getDoc(doc(db, 'accessibility_features', 'test')));
        await assertFails(setDoc(doc(db, 'accessibility_features', 'test'), {
          submittedBy: 'user1',
          status: 'pending'
        }));
      });

      it('should allow authenticated user to create with their uid and pending status', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        await assertSucceeds(setDoc(doc(db, 'accessibility_features', 'af1'), {
          submittedBy: 'user1',
          status: 'pending',
          featureType: 'ramp',
          description: 'Wheelchair ramp'
        }));
      });

      it('should deny user creating with wrong uid or status', async () => {
        await createUserDoc('user1');
        const db = getFirestore({ uid: 'user1' });
        
        // Wrong submittedBy
        await assertFails(setDoc(doc(db, 'accessibility_features', 'af2'), {
          submittedBy: 'user2',
          status: 'pending',
          featureType: 'ramp'
        }));
        
        // Wrong status
        await assertFails(setDoc(doc(db, 'accessibility_features', 'af3'), {
          submittedBy: 'user1',
          status: 'approved',
          featureType: 'ramp'
        }));
      });

      it('should allow staff to manage accessibility features', async () => {
        // Create as user
        await createUserDoc('user1');
        const userDb = getFirestore({ uid: 'user1' });
        await setDoc(doc(userDb, 'accessibility_features', 'af4'), {
          submittedBy: 'user1',
          status: 'pending',
          featureType: 'ramp'
        });
        
        // Staff can read, update, delete
        const staffDb = getFirestore({ uid: 'staff1', customClaims: { role: 'admin' } });
        await assertSucceeds(getDoc(doc(staffDb, 'accessibility_features', 'af4')));
        await assertSucceeds(updateDoc(doc(staffDb, 'accessibility_features', 'af4'), {
          status: 'approved'
        }));
      });
    });
  });

  describe('(f) Places Collection - Public Read, Staff Write', () => {
    it('should allow public read of places', async () => {
      // Create place as admin
      await createUserDoc('admin1', 'admin');
      const adminDb = getFirestore({ uid: 'admin1' });
      await setDoc(doc(adminDb, 'places', 'public-place'), {
        name: 'Public Place',
        address: 'Public Address'
      });
      
      // Unauthenticated can read
      const unauthDb = getUnauthenticatedFirestore();
      await assertSucceeds(getDoc(doc(unauthDb, 'places', 'public-place')));
      
      // Regular user can read
      await createUserDoc('user1');
      const userDb = getFirestore({ uid: 'user1' });
      await assertSucceeds(getDoc(doc(userDb, 'places', 'public-place')));
    });

    it('should deny non-staff write to places', async () => {
      await createUserDoc('user1');
      const userDb = getFirestore({ uid: 'user1' });
      
      await assertFails(setDoc(doc(userDb, 'places', 'user-place'), {
        name: 'User Place'
      }));
    });

    it('should allow staff write to places', async () => {
      await createUserDoc('admin1', 'admin');
      const adminDb = getFirestore({ uid: 'admin1' });
      
      await assertSucceeds(setDoc(doc(adminDb, 'places', 'admin-place'), {
        name: 'Admin Place'
      }));
    });
  });

  describe('(g) Reports Collection - Regression Test', () => {
    it('should allow authenticated user to create report with pending status', async () => {
      await createUserDoc('user1');
      const db = getFirestore({ uid: 'user1' });
      
      await assertSucceeds(setDoc(doc(db, 'reports', 'report1'), {
        reportedBy: 'user1',
        status: 'pending',
        reason: 'inappropriate_content',
        targetType: 'place',
        targetId: 'place1'
      }));
    });

    it('should allow staff to read and update reports', async () => {
      // User creates report
      await createUserDoc('user1');
      const userDb = getFirestore({ uid: 'user1' });
      await setDoc(doc(userDb, 'reports', 'report2'), {
        reportedBy: 'user1',
        status: 'pending',
        reason: 'spam'
      });
      
      // Staff can read and update
      await createUserDoc('admin1', 'admin');
      const adminDb = getFirestore({ uid: 'admin1' });
      await assertSucceeds(getDoc(doc(adminDb, 'reports', 'report2')));
      await assertSucceeds(updateDoc(doc(adminDb, 'reports', 'report2'), {
        status: 'resolved'
      }));
    });

    it('should allow reporter to read their own report', async () => {
      await createUserDoc('user1');
      const userDb = getFirestore({ uid: 'user1' });
      
      await setDoc(doc(userDb, 'reports', 'report3'), {
        reportedBy: 'user1',
        status: 'pending',
        reason: 'misinformation'
      });
      
      await assertSucceeds(getDoc(doc(userDb, 'reports', 'report3')));
    });

    it('should deny user reading other user reports', async () => {
      // User1 creates report
      await createUserDoc('user1');
      const user1Db = getFirestore({ uid: 'user1' });
      await setDoc(doc(user1Db, 'reports', 'report4'), {
        reportedBy: 'user1',
        status: 'pending',
        reason: 'spam'
      });
      
      // User2 cannot read it
      await createUserDoc('user2');
      const user2Db = getFirestore({ uid: 'user2' });
      await assertFails(getDoc(doc(user2Db, 'reports', 'report4')));
    });
  });
});