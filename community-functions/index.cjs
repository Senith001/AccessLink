const {initializeApp} = require('firebase-admin/app');
const {getFirestore, FieldValue} = require('firebase-admin/firestore');
const {onDocumentWritten} = require('firebase-functions/v2/firestore');
const {aggregateRatings} = require('./ratings.cjs');
initializeApp();
exports.accesslinkCommunityRatings = onDocumentWritten({document: 'reviews/{reviewId}', retry: true}, async event => {
  const ids = new Set([event.data?.before.data()?.placeId, event.data?.after.data()?.placeId].filter(Boolean));
  const db = getFirestore();
  for (const id of ids) {
    await db.runTransaction(async tx => {
      const ref = db.collection('places').doc(id);
      const place = await tx.get(ref);
      const reviews = await tx.get(db.collection('reviews').where('placeId', '==', id));
      if (!place.exists) return;
      tx.update(ref, {...aggregateRatings(reviews.docs.map(d => ({id: d.id, data: d.data()}))),
        ratingUpdatedAt: FieldValue.serverTimestamp()});
    });
  }
});
