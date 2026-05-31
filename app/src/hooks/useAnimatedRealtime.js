import { useState, useEffect, useRef } from 'react';

const EMPTY = { type: 'FeatureCollection', features: [] };
const DURATION = 15000; // ms to glide from old position to the newly reported one

const keyOf = (p) => `${p.agency_name}:${p.vehicle_id || p.id}`;

// Smoothly animates live vehicles between position updates so they appear to
// travel rather than jump/blink. `target` is the latest enriched snapshot
// (changes ~every 15s); the returned FeatureCollection updates every frame while
// vehicles are in motion. Designed to be called INSIDE RealtimeLayers so only
// that subtree re-renders per frame.
export function useAnimatedRealtime(target) {
  const [frame, setFrame] = useState(EMPTY);
  const statesRef = useRef(new Map());

  // New target data: set each vehicle's destination (only resets the glide when
  // the destination actually changed, so motion stays continuous across refreshes).
  useEffect(() => {
    const states = statesRef.current;
    const now = performance.now();
    const seen = new Set();
    for (const f of (target?.features || [])) {
      const p = f.properties || {};
      const id = keyOf(p);
      seen.add(id);
      const [lng, lat] = f.geometry.coordinates;
      const s = states.get(id);
      if (!s) {
        states.set(id, { curLng: lng, curLat: lat, fromLng: lng, fromLat: lat, toLng: lng, toLat: lat, start: now, props: p });
      } else if (s.toLng !== lng || s.toLat !== lat) {
        s.fromLng = s.curLng; s.fromLat = s.curLat;
        s.toLng = lng; s.toLat = lat; s.start = now; s.props = p;
      } else {
        s.props = p; // same destination — refresh props (color/heading/etc.)
      }
    }
    for (const id of [...states.keys()]) if (!seen.has(id)) states.delete(id);
  }, [target]);

  // Animation loop: lerp toward destinations; stop emitting once everything settles.
  useEffect(() => {
    let raf;
    let settledEmitted = false;
    const tick = () => {
      const states = statesRef.current;
      const now = performance.now();
      let moving = false;
      const features = [];
      for (const s of states.values()) {
        const t = Math.min((now - s.start) / DURATION, 1);
        if (t < 1) moving = true;
        s.curLng = s.fromLng + (s.toLng - s.fromLng) * t;
        s.curLat = s.fromLat + (s.toLat - s.fromLat) * t;
        features.push({ type: 'Feature', geometry: { type: 'Point', coordinates: [s.curLng, s.curLat] }, properties: s.props });
      }
      if (moving || !settledEmitted) {
        setFrame({ type: 'FeatureCollection', features });
        settledEmitted = !moving;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, []);

  return frame;
}
