//
//  MapGeography.swift
//  Nomenklatura
//
//  Geographic data structures for world map rendering
//

import Foundation
import CoreGraphics

// MARK: - Map Region

/// Represents a geographic region for map rendering
struct MapRegion: Codable, Identifiable {
    let id: String                      // Matches ForeignCountry.countryId or special region
    let displayName: String
    let polygons: [MapPolygon]          // Can have multiple (islands, exclaves)
    let centroid: CGPoint               // For label placement
    let bounds: CGRect
    let politicalAlignment: PoliticalAlignment
    let isOccupied: Bool                // Territory under foreign occupation
    let controlledBy: String?           // If occupied, who controls it

    init(id: String, displayName: String, polygons: [MapPolygon], centroid: CGPoint, bounds: CGRect, politicalAlignment: PoliticalAlignment, isOccupied: Bool = false, controlledBy: String? = nil) {
        self.id = id
        self.displayName = displayName
        self.polygons = polygons
        self.centroid = centroid
        self.bounds = bounds
        self.politicalAlignment = politicalAlignment
        self.isOccupied = isOccupied
        self.controlledBy = controlledBy
    }

    /// Political alignment determines map color
    enum PoliticalAlignment: String, Codable {
        case homeland       // PSRA - deep red with gold border
        case socialistAlly  // USSR, Germany - red tones
        case capitalist     // UK, Canada, France, Cuba - blue tones
        case fascist        // Italy, Spain - brown tones
        case pacificHostile // Japan - distinct hostile color
        case neutral        // Mexico, China - gray
        case occupied       // Territories under occupation (Hawaii, E. Alaska)
        case ocean          // Ocean areas
        case unclaimed      // Unclaimed/minor territories
    }
}

// MARK: - Map Polygon

/// A single polygon representing part of a region (for multi-polygon features)
struct MapPolygon: Codable {
    let points: [CGPoint]
    let isHole: Bool  // For lakes, enclaves

    init(points: [CGPoint], isHole: Bool = false) {
        self.points = points
        self.isHole = isHole
    }
}

// Note: CGPoint and CGRect already conform to Codable in CoreGraphics

// MARK: - Map Projection

/// Projection for converting lat/long to screen coordinates
enum MapProjection: String, Codable {
    case robinson       // Compromise projection, good for world maps
    case mercator       // Classic, good for small areas
    case equirectangular // Simple, good for mid-latitudes

    /// Project geographic coordinates to screen coordinates
    /// - Parameters:
    ///   - latitude: Latitude in degrees (-90 to 90)
    ///   - longitude: Longitude in degrees (-180 to 180)
    ///   - size: The size of the target view/scene
    /// - Returns: Screen coordinates within the given size
    func project(latitude: Double, longitude: Double, into size: CGSize) -> CGPoint {
        switch self {
        case .equirectangular:
            return projectEquirectangular(latitude: latitude, longitude: longitude, into: size)
        case .mercator:
            return projectMercator(latitude: latitude, longitude: longitude, into: size)
        case .robinson:
            return projectRobinson(latitude: latitude, longitude: longitude, into: size)
        }
    }

    // MARK: - Equirectangular Projection

    private func projectEquirectangular(latitude: Double, longitude: Double, into size: CGSize) -> CGPoint {
        // Simple linear mapping
        let x = (longitude + 180) / 360 * Double(size.width)
        let y = (90 - latitude) / 180 * Double(size.height)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Mercator Projection

    private func projectMercator(latitude: Double, longitude: Double, into size: CGSize) -> CGPoint {
        // Mercator: stretches at poles
        let x = (longitude + 180) / 360 * Double(size.width)

        // Clamp latitude to avoid infinity at poles
        let clampedLat = max(-85, min(85, latitude))
        let latRad = clampedLat * .pi / 180
        let mercatorY = log(tan(.pi / 4 + latRad / 2))
        let y = (1 - mercatorY / .pi) / 2 * Double(size.height)

        return CGPoint(x: x, y: y)
    }

    // MARK: - Robinson Projection

    private func projectRobinson(latitude: Double, longitude: Double, into size: CGSize) -> CGPoint {
        // Robinson projection parameters (simplified)
        // Uses polynomial approximation for X and Y
        let absLat = abs(latitude)

        // Polynomial coefficients for Robinson projection
        let xCoeff = 1 - (absLat / 90) * (absLat / 90) * 0.1
        let yCoeff = latitude / 90 * 0.87

        let x = (longitude / 180) * xCoeff * Double(size.width) / 2 + Double(size.width) / 2
        let y = Double(size.height) / 2 - yCoeff * Double(size.height) / 2

        return CGPoint(x: x, y: y)
    }
}

// MARK: - World Map Data

/// Static world map data for the alternate 1950s
struct AlternateWorldMap {

