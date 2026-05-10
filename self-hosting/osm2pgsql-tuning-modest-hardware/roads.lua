-- roads.lua — minimal flex-mode style for osm2pgsql
-- Imports only road ways; ignores all other OSM features.
-- Reduces table size and index build time compared to the legacy pgsql mode.

local tables = {}

tables.roads = osm2pgsql.define_way_table('roads', {
    { column = 'name',     type = 'text' },
    { column = 'highway',  type = 'text' },
    { column = 'surface',  type = 'text' },
    { column = 'maxspeed', type = 'text' },
    { column = 'geom',     type = 'linestring', projection = 4326 },
})

function osm2pgsql.process_way(object)
    if object.tags.highway then
        tables.roads:insert({
            name     = object.tags.name,
            highway  = object.tags.highway,
            surface  = object.tags.surface,
            maxspeed = object.tags.maxspeed,
            geom     = object:as_linestring(),
        })
    end
end
