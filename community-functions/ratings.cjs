// Choose the canonical per-user review, or the newest legacy record.
function aggregateRatings(docs) {
  const chosen = new Map();
  for (const doc of docs) {
    const d = doc.data;
    if (typeof d.userId !== 'string' || !Number.isInteger(d.rating) || d.rating < 1 || d.rating > 5) continue;
    const canonical = doc.id === `${d.placeId}_${d.userId}`;
    const time = d.updatedAt?.toMillis?.() ?? d.createdAt?.toMillis?.() ?? 0;
    const prev = chosen.get(d.userId);
    if (!prev || (canonical && !prev.canonical) || (canonical === prev.canonical && time > prev.time)) {
      chosen.set(d.userId, {rating: d.rating, canonical, time});
    }
  }
  const ratingCount = chosen.size;
  const ratingSum = [...chosen.values()].reduce((n, v) => n + v.rating, 0);
  return {ratingCount, ratingSum, ratingAverage: ratingCount ? Number((ratingSum / ratingCount).toFixed(1)) : 0};
}
module.exports = {aggregateRatings};
