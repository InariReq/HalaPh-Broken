const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { FieldValue } = require("firebase-admin/firestore");

admin.initializeApp();

/**
 * Cloud Function: Create friendship when friend request is accepted
 * Trigger: Firestore document update in friend_requests collection
 * Path: /users/{toUid}/friend_requests/{fromUid}
 */
exports.onFriendRequestAccepted = functions.firestore
  .document("users/{toUid}/friend_requests/{fromUid}")
  .onUpdate(async (change, context) => {
    const { toUid, fromUid } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only proceed when status changes from 'pending' to 'accepted'
    if (beforeData.status !== 'pending' || afterData.status !== 'accepted') {
      return null;
    }

    console.log(`Creating friendship between ${fromUid} and ${toUid}`);

    try {
      const db = admin.firestore();
      const batch = db.batch();

      // Create friend document for recipient
      const recipientFriendRef = db
        .collection("users")
        .doc(toUid)
        .collection("friends")
        .doc(fromUid);

      const recipientFriendData = {
        friendUid: fromUid,
        friendId: fromUid,
        ownerUid: toUid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        // Include sender profile data if available
        fromName: afterData.fromName || null,
        fromCode: afterData.fromCode || null,
        fromAvatarUrl: afterData.fromAvatarUrl || null,
      };

      batch.set(recipientFriendRef, recipientFriendData);

      // Create friend document for sender
      const senderFriendRef = db
        .collection("users")
        .doc(fromUid)
        .collection("friends")
        .doc(toUid);

      // Get recipient's public profile data
      const recipientProfileRef = db.collection("publicProfiles").doc(toUid);
      const recipientProfileDoc = await recipientProfileRef.get();

      const senderFriendData = {
        friendUid: toUid,
        friendId: toUid,
        ownerUid: fromUid,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
        // Include recipient profile data if available
        name: recipientProfileDoc.exists ? recipientProfileDoc.data().name : null,
        code: recipientProfileDoc.exists ? recipientProfileDoc.data().code : null,
        email: recipientProfileDoc.exists ? recipientProfileDoc.data().email : null,
        avatarUrl: recipientProfileDoc.exists ? recipientProfileDoc.data().avatarUrl : null,
      };

      batch.set(senderFriendRef, senderFriendData);

      // Create notification for recipient (if they don't already have one)
      const recipientNotificationRef = db
        .collection("users")
        .doc(toUid)
        .collection("notifications")
        .doc();

      const recipientNotificationData = {
        toUid: toUid,
        fromUid: fromUid,
        type: "friend_request_accepted",
        title: "Friend Request Accepted",
        message: `${afterData.fromName || 'Someone'} accepted your friend request!`,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      batch.set(recipientNotificationRef, recipientNotificationData);

      // Create notification for sender
      const senderNotificationRef = db
        .collection("users")
        .doc(fromUid)
        .collection("notifications")
        .doc();

      const senderNotificationData = {
        toUid: fromUid,
        fromUid: toUid,
        type: "friend_request_accepted",
        title: "Friend Request Accepted",
        message: `You are now friends with ${recipientProfileDoc.exists ? recipientProfileDoc.data().name : 'someone'}!`,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      batch.set(senderNotificationRef, senderNotificationData);

      // Add activity entries for both users
      const recipientActivityRef = db
        .collection("users")
        .doc(toUid)
        .collection("activity")
        .doc();

      const recipientActivityData = {
        userId: toUid,
        type: "friend_added",
        description: `You are now friends with ${afterData.fromName || 'someone'}`,
        timestamp: FieldValue.serverTimestamp(),
        metadata: {
          friendUid: fromUid,
          friendName: afterData.fromName,
        },
      };

      batch.set(recipientActivityRef, recipientActivityData);

      const senderActivityRef = db
        .collection("users")
        .doc(fromUid)
        .collection("activity")
        .doc();

      const senderActivityData = {
        userId: fromUid,
        type: "friend_added",
        description: `You are now friends with ${recipientProfileDoc.exists ? recipientProfileDoc.data().name : 'someone'}`,
        timestamp: FieldValue.serverTimestamp(),
        metadata: {
          friendUid: toUid,
          friendName: recipientProfileDoc.exists ? recipientProfileDoc.data().name : null,
        },
      };

      batch.set(senderActivityRef, senderActivityData);

      // Commit all changes atomically
      await batch.commit();

      console.log(`Successfully created friendship between ${fromUid} and ${toUid}`);
      return null;
    } catch (error) {
      console.error(`Error creating friendship between ${fromUid} and ${toUid}:`, error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create friendship",
        error
      );
    }
  });

/**
 * Cloud Function: Create notification when friend request is sent
 * Trigger: Firestore document creation in friend_requests collection
 * Path: /users/{toUid}/friend_requests/{fromUid}
 */
exports.onFriendRequestSent = functions.firestore
  .document("users/{toUid}/friend_requests/{fromUid}")
  .onCreate(async (snapshot, context) => {
    const { toUid, fromUid } = context.params;
    const requestData = snapshot.data();

    console.log(`Creating notification for friend request from ${fromUid} to ${toUid}`);

    try {
      const db = admin.firestore();

      // Create notification for recipient
      const notificationRef = db
        .collection("users")
        .doc(toUid)
        .collection("notifications")
        .doc();

      const notificationData = {
        toUid: toUid,
        fromUid: fromUid,
        type: "friend_request",
        title: "New Friend Request",
        message: `${requestData.fromName || 'Someone'} sent you a friend request!`,
        read: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await notificationRef.set(notificationData);

      // Add activity entry for sender
      const activityRef = db
        .collection("users")
        .doc(fromUid)
        .collection("activity")
        .doc();

      const activityData = {
        userId: fromUid,
        type: "friend_request_sent",
        description: `You sent a friend request to ${requestData.toName || 'someone'}`,
        timestamp: FieldValue.serverTimestamp(),
        metadata: {
          recipientUid: toUid,
          recipientName: requestData.toName,
        },
      };

      await activityRef.set(activityData);

      console.log(`Successfully created friend request notification`);
      return null;
    } catch (error) {
      console.error("Error creating friend request notification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to create friend request notification",
        error
      );
    }
  });

/**
 * Cloud Function: Clean up friend request when rejected
 * Trigger: Firestore document update in friend_requests collection
 * Path: /users/{toUid}/friend_requests/{fromUid}
 */
exports.onFriendRequestRejected = functions.firestore
  .document("users/{toUid}/friend_requests/{fromUid}")
  .onUpdate(async (change, context) => {
    const { toUid, fromUid } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Only proceed when status changes from 'pending' to 'rejected'
    if (beforeData.status !== 'pending' || afterData.status !== 'rejected') {
      return null;
    }

    console.log(`Friend request from ${fromUid} to ${toUid} was rejected`);

    try {
      const db = admin.firestore();

      // Add activity entry for sender
      const activityRef = db
        .collection("users")
        .doc(fromUid)
        .collection("activity")
        .doc();

      const activityData = {
        userId: fromUid,
        type: "friend_request_rejected",
        description: `Your friend request to ${afterData.toName || 'someone'} was declined`,
        timestamp: FieldValue.serverTimestamp(),
        metadata: {
          recipientUid: toUid,
          recipientName: afterData.toName,
        },
      };

      await activityRef.set(activityData);

      console.log(`Successfully logged friend request rejection`);
      return null;
    } catch (error) {
      console.error("Error logging friend request rejection:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to log friend request rejection",
        error
      );
    }
  });

/**
 * Cloud Function: Create notification for shared plan collaboration
 * Trigger: Firestore document update in sharedPlans collection
 * Path: /sharedPlans/{planId}
 */
exports.onPlanCollaboratorAdded = functions.firestore
  .document("sharedPlans/{planId}")
  .onUpdate(async (change, context) => {
    const { planId } = context.params;
    const beforeData = change.before.data();
    const afterData = change.after.data();

    // Check if participantUids changed
    const beforeParticipants = new Set(beforeData.participantUids || []);
    const afterParticipants = new Set(afterData.participantUids || []);

    // Find newly added participants
    const newParticipants = [...afterParticipants].filter(uid => !beforeParticipants.has(uid));

    if (newParticipants.length === 0) {
      return null; // No new participants added
    }

    console.log(`Adding ${newParticipants.length} collaborators to plan ${planId}`);

    try {
      const db = admin.firestore();
      const batch = db.batch();

      // Create notifications for new participants
      for (const participantUid of newParticipants) {
        // Don't notify the owner if they added themselves
        if (participantUid === afterData.ownerUid) {
          continue;
        }

        const notificationRef = db
          .collection("users")
          .doc(participantUid)
          .collection("notifications")
          .doc();

        const notificationData = {
          toUid: participantUid,
          fromUid: afterData.ownerUid,
          type: "plan_shared",
          title: "Plan Shared With You",
          message: `You've been added to the plan "${afterData.title}"`,
          read: false,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
          metadata: {
            planId: planId,
            planTitle: afterData.title,
          },
        };

        batch.set(notificationRef, notificationData);

        // Add activity entry for participant
        const activityRef = db
          .collection("users")
          .doc(participantUid)
          .collection("activity")
          .doc();

        const activityData = {
          userId: participantUid,
          type: "plan_shared",
          description: `You were added to the plan "${afterData.title}"`,
          timestamp: FieldValue.serverTimestamp(),
          metadata: {
            planId: planId,
            planTitle: afterData.title,
            ownerUid: afterData.ownerUid,
          },
        };

        batch.set(activityRef, activityData);
      }

      await batch.commit();

      console.log(`Successfully notified ${newParticipants.length} new collaborators`);
      return null;
    } catch (error) {
      console.error("Error notifying new collaborators:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to notify new collaborators",
        error
      );
    }
  });