    /// All map regions for the alternate history world
    static func loadRegions() -> [MapRegion] {
        return [
            // PSRA - The People's Socialist Republic of America
            createPSRA(),

            // Socialist Allies
            createSovietUnion(),
            createGermany(),

            // Hostile Capitalist Powers
            createCanada(),
            createUnitedKingdom(),
            createFrance(),
            createCuba(),

            // Fascist Powers
            createItaly(),
            createSpain(),

            // Pacific Theater
            createJapan(),
            createHawaii(),

            // Neutral Powers
            createMexico(),
            createChina(),

            // Occupied Territories
            createEasternAlaska(),

            // Oceans
            createAtlanticOcean(),
            createPacificOcean()
        ]
    }

    // MARK: - PSRA (Player Homeland)

    private static func createPSRA() -> MapRegion {
        // Continental US + British Columbia + Alberta (seized 1941-42)
        // Simplified polygon for the combined territory
        let points: [CGPoint] = [
            // Pacific Northwest (including seized BC)
            CGPoint(x: 0.12, y: 0.28),  // Northern BC
            CGPoint(x: 0.14, y: 0.32),  // Southern BC
            CGPoint(x: 0.12, y: 0.36),  // Washington
            CGPoint(x: 0.10, y: 0.42),  // Oregon
            CGPoint(x: 0.08, y: 0.50),  // California coast
            CGPoint(x: 0.10, y: 0.56),  // Southern California
            // Southwest
            CGPoint(x: 0.14, y: 0.54),  // Arizona
            CGPoint(x: 0.18, y: 0.56),  // New Mexico
            CGPoint(x: 0.20, y: 0.54),  // Texas panhandle
            CGPoint(x: 0.24, y: 0.58),  // Texas coast
            // Gulf Coast & Southeast
            CGPoint(x: 0.28, y: 0.56),  // Louisiana
            CGPoint(x: 0.32, y: 0.54),  // Mississippi/Alabama
            CGPoint(x: 0.36, y: 0.50),  // Florida panhandle
            CGPoint(x: 0.38, y: 0.54),  // Florida
            // East Coast
            CGPoint(x: 0.36, y: 0.46),  // Georgia
            CGPoint(x: 0.34, y: 0.42),  // Carolinas
            CGPoint(x: 0.36, y: 0.38),  // Virginia
            CGPoint(x: 0.38, y: 0.36),  // Mid-Atlantic
            CGPoint(x: 0.36, y: 0.32),  // New England
            CGPoint(x: 0.34, y: 0.30),  // Maine
            // Northern Border (with Canada)
            CGPoint(x: 0.30, y: 0.28),  // Great Lakes
            CGPoint(x: 0.24, y: 0.28),  // Upper Midwest
            CGPoint(x: 0.18, y: 0.26),  // Northern Plains
            CGPoint(x: 0.16, y: 0.24),  // Montana
            // Alberta (seized territory)
            CGPoint(x: 0.16, y: 0.22),  // Alberta south
            CGPoint(x: 0.14, y: 0.20),  // Alberta north
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.22, y: 0.40)
        let bounds = CGRect(x: 0.08, y: 0.20, width: 0.32, height: 0.38)

        return MapRegion(
            id: "psra",
            displayName: "P.S.R.A.",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .homeland
        )
    }

    // MARK: - Soviet Union

