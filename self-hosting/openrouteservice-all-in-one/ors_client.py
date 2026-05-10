"""
ORS Python client example — switch between public API and self-hosted with one parameter.
Requires: pip install openrouteservice
"""

import openrouteservice

# --- Self-hosted (no API key needed) ---
client = openrouteservice.Client(
    base_url="http://localhost:8080/ors"
)

# LA → SF driving route
route = client.directions(
    coordinates=[[-118.2437, 34.0522], [-122.4194, 37.7749]],
    profile="driving-car",
    format="geojson",
)

props = route["features"][0]["properties"]["summary"]
print(f"Distance: {props['distance'] / 1000:.1f} km")
print(f"Duration: {props['duration'] / 3600:.1f} h")

# Isochrone — 15-minute walking zone around downtown SF
iso = client.isochrones(
    locations=[[-122.4194, 37.7749]],
    profile="foot-walking",
    range=[900],      # seconds
)
print(f"Isochrone area: {iso['features'][0]['properties']['area']:.0f} m²")
