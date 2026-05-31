import { Source, Layer } from 'react-map-gl/maplibre';
import { useAnimatedRealtime } from '../../hooks/useAnimatedRealtime';

// Realtime markers: big when zoomed out (where stop dots are hidden) and shrink as
// you zoom in, converging to roughly a stop dot's size at the closest zoom.
const DOT_RADIUS = ['interpolate', ['linear'], ['zoom'], 8, 14, 12, 10, 18, 9];
const ARROW_SIZE = ['interpolate', ['linear'], ['zoom'], 8, 1.5, 12, 1.1, 18, 0.85];

// Each agency draws two layers sharing one visibility toggle, driven by per-feature
// props (set in App enrichment): a rotated colored ARROW when a heading is known
// (current or last-known), or a colored DOT when none was ever reported.
const AGENCIES = [
  { agencyId: 'realtime-ktmb', name: 'ktmb' },
  { agencyId: 'realtime-rapid-bus', name: 'rapid-bus' },
  { agencyId: 'realtime-mrt-feeder', name: 'rapid-mrt' },
];

const labelPaint = {
  'text-color': '#333333',
  'text-halo-color': '#ffffff',
  'text-halo-width': 1.5,
};

export function RealtimeLayers({ visibility, data }) {
  // Smoothly interpolate positions between updates (only this subtree re-renders).
  const fc = useAnimatedRealtime(data);

  return (
    <Source id="realtime" type="geojson" data={fc}>
      {AGENCIES.map(({ agencyId, name }) => {
        const visible = visibility[agencyId] ? 'visible' : 'none';
        const isAgency = ['==', ['get', 'agency_name'], name];
        return [
          <Layer
            key={agencyId}
            id={agencyId}
            type="circle"
            filter={['all', isAgency, ['!', ['get', 'hasHeading']]]}
            layout={{ visibility: visible }}
            paint={{
              'circle-radius': DOT_RADIUS,
              'circle-color': ['get', 'color'],
              'circle-stroke-width': 2,
              'circle-stroke-color': '#ffffff',
              'circle-opacity': 0.9,
            }}
          />,
          <Layer
            key={`${agencyId}-arrow`}
            id={`${agencyId}-arrow`}
            type="symbol"
            filter={['all', isAgency, ['get', 'hasHeading']]}
            layout={{
              visibility: visible,
              'icon-image': ['get', 'arrowIcon'],
              'icon-rotate': ['get', 'dirBearing'],
              'icon-rotation-alignment': 'map',
              'icon-allow-overlap': true,
              'icon-ignore-placement': true,
              'icon-size': ARROW_SIZE,
            }}
          />,
        ];
      })}
      <Layer
        id="rt-labels"
        type="symbol"
        minzoom={14}
        layout={{
          'text-field': ['concat', ['get', 'vehicle_label'], '\n', ['coalesce', ['get', 'next_stop_name'], '']],
          'text-size': 10,
          'text-offset': [0, 1.5],
          'text-anchor': 'top',
        }}
        paint={labelPaint}
      />
    </Source>
  );
}