    private static func createSovietUnion() -> MapRegion {
        // USSR including Eastern Alaska
        let points: [CGPoint] = [
            // Eastern Europe
            CGPoint(x: 0.50, y: 0.26),
            CGPoint(x: 0.54, y: 0.22),
            CGPoint(x: 0.60, y: 0.20),
            CGPoint(x: 0.70, y: 0.18),
            CGPoint(x: 0.80, y: 0.16),
            // Siberia
            CGPoint(x: 0.88, y: 0.18),
            CGPoint(x: 0.92, y: 0.22),
            CGPoint(x: 0.94, y: 0.28),
            // Pacific coast
            CGPoint(x: 0.92, y: 0.34),
            CGPoint(x: 0.88, y: 0.36),
            // Central Asia
            CGPoint(x: 0.70, y: 0.38),
            CGPoint(x: 0.60, y: 0.36),
            CGPoint(x: 0.54, y: 0.34),
            CGPoint(x: 0.50, y: 0.30),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.70, y: 0.28)
        let bounds = CGRect(x: 0.50, y: 0.16, width: 0.44, height: 0.22)

        return MapRegion(
            id: "soviet_union",
            displayName: "Soviet Union",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Germany (Socialist Republic)

    private static func createGermany() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.48, y: 0.32),
            CGPoint(x: 0.50, y: 0.30),
            CGPoint(x: 0.52, y: 0.32),
            CGPoint(x: 0.52, y: 0.36),
            CGPoint(x: 0.50, y: 0.38),
            CGPoint(x: 0.48, y: 0.36),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.50, y: 0.34)
        let bounds = CGRect(x: 0.48, y: 0.30, width: 0.04, height: 0.08)

        return MapRegion(
            id: "germany",
            displayName: "Germany",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Canada (Lost BC & Alberta)

    private static func createCanada() -> MapRegion {
        // Canada minus BC and Alberta
        let points: [CGPoint] = [
            CGPoint(x: 0.16, y: 0.16),  // Manitoba
            CGPoint(x: 0.20, y: 0.12),  // Hudson Bay
            CGPoint(x: 0.28, y: 0.10),  // Quebec
            CGPoint(x: 0.34, y: 0.16),  // Maritimes
            CGPoint(x: 0.32, y: 0.22),  // Quebec south
            CGPoint(x: 0.28, y: 0.26),  // Ontario
            CGPoint(x: 0.22, y: 0.24),  // Great Lakes
            CGPoint(x: 0.18, y: 0.22),  // Manitoba south
            CGPoint(x: 0.16, y: 0.20),  // Saskatchewan
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.26, y: 0.18)
        let bounds = CGRect(x: 0.16, y: 0.10, width: 0.18, height: 0.16)

        return MapRegion(
            id: "canada",
            displayName: "Canada",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - United Kingdom

    private static func createUnitedKingdom() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.44, y: 0.28),
            CGPoint(x: 0.46, y: 0.26),
            CGPoint(x: 0.46, y: 0.32),
            CGPoint(x: 0.44, y: 0.34),
            CGPoint(x: 0.42, y: 0.32),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.44, y: 0.30)
        let bounds = CGRect(x: 0.42, y: 0.26, width: 0.04, height: 0.08)

        return MapRegion(
            id: "united_kingdom",
            displayName: "United Kingdom",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - France

    private static func createFrance() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.44, y: 0.36),
            CGPoint(x: 0.48, y: 0.34),
            CGPoint(x: 0.48, y: 0.40),
            CGPoint(x: 0.44, y: 0.42),
            CGPoint(x: 0.42, y: 0.38),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.45, y: 0.38)
        let bounds = CGRect(x: 0.42, y: 0.34, width: 0.06, height: 0.08)

        return MapRegion(
            id: "france",
            displayName: "France",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - Cuba (Government-in-Exile)

    private static func createCuba() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.26, y: 0.54),
            CGPoint(x: 0.30, y: 0.52),
            CGPoint(x: 0.30, y: 0.54),
            CGPoint(x: 0.26, y: 0.56),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.28, y: 0.54)
        let bounds = CGRect(x: 0.26, y: 0.52, width: 0.04, height: 0.04)

