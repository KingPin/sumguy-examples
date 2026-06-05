-- style.lua — minimal osm2pgsql flex-output style for the Martin tile stack
--
-- Produces three tables in the `osm` schema, with geometries in EPSG:3857
-- (Web Mercator), which is exactly what `martin-config.yaml` auto-publishes:
--
--   osm.roads     (linestrings) — anything tagged highway=*
--   osm.water     (polygons)    — natural=water, waterway=riverbank, landuse=reservoir
--   osm.buildings (polygons)    — anything tagged building=*
--
-- This is deliberately small and readable, not a full OpenMapTiles schema.
-- It exists so the example stack actually runs end to end. Extend it with
-- more layers (landuse, places, POIs) once you know which tiles you need.
--
-- Run it via the osm2pgsql command in the README:
--   --output=flex --style=/data/style.lua
--
-- Flex-output reference: https://osm2pgsql.org/doc/manual.html#the-flex-output

local tables = {}

-- Roads: linestrings keyed off highway=*
tables.roads = osm2pgsql.define_way_table('roads', {
    { column = 'name',     type = 'text' },
    { column = 'highway',  type = 'text' },
    { column = 'surface',  type = 'text' },
    { column = 'maxspeed', type = 'text' },
    { column = 'geom',     type = 'linestring', projection = 3857, not_null = true },
}, { schema = 'osm' })

-- Water: areas (closed ways + multipolygon relations)
tables.water = osm2pgsql.define_area_table('water', {
    { column = 'name', type = 'text' },
    { column = 'kind', type = 'text' },
    { column = 'geom', type = 'geometry', projection = 3857, not_null = true },
}, { schema = 'osm' })

-- Buildings: areas (closed ways + multipolygon relations)
tables.buildings = osm2pgsql.define_area_table('buildings', {
    { column = 'name',     type = 'text' },
    { column = 'building', type = 'text' },
    { column = 'geom',     type = 'geometry', projection = 3857, not_null = true },
}, { schema = 'osm' })

-- Is this set of tags a water feature we want as a polygon?
local function water_kind(tags)
    if tags.natural == 'water' then return 'water' end
    if tags.waterway == 'riverbank' then return 'riverbank' end
    if tags.landuse == 'reservoir' then return 'reservoir' end
    return nil
end

function osm2pgsql.process_way(object)
    local tags = object.tags

    -- Roads are linear features.
    if tags.highway then
        tables.roads:insert({
            name     = tags.name,
            highway  = tags.highway,
            surface  = tags.surface,
            maxspeed = tags.maxspeed,
            geom     = object:as_linestring(),
        })
    end

    -- Areas only make sense for closed ways.
    if object.is_closed then
        local kind = water_kind(tags)
        if kind then
            tables.water:insert({
                name = tags.name,
                kind = kind,
                geom = object:as_polygon(),
            })
        end

        if tags.building then
            tables.buildings:insert({
                name     = tags.name,
                building = tags.building,
                geom     = object:as_polygon(),
            })
        end
    end
end

function osm2pgsql.process_relation(object)
    local tags = object.tags

    -- Only multipolygon relations become areas.
    if tags.type ~= 'multipolygon' then
        return
    end

    local kind = water_kind(tags)
    if kind then
        tables.water:insert({
            name = tags.name,
            kind = kind,
            geom = object:as_multipolygon(),
        })
    end

    if tags.building then
        tables.buildings:insert({
            name     = tags.name,
            building = tags.building,
            geom     = object:as_multipolygon(),
        })
    end
end
