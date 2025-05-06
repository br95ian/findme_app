const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const fcm = admin.messaging();

// Calculate distance between two points (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const p = 0.017453292519943295; // Math.PI / 180
  const c = Math.cos;
  const a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
  return 12742 * Math.asin(Math.sqrt(a)); // 2 * R * asin(sqrt(a)), R = 6371 km
}

// Trigger when a new item is created
exports.findPotentialMatches = functions.firestore
  .document('items/{itemId}')
  .onCreate(async (snapshot, context) => {
    const newItem = snapshot.data();
    const itemId = context.params.itemId;

    // Skip if the item is already resolved
    if (newItem.isResolved) {
      return null;
    }

    // Determine the opposite item type to search for
    const oppositeType = newItem.type === 'lost' ? 'found' : 'lost';

    // Query for potential matches
    const querySnapshot = await db.collection('items')
      .where('type', '==', oppositeType)
      .where('isResolved', '==', false)
      .where('category', '==', newItem.category)
      .get();

    if (querySnapshot.empty) {
      console.log('No potential matches found.');
      return null;
    }

    // Filter by distance (within 1km)
    const matches = [];
    querySnapshot.forEach(doc => {
      const item = doc.data();
      
      // Skip if same user
      if (item.userId === newItem.userId) {
        return;
      }
      
      // Calculate distance
      const distance = calculateDistance(
        newItem.location.latitude,
        newItem.location.longitude,
        item.location.latitude,
        item.location.longitude
      );
      
      // Items within 1km are potential matches
      if (distance <= 1.0) {
        matches.push({
          id: doc.id,
          ...item
        });
      }
    });

    console.log(`Found ${matches.length} potential matches.`);
    
    // Send notifications to users
    const notificationPromises = matches.map(async (match) => {
      try {
        // Get user device tokens
        const userDoc = await db.collection('users').doc(match.userId).get();
        const user = userDoc.data();
        
        if (!user || !user.fcmTokens || Object.keys(user.fcmTokens).length === 0) {
          return null;
        }
        
        // Create the notification
        const title = match.type === 'lost' 
          ? 'Potential match for your lost item' 
          : 'Someone may have lost what you found';
          
        const body = `There's a potential match for "${match.title}"`;
        
        // Send notification to all user devices
        const tokens = Object.values(user.fcmTokens);
        
        const message = {
          notification: {
            title: title,
            body: body,
          },
          data: {
            itemId: match.id,
            matchId: itemId,
            click_action: 'FLUTTER_NOTIFICATION_CLICK',
          },
          tokens: tokens,
        };
        
        return fcm.sendMulticast(message);
      } catch (error) {
        console.error('Error sending notification:', error);
        return null;
      }
    });
    
    await Promise.all(notificationPromises);
    
    // Create match records in Firestore
    const matchPromises = matches.map(match => {
      return db.collection('matches').add({
        itemId: itemId,
        matchId: match.id,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        notified: true,
      });
    });
    
    return Promise.all(matchPromises);
  });

