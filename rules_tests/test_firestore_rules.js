const { initializeTestEnvironment, assertFails, assertSucceeds } = require('@firebase/rules-unit-testing');
const { getFirestore, collection, doc, setDoc, getDoc, query, where, getDocs, updateDoc, serverTimestamp, Timestamp } = require('firebase/firestore');
const { describe, it, before, after, beforeEach, afterEach } = require('node:test');
const assert = require('node:assert');

const PROJECT_ID = 'halaph-test-project';

// Test UIDs
const OWNER_UID = 'ownerUid';
const PARTICIPANT_UID = 'participantUid';
const STRANGER_UID = 'strangerUid';

describe('Firestore Security Rules Tests', function() {
  let testEnv;

  before(async function() {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: {
        rules: require('fs').readFileSync('../firestore.rules', 'utf8'),
      },
    });
  });

  after(async function() {
    await testEnv.cleanup();
  });

  describe('friendRequests collection', function() {
    const requestId = 'testRequest1';

    const validPayload = {
      fromUid: OWNER_UID,
      toUid: STRANGER_UID,
      fromCode: 'AB1234',
      toCode: 'CD5678',
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    };

    it('friend request cannot be sent to self', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await assertFails(setDoc(reqRef, {
        fromUid: OWNER_UID,
        toUid: OWNER_UID,
        status: 'pending',
        createdAt: serverTimestamp()
      }));
    });

    it('friend request can be sent to another user', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await assertSucceeds(setDoc(reqRef, {
        fromUid: OWNER_UID,
        toUid: STRANGER_UID,
        status: 'pending',
        createdAt: serverTimestamp()
      }));
    });

    it('exact live primary payload succeeds', async function() {
      const fromUid = 'sb3Qwv3LEGcYGlpEoDUwaKbQvKo2';
      const toUid = 'AglHR8eiyoba5J12KOqEcQBAqjm2';
      const reqRef = doc(testEnv.authenticatedContext(fromUid).firestore(), 'friendRequests', `${fromUid}_${toUid}`);
      await assertSucceeds(setDoc(reqRef, {
        fromUid: fromUid,
        toUid: toUid,
        fromCode: 'BD-6060',
        toCode: 'JE-9248',
        status: 'pending',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      }));
    });

    it('valid friend request create succeeds with exact live payload', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await assertSucceeds(setDoc(reqRef, validPayload));
    });

    it('unrelated auth user cannot create request as another fromUid', async function() {
      const strangerDb = testEnv.authenticatedContext(STRANGER_UID).firestore();
      const reqRef = doc(strangerDb, 'friendRequests', requestId);
      await assertFails(setDoc(reqRef, {
        fromUid: OWNER_UID,
        toUid: STRANGER_UID,
        status: 'pending',
        createdAt: serverTimestamp()
      }));
    });

    it('payload with forbidden field friendCode is denied', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await assertFails(setDoc(reqRef, {
        fromUid: OWNER_UID,
        toUid: STRANGER_UID,
        status: 'pending',
        friendCode: 'ABC123',
        createdAt: serverTimestamp()
      }));
    });

    it('recipient cannot get request (no get rule)', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await setDoc(reqRef, validPayload);
      const strangerDb = testEnv.authenticatedContext(STRANGER_UID).firestore();
      const readRef = doc(strangerDb, 'friendRequests', requestId);
      await assertFails(getDoc(readRef));
    });

    it('sender cannot get request (no get rule)', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await setDoc(reqRef, validPayload);
      await assertFails(getDoc(reqRef));
    });

    it('unrelated user cannot get request', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await setDoc(reqRef, validPayload);
      const unrelatedDb = testEnv.authenticatedContext(PARTICIPANT_UID).firestore();
      const readRef = doc(unrelatedDb, 'friendRequests', requestId);
      await assertFails(getDoc(readRef));
    });

    it('update to accepted uses only status and updatedAt', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await setDoc(reqRef, validPayload);
      const strangerDb = testEnv.authenticatedContext(STRANGER_UID).firestore();
      const updateRef = doc(strangerDb, 'friendRequests', requestId);
      await assertSucceeds(updateDoc(updateRef, {
        status: 'accepted',
        updatedAt: serverTimestamp()
      }));
    });

    it('update with respondedAt is denied', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const reqRef = doc(ownerDb, 'friendRequests', requestId);
      await setDoc(reqRef, validPayload);
      const strangerDb = testEnv.authenticatedContext(STRANGER_UID).firestore();
      const updateRef = doc(strangerDb, 'friendRequests', requestId);
      await assertFails(updateDoc(updateRef, {
        status: 'accepted',
        respondedAt: serverTimestamp()
      }));
    });
  });

  describe('friendRequests mirror (nested inbox)', function() {
    const requestId = 'mirrorRequest1';
    const fromUid = OWNER_UID;
    const toUid = STRANGER_UID;

    const mirrorPayload = {
      fromUid: fromUid,
      toUid: toUid,
      fromCode: 'AB1234',
      toCode: 'CD5678',
      status: 'pending',
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp()
    };

    beforeEach(async function() {
      // Clean up mirror document before each test
      const { deleteDoc } = require('firebase/firestore');
      await testEnv.withSecurityRulesDisabled(async (adminContext) => {
        const adminDb = adminContext.firestore();
        const mirrorRef = doc(adminDb, 'users', toUid, 'friend_requests', fromUid);
        const primaryRef = doc(adminDb, 'friendRequests', `${fromUid}_${toUid}`);
        await deleteDoc(mirrorRef).catch(() => {});
        await deleteDoc(primaryRef).catch(() => {});
      });
    });

    it('sender can create primary friendRequests/{fromUid}_{toUid}', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const primaryRef = doc(ownerDb, 'friendRequests', `${fromUid}_${toUid}`);
      await assertSucceeds(setDoc(primaryRef, mirrorPayload));
    });

    it('sender can create mirror users/{toUid}/friend_requests/{fromUid}', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await assertSucceeds(setDoc(mirrorRef, mirrorPayload));
    });

    it('recipient can read mirror users/{toUid}/friend_requests/{fromUid}', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      const recipientDb = testEnv.authenticatedContext(toUid).firestore();
      const readRef = doc(recipientDb, 'users', toUid, 'friend_requests', fromUid);
      await assertSucceeds(getDoc(readRef));
    });

    it('recipient can query own users/{toUid}/friend_requests where status == pending', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      const recipientDb = testEnv.authenticatedContext(toUid).firestore();
      const q = query(
        collection(recipientDb, 'users', toUid, 'friend_requests'),
        where('status', '==', 'pending')
      );
      await assertSucceeds(getDocs(q));
    });

    it('unrelated user cannot read mirror', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      const unrelatedDb = testEnv.authenticatedContext(PARTICIPANT_UID).firestore();
      const readRef = doc(unrelatedDb, 'users', toUid, 'friend_requests', fromUid);
      await assertFails(getDoc(readRef));
    });

    it('recipient can accept by updating mirror path', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      const recipientDb = testEnv.authenticatedContext(toUid).firestore();
      const updateRef = doc(recipientDb, 'users', toUid, 'friend_requests', fromUid);
      await assertSucceeds(updateDoc(updateRef, {
        status: 'accepted',
        updatedAt: serverTimestamp()
      }));
    });

    it('recipient can decline by updating mirror path', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      const recipientDb = testEnv.authenticatedContext(toUid).firestore();
      const updateRef = doc(recipientDb, 'users', toUid, 'friend_requests', fromUid);
      await assertSucceeds(updateDoc(updateRef, {
        status: 'declined',
        updatedAt: serverTimestamp()
      }));
    });

    it('sender can cancel by updating both paths', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const primaryRef = doc(ownerDb, 'friendRequests', `${fromUid}_${toUid}`);
      await setDoc(primaryRef, mirrorPayload);
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await setDoc(mirrorRef, mirrorPayload);
      await assertSucceeds(updateDoc(primaryRef, {
        status: 'cancelled',
        updatedAt: serverTimestamp()
      }));
      await assertSucceeds(updateDoc(mirrorRef, {
        status: 'cancelled',
        updatedAt: serverTimestamp()
      }));
    });

    it('self friend request is denied for mirror', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', fromUid, 'friend_requests', fromUid);
      await assertFails(setDoc(mirrorRef, {
        fromUid: fromUid,
        toUid: fromUid,
        status: 'pending',
        createdAt: serverTimestamp()
      }));
    });

    it('forbidden fields are denied for mirror create', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const mirrorRef = doc(ownerDb, 'users', toUid, 'friend_requests', fromUid);
      await assertFails(setDoc(mirrorRef, {
        fromUid: fromUid,
        toUid: toUid,
        status: 'pending',
        friendCode: 'ABC123',
        createdAt: serverTimestamp()
      }));
    });

    it('top-level friendRequests valid create still succeeds', async function() {
      const ownerDb = testEnv.authenticatedContext(fromUid).firestore();
      const primaryRef = doc(ownerDb, 'friendRequests', `${fromUid}_${toUid}`);
      await assertSucceeds(setDoc(primaryRef, mirrorPayload));
    });
  });

  describe('friends collection', function() {
    beforeEach(async function() {
      // Isolate tests by clearing Firestore state for this branch
      await testEnv.clearFirestore();
    });
    const ownerUid = OWNER_UID;
    const friendUid = STRANGER_UID;
    const friendCode = 'AB-1234';

    const friendPayload = {
      uid: friendUid,
      friendUid: friendUid,
      friendId: friendUid,
      code: friendCode,
      name: 'Test Friend',
      createdAt: serverTimestamp()
    };

    it('owner can create own friend doc', async function() {
      const ownerDb = testEnv.authenticatedContext(ownerUid).firestore();
      const friendRef = doc(ownerDb, 'users', ownerUid, 'friends', friendUid);
      await assertSucceeds(setDoc(friendRef, friendPayload));
    });

    it('owner can read own friends', async function() {
      const ownerDb = testEnv.authenticatedContext(ownerUid).firestore();
      const friendRef = doc(ownerDb, 'users', ownerUid, 'friends', friendUid);
      await setDoc(friendRef, friendPayload);
      await assertSucceeds(getDoc(friendRef));
    });

    it("user cannot read another user's friends", async function() {
      const ownerDb = testEnv.authenticatedContext(ownerUid).firestore();
      const friendRef = doc(ownerDb, 'users', ownerUid, 'friends', friendUid);
      await setDoc(friendRef, friendPayload);
      const otherDb = testEnv.authenticatedContext(STRANGER_UID).firestore();
      const otherRef = doc(otherDb, 'users', ownerUid, 'friends', friendUid);
      await assertFails(getDoc(otherRef));
    });

    it('reciprocal create succeeds when auth uid == friendId', async function() {
      const friendDb = testEnv.authenticatedContext(friendUid).firestore();
      const reciprRef = doc(friendDb, 'users', ownerUid, 'friends', friendUid);
      await assertSucceeds(setDoc(reciprRef, friendPayload));
    });

    it('reciprocal create denied when friendUid does not equal friendId', async function() {
      const badPayload = { ...friendPayload, friendUid: 'wrongUid' };
      const friendDb = testEnv.authenticatedContext(friendUid).firestore();
      const reciprRef = doc(friendDb, 'users', ownerUid, 'friends', friendUid);
      await assertFails(setDoc(reciprRef, badPayload));
    });

    it('reciprocal create denied when uid does not equal friendId', async function() {
      const badPayload = { ...friendPayload, uid: 'wrongId' };
      const friendDb = testEnv.authenticatedContext(friendUid).firestore();
      const reciprRef = doc(friendDb, 'users', ownerUid, 'friends', friendUid);
      await assertFails(setDoc(reciprRef, badPayload));
    });

    it('forbidden field is denied', async function() {
      const ownerDb = testEnv.authenticatedContext(ownerUid).firestore();
      const friendRef = doc(ownerDb, 'users', ownerUid, 'friends', friendUid);
      await assertFails(setDoc(friendRef, {
        ...friendPayload,
        forbiddenField: 'should be denied'
      }));
    });
  });

  describe('sharedPlans collection', function() {
    const planId = 'testPlan1';

    const ownerPayload = {
      title: 'Test Plan',
      startDate: Timestamp.now(),
      endDate: Timestamp.now(),
      participantUids: [OWNER_UID, PARTICIPANT_UID],
      createdBy: OWNER_UID,
      ownerUid: OWNER_UID,
      days: [],
      itinerary: {},
      destinationIds: [],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now()
    };

    it('owner can read own shared plan get', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const planRef = doc(ownerDb, 'sharedPlans', planId);
      await setDoc(planRef, ownerPayload);
      await assertSucceeds(getDoc(planRef));
    });
  });

  describe('friendCodes collection', function() {
    const code = 'AB-1234';

    it('friend code can be read by signed-in users', async function() {
      const ownerDb = testEnv.authenticatedContext(OWNER_UID).firestore();
      const codeRef = doc(ownerDb, 'friendCodes', code);
      await setDoc(codeRef, {
        uid: OWNER_UID,
        code: code,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp()
      });
      await assertSucceeds(getDoc(codeRef));
    });
  });

  describe('firestore.rules validation', function() {
    it('firestore.rules does not reference participantCodes', async function() {
      const fs = require('fs');
      const rules = fs.readFileSync('../firestore.rules', 'utf8');
      assert.strictEqual(rules.includes('participantCodes'), false,
        'firestore.rules still references participantCodes - remove it');
    });
  });

  describe('notifications collection', function() {
    it('notifications query does not need composite index', async function() {
      const userId = OWNER_UID;
      const ownerDb = testEnv.authenticatedContext(userId).firestore();
      const q = query(
        collection(ownerDb, 'users', userId, 'notifications'),
        where('read', '==', false)
      );
      await assertSucceeds(getDocs(q));
    });
  });
});