        return MapRegion(
            id: "cuba",
            displayName: "Cuba",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - Italy (Fascist)

    private static func createItaly() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.50, y: 0.40),
            CGPoint(x: 0.52, y: 0.42),
            CGPoint(x: 0.50, y: 0.50),
            CGPoint(x: 0.48, y: 0.48),
            CGPoint(x: 0.48, y: 0.42),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.50, y: 0.45)
        let bounds = CGRect(x: 0.48, y: 0.40, width: 0.04, height: 0.10)

        return MapRegion(
            id: "italy",
            displayName: "Italy",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .fascist
        )
    }

    // MARK: - Spain (Fascist)

    private static func createSpain() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.40, y: 0.42),
            CGPoint(x: 0.44, y: 0.42),
            CGPoint(x: 0.44, y: 0.48),
            CGPoint(x: 0.40, y: 0.48),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.42, y: 0.45)
        let bounds = CGRect(x: 0.40, y: 0.42, width: 0.04, height: 0.06)

        return MapRegion(
            id: "spain",
            displayName: "Spain",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .fascist
        )
    }

    // MARK: - Japan

    private static func createJapan() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.88, y: 0.38),
            CGPoint(x: 0.92, y: 0.36),
            CGPoint(x: 0.92, y: 0.44),
            CGPoint(x: 0.88, y: 0.46),
            CGPoint(x: 0.86, y: 0.42),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.90, y: 0.41)
        let bounds = CGRect(x: 0.86, y: 0.36, width: 0.06, height: 0.10)

        return MapRegion(
            id: "japan",
            displayName: "Japan",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .pacificHostile
        )
    }

    // MARK: - Hawaii (Japanese Occupied)

    private static func createHawaii() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.02, y: 0.48),
            CGPoint(x: 0.04, y: 0.46),
            CGPoint(x: 0.06, y: 0.48),
            CGPoint(x: 0.04, y: 0.50),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.04, y: 0.48)
        let bounds = CGRect(x: 0.02, y: 0.46, width: 0.04, height: 0.04)

        return MapRegion(
            id: "hawaii",
            displayName: "Hawaii",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .occupied,
            isOccupied: true,
            controlledBy: "japan"
        )
    }

    // MARK: - Mexico (Neutral)

    private static func createMexico() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.10, y: 0.56),
            CGPoint(x: 0.18, y: 0.58),
            CGPoint(x: 0.22, y: 0.62),
            CGPoint(x: 0.18, y: 0.68),
            CGPoint(x: 0.12, y: 0.66),
            CGPoint(x: 0.08, y: 0.60),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.15, y: 0.62)
        let bounds = CGRect(x: 0.08, y: 0.56, width: 0.14, height: 0.12)

        return MapRegion(
            id: "mexico",
            displayName: "Mexico",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .neutral
        )
    }

    // MARK: - China (Contested)

    private static func createChina() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.72, y: 0.40),
            CGPoint(x: 0.82, y: 0.38),
            CGPoint(x: 0.86, y: 0.44),
            CGPoint(x: 0.84, y: 0.54),
            CGPoint(x: 0.76, y: 0.56),
            CGPoint(x: 0.70, y: 0.52),
            CGPoint(x: 0.68, y: 0.46),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.77, y: 0.47)
        let bounds = CGRect(x: 0.68, y: 0.38, width: 0.18, height: 0.18)

        return MapRegion(
            id: "china",
            displayName: "China",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .neutral
        )
    }

    // MARK: - Eastern Alaska (Soviet Occupied)

    private static func createEasternAlaska() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.04, y: 0.18),
            CGPoint(x: 0.08, y: 0.16),
            CGPoint(x: 0.10, y: 0.22),
            CGPoint(x: 0.06, y: 0.24),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.07, y: 0.20)
        let bounds = CGRect(x: 0.04, y: 0.16, width: 0.06, height: 0.08)

        return MapRegion(
            id: "eastern_alaska",
            displayName: "E. Alaska",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .occupied,
            isOccupied: true,
            controlledBy: "soviet_union"
        )
    }

    // MARK: - Atlantic Ocean

    private static func createAtlanticOcean() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.36, y: 0.30),
            CGPoint(x: 0.42, y: 0.26),
            CGPoint(x: 0.42, y: 0.60),
            CGPoint(x: 0.36, y: 0.56),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.39, y: 0.43)
        let bounds = CGRect(x: 0.36, y: 0.26, width: 0.06, height: 0.34)

        return MapRegion(
            id: "atlantic_ocean",
            displayName: "Atlantic Ocean",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .ocean
        )
    }

    // MARK: - Pacific Ocean

    private static func createPacificOcean() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.00, y: 0.30),
            CGPoint(x: 0.08, y: 0.30),
            CGPoint(x: 0.08, y: 0.60),
            CGPoint(x: 0.00, y: 0.60),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.04, y: 0.45)
        let bounds = CGRect(x: 0.00, y: 0.30, width: 0.08, height: 0.30)

        return MapRegion(
            id: "pacific_ocean",
            displayName: "Pacific Ocean",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .ocean
        )
    }
}
