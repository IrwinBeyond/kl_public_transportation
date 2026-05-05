-- GTFS Transit Visualization — PostGIS Materialized Views
-- Run against gis_malay database when GTFS data is loaded or updated.

-- Drop existing
DROP MATERIALIZED VIEW IF EXISTS public.transit_routes CASCADE;
DROP MATERIALIZED VIEW IF EXISTS public.transit_stops CASCADE;

-- Route lines: shapes aggregated into LineStrings, joined with route metadata
CREATE MATERIALIZED VIEW public.transit_routes AS
SELECT
  row_number() OVER ()::integer AS id,
  r.route_short_name,
  r.route_long_name,
  COALESCE('#' || NULLIF(r.route_color, ''), '#888888') AS route_color,
  'rapid-rail'::text AS agency,
  ST_Force2D(ST_SetSRID(sa.shape, 4326))::geometry(LineString, 4326) AS geom
FROM "rapid-rail".shapes_aggregated sa
JOIN "rapid-rail".trips t ON sa.shape_id = t.shape_id
JOIN "rapid-rail".routes r ON t.route_id = r.route_id
GROUP BY r.route_short_name, r.route_long_name, r.route_color, sa.shape
UNION ALL
SELECT
  row_number() OVER ()::integer + 100000 AS id,
  r.route_short_name,
  r.route_long_name,
  CASE WHEN r.route_color IS NOT NULL AND r.route_color <> ''
    THEN '#' || r.route_color ELSE '#115740' END AS route_color,
  'rapid-bus'::text AS agency,
  ST_Force2D(ST_SetSRID(sa.shape, 4326))::geometry(LineString, 4326) AS geom
FROM "rapid-bus".shapes_aggregated sa
JOIN "rapid-bus".trips t ON sa.shape_id = t.shape_id
JOIN "rapid-bus".routes r ON t.route_id = r.route_id
GROUP BY r.route_short_name, r.route_long_name, r.route_color, sa.shape
UNION ALL
SELECT
  row_number() OVER ()::integer + 200000 AS id,
  COALESCE(NULLIF(r.route_short_name, ''), r.route_long_name) AS route_short_name,
  r.route_long_name,
  '#FFCD00' AS route_color,
  'rapid-mrt'::text AS agency,
  ST_Force2D(ST_SetSRID(sa.shape, 4326))::geometry(LineString, 4326) AS geom
FROM "rapid-mrt".shapes_aggregated sa
JOIN "rapid-mrt".trips t ON sa.shape_id = t.shape_id
JOIN "rapid-mrt".routes r ON t.route_id = r.route_id
GROUP BY r.route_short_name, r.route_long_name, r.route_color, sa.shape;

CREATE INDEX idx_transit_routes_geom ON public.transit_routes USING GIST (geom);
ANALYZE public.transit_routes;

-- Stops: points with route info aggregated
CREATE MATERIALIZED VIEW public.transit_stops AS
SELECT
  s.stop_id,
  s.stop_name,
  s.stop_code,
  'ktmb'::text AS agency,
  COALESCE(STRING_AGG(DISTINCT r.route_short_name, ', '
    ORDER BY r.route_short_name), '') AS routes,
  ST_Force2D(s.stop_loc::geometry)::geometry(Point, 4326) AS geom
FROM ktmb.stops s
LEFT JOIN ktmb.stop_times st ON s.stop_id = st.stop_id
LEFT JOIN ktmb.trips t ON st.trip_id = t.trip_id
LEFT JOIN ktmb.routes r ON t.route_id = r.route_id
WHERE s.location_type = '0' OR s.location_type IS NULL
GROUP BY s.stop_id, s.stop_name, s.stop_code, s.stop_loc
UNION ALL
SELECT
  s.stop_id,
  s.stop_name,
  s.stop_code,
  'rapid-rail'::text AS agency,
  COALESCE(STRING_AGG(DISTINCT r.route_short_name, ', '
    ORDER BY r.route_short_name), '') AS routes,
  ST_Force2D(s.stop_loc::geometry)::geometry(Point, 4326) AS geom
FROM "rapid-rail".stops s
LEFT JOIN "rapid-rail".stop_times st ON s.stop_id = st.stop_id
LEFT JOIN "rapid-rail".trips t ON st.trip_id = t.trip_id
LEFT JOIN "rapid-rail".routes r ON t.route_id = r.route_id
WHERE s.location_type = '0' OR s.location_type IS NULL
GROUP BY s.stop_id, s.stop_name, s.stop_code, s.stop_loc
UNION ALL
SELECT
  s.stop_id,
  s.stop_name,
  s.stop_code,
  'rapid-bus'::text AS agency,
  COALESCE(STRING_AGG(DISTINCT r.route_short_name, ', '
    ORDER BY r.route_short_name), '') AS routes,
  ST_Force2D(s.stop_loc::geometry)::geometry(Point, 4326) AS geom
FROM "rapid-bus".stops s
LEFT JOIN "rapid-bus".stop_times st ON s.stop_id = st.stop_id
LEFT JOIN "rapid-bus".trips t ON st.trip_id = t.trip_id
LEFT JOIN "rapid-bus".routes r ON t.route_id = r.route_id
WHERE s.location_type = '0' OR s.location_type IS NULL
GROUP BY s.stop_id, s.stop_name, s.stop_code, s.stop_loc
UNION ALL
SELECT
  s.stop_id,
  s.stop_name,
  s.stop_code,
  'rapid-mrt'::text AS agency,
  COALESCE(STRING_AGG(DISTINCT
    COALESCE(NULLIF(r.route_short_name, ''), r.route_long_name), ', '
    ORDER BY COALESCE(NULLIF(r.route_short_name, ''), r.route_long_name)), '') AS routes,
  ST_Force2D(s.stop_loc::geometry)::geometry(Point, 4326) AS geom
FROM "rapid-mrt".stops s
LEFT JOIN "rapid-mrt".stop_times st ON s.stop_id = st.stop_id
LEFT JOIN "rapid-mrt".trips t ON st.trip_id = t.trip_id
LEFT JOIN "rapid-mrt".routes r ON t.route_id = r.route_id
WHERE s.location_type = '0' OR s.location_type IS NULL
GROUP BY s.stop_id, s.stop_name, s.stop_code, s.stop_loc;

CREATE INDEX idx_transit_stops_geom ON public.transit_stops USING GIST (geom);
ANALYZE public.transit_stops;

-- Run to refresh after GTFS data updates:
-- REFRESH MATERIALIZED VIEW public.transit_routes;
-- REFRESH MATERIALIZED VIEW public.transit_stops;
