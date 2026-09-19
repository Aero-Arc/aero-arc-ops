CREATE ROLE aero_arc LOGIN PASSWORD 'aero_arc';
CREATE DATABASE aero_arc OWNER aero_arc;

\connect aero_arc

CREATE EXTENSION IF NOT EXISTS postgis;