// Update FCM token for a user
exports.updateUserFcmToken = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated', 
      'User must be authenticated to update FCM token'
    );
  }

  const { token } = data;
  const userId = context.auth.uid;

  if (!token) {
    throw new functions.https.HttpsError(
      'invalid-argument', 
      'FCM token must be provided'
    );
  }

  try {
    // Add token to user document
    const tokenKey = `fcmTokens.${token.replace(/\./g, ',')}`;  // Replace dots in token for Firestore
    await db.collection('users').doc(userId).update({
      [tokenKey]: token,
    });
    return { success: true };
  } catch (error) {
    console.error('Error updating FCM token:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Clean up old unresolved items (items older than 90 days)
exports.cleanupOldItems = functions.pubsub
  .schedule('0 0 * * *')  // Run every day at midnight
  .onRun(async (context) => {
    const cutoffDate = new Date();
    cutoffDate.setDate(cutoffDate.getDate() - 90);
    const cutoffTimestamp = admin.firestore.Timestamp.fromDate(cutoffDate);
    
    const oldItemsQuery = await db.collection('items')
      .where('isResolved', '==', false)
      .where('createdAt', '<', cutoffTimestamp)
      .get();
    
    if (oldItemsQuery.empty) {
      console.log('No old items to clean up.');
      return null;
    }

    const batch = db.batch();
    oldItemsQuery.forEach(doc => {
      batch.update(doc.ref, { 
        isResolved: true,
        status: 'expired',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });

    await batch.commit();
    console.log(`Cleaned up ${oldItemsQuery.size} old items.`);
    return null;
  });

// Mark an item as resolved
exports.resolveItem = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to resolve an item'
    );
  }

  const { itemId, matchId, resolutionType } = data;
  const userId = context.auth.uid;

  if (!itemId || !resolutionType) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Item ID and resolution type must be provided'
    );
  }

  try {
    // Get the item document
    const itemDoc = await db.collection('items').doc(itemId).get();
    
    if (!itemDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Item not found'
      );
    }
    
    const item = itemDoc.data();
    
    // Check if user owns this item
    if (item.userId !== userId) {
      throw new functions.https.HttpsError(
        'permission-denied',
        'Only the item owner can resolve it'
      );
    }
    
    // Update the item as resolved
    await db.collection('items').doc(itemId).update({
      isResolved: true,
      resolutionType: resolutionType,
      matchId: matchId || null,
      resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    // If there's a match, also update it
    if (matchId) {
      const matchDoc = await db.collection('items').doc(matchId).get();
      
      if (matchDoc.exists) {
        await db.collection('items').doc(matchId).update({
          isResolved: true,
          resolutionType: 'matched',
          matchId: itemId,
          resolvedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        // Create a resolution record
        await db.collection('resolutions').add({
          itemId: itemId,
          matchId: matchId,
          resolutionType: resolutionType,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          userId: userId
        });
        
        // Send notification to the match owner
        const matchItem = matchDoc.data();
        const matchUserDoc = await db.collection('users').doc(matchItem.userId).get();
        const matchUser = matchUserDoc.data();
        
        if (matchUser && matchUser.fcmTokens && Object.keys(matchUser.fcmTokens).length > 0) {
          const tokens = Object.values(matchUser.fcmTokens);
          
          const message = {
            notification: {
              title: 'Your item has been matched!',
              body: `Your ${matchItem.type} item "${matchItem.title}" has been matched with another user.`
            },
            data: {
              itemId: matchId,
              matchId: itemId,
              resolutionType: 'matched',
              click_action: 'FLUTTER_NOTIFICATION_CLICK'
            },
            tokens: tokens
          };
          
          await fcm.sendMulticast(message);
        }
      }
    }
    
    return { success: true };
  } catch (error) {
    console.error('Error resolving item:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Generate statistics for dashboard
exports.generateStats = functions.https.onCall(async (data, context) => {
  // Check if user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated to get statistics'
    );
  }

  try {
    // Get counts of items by type and resolution status
    const lostItemsQuery = await db.collection('items').where('type', '==', 'lost').get();
    const foundItemsQuery = await db.collection('items').where('type', '==', 'found').get();
    const resolvedItemsQuery = await db.collection('items').where('isResolved', '==', true).get();
    
    // Get user's items
    const userId = context.auth.uid;
    const userItemsQuery = await db.collection('items')
      .where('userId', '==', userId)
      .get();
    
    // Calculate statistics
    const stats = {
      totalItems: lostItemsQuery.size + foundItemsQuery.size,
      lostItems: lostItemsQuery.size,
      foundItems: foundItemsQuery.size,
      resolvedItems: resolvedItemsQuery.size,
      userItems: userItemsQuery.size,
      successRate: resolvedItemsQuery.size > 0 ? 
        (resolvedItemsQuery.size / (lostItemsQuery.size + foundItemsQuery.size) * 100).toFixed(1) : 0
    };
    
    return stats;
  } catch (error) {
    console.error('Error generating statistics:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});