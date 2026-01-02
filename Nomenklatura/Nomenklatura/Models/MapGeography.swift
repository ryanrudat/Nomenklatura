//
//  MapGeography.swift
//  Nomenklatura
//
//  Geographic data structures for world map rendering
//  The PSR is a fictional nation on a fictional continent; all other powers are real circa 1950/1951
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
        case homeland       // PSR - deep red with gold border
        case socialistAlly  // USSR, Eastern Bloc - red tones
        case capitalist     // USA, Western Europe - blue tones
        case nonAligned     // India, Yugoslavia, Egypt - green tones
        case neutral        // Uncommitted nations - gray
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

/// Static world map data for the 1950s world with fictional PSR
struct WorldMapData {

    /// All map regions for the world circa 1950/1951
    /// The PSR is a fictional nation on a fictional continent; all others are real
    static func loadRegions() -> [MapRegion] {
        return [
            // The People's Socialist Republic (Player's Homeland)
            createPSR(),

            // Socialist Bloc (Real Nations)
            createSovietUnion(),
            createPoland(),
            createCzechoslovakia(),
            createChina(),

            // Western Powers (Real Nations)
            createUnitedStates(),
            createUnitedKingdom(),
            createFrance(),
            createWestGermany(),
            createJapan(),

            // Non-Aligned Nations (Real Nations)
            createIndia(),
            createYugoslavia(),
            createEgypt(),
            createMexico(),

            // Oceans
            createAtlanticOcean(),
            createPacificOcean(),
            createIndianOcean()
        ]
    }

    // MARK: - PSR (Player Homeland - Fictional)

    /// The People's Socialist Republic - a fictional nation on a fictional continent
    /// Geographically positioned in the southern hemisphere, distinct from all real landmasses
    private static func createPSR() -> MapRegion {
        // Fictional continent in the southern Atlantic/Indian Ocean region
        // Large enough to be significant, isolated enough to be independent
        let points: [CGPoint] = [
            // Northwestern coast
            CGPoint(x: 0.30, y: 0.55),
            CGPoint(x: 0.28, y: 0.58),
            CGPoint(x: 0.26, y: 0.62),
            // Western coast
            CGPoint(x: 0.25, y: 0.66),
            CGPoint(x: 0.26, y: 0.70),
            // Southwestern coast
            CGPoint(x: 0.28, y: 0.73),
            CGPoint(x: 0.32, y: 0.75),
            // Southern coast
            CGPoint(x: 0.38, y: 0.76),
            CGPoint(x: 0.44, y: 0.74),
            // Southeastern coast
            CGPoint(x: 0.48, y: 0.71),
            CGPoint(x: 0.50, y: 0.67),
            // Eastern coast
            CGPoint(x: 0.49, y: 0.62),
            CGPoint(x: 0.47, y: 0.58),
            // Northeastern coast
            CGPoint(x: 0.44, y: 0.55),
            CGPoint(x: 0.40, y: 0.53),
            // Northern coast
            CGPoint(x: 0.35, y: 0.52),
            CGPoint(x: 0.32, y: 0.53),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.38, y: 0.64)
        let bounds = CGRect(x: 0.25, y: 0.52, width: 0.25, height: 0.24)

        return MapRegion(
            id: "psr",
            displayName: "P.S.R.",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .homeland
        )
    }

    // MARK: - Soviet Union

    private static func createSovietUnion() -> MapRegion {
        // USSR spanning Eastern Europe to the Pacific
        let points: [CGPoint] = [
            // Eastern Europe
            CGPoint(x: 0.52, y: 0.26),
            CGPoint(x: 0.56, y: 0.22),
            CGPoint(x: 0.62, y: 0.20),
            CGPoint(x: 0.72, y: 0.18),
            CGPoint(x: 0.82, y: 0.16),
            // Siberia
            CGPoint(x: 0.90, y: 0.18),
            CGPoint(x: 0.94, y: 0.22),
            CGPoint(x: 0.96, y: 0.28),
            // Pacific coast
            CGPoint(x: 0.94, y: 0.34),
            CGPoint(x: 0.90, y: 0.36),
            // Central Asia
            CGPoint(x: 0.72, y: 0.38),
            CGPoint(x: 0.62, y: 0.36),
            CGPoint(x: 0.56, y: 0.34),
            CGPoint(x: 0.52, y: 0.30),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.72, y: 0.28)
        let bounds = CGRect(x: 0.52, y: 0.16, width: 0.44, height: 0.22)

        return MapRegion(
            id: "soviet_union",
            displayName: "Soviet Union",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Poland

    private static func createPoland() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.50, y: 0.28),
            CGPoint(x: 0.52, y: 0.26),
            CGPoint(x: 0.54, y: 0.28),
            CGPoint(x: 0.54, y: 0.32),
            CGPoint(x: 0.52, y: 0.34),
            CGPoint(x: 0.50, y: 0.32),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.52, y: 0.30)
        let bounds = CGRect(x: 0.50, y: 0.26, width: 0.04, height: 0.08)

        return MapRegion(
            id: "poland",
            displayName: "Poland",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Czechoslovakia

    private static func createCzechoslovakia() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.49, y: 0.32),
            CGPoint(x: 0.52, y: 0.31),
            CGPoint(x: 0.53, y: 0.34),
            CGPoint(x: 0.51, y: 0.36),
            CGPoint(x: 0.48, y: 0.35),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.50, y: 0.34)
        let bounds = CGRect(x: 0.48, y: 0.31, width: 0.05, height: 0.05)

        return MapRegion(
            id: "czechoslovakia",
            displayName: "Czechoslovakia",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - China

    private static func createChina() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.74, y: 0.38),
            CGPoint(x: 0.84, y: 0.36),
            CGPoint(x: 0.88, y: 0.42),
            CGPoint(x: 0.86, y: 0.52),
            CGPoint(x: 0.78, y: 0.54),
            CGPoint(x: 0.72, y: 0.50),
            CGPoint(x: 0.70, y: 0.44),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.79, y: 0.45)
        let bounds = CGRect(x: 0.70, y: 0.36, width: 0.18, height: 0.18)

        return MapRegion(
            id: "china",
            displayName: "China",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - United States

    private static func createUnitedStates() -> MapRegion {
        // Continental USA
        let points: [CGPoint] = [
            // Pacific Northwest
            CGPoint(x: 0.08, y: 0.30),
            CGPoint(x: 0.10, y: 0.34),
            CGPoint(x: 0.08, y: 0.40),
            // California
            CGPoint(x: 0.06, y: 0.44),
            // Southwest
            CGPoint(x: 0.10, y: 0.46),
            CGPoint(x: 0.14, y: 0.46),
            // Gulf Coast
            CGPoint(x: 0.18, y: 0.48),
            CGPoint(x: 0.22, y: 0.46),
            // Florida
            CGPoint(x: 0.24, y: 0.48),
            CGPoint(x: 0.22, y: 0.44),
            // East Coast
            CGPoint(x: 0.24, y: 0.38),
            CGPoint(x: 0.22, y: 0.32),
            // New England
            CGPoint(x: 0.24, y: 0.30),
            // Northern Border
            CGPoint(x: 0.20, y: 0.28),
            CGPoint(x: 0.14, y: 0.28),
            CGPoint(x: 0.10, y: 0.28),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.15, y: 0.38)
        let bounds = CGRect(x: 0.06, y: 0.28, width: 0.18, height: 0.20)

        return MapRegion(
            id: "united_states",
            displayName: "United States",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - United Kingdom

    private static func createUnitedKingdom() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.44, y: 0.26),
            CGPoint(x: 0.46, y: 0.24),
            CGPoint(x: 0.47, y: 0.28),
            CGPoint(x: 0.46, y: 0.32),
            CGPoint(x: 0.44, y: 0.30),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.45, y: 0.28)
        let bounds = CGRect(x: 0.44, y: 0.24, width: 0.03, height: 0.08)

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
            CGPoint(x: 0.44, y: 0.34),
            CGPoint(x: 0.48, y: 0.32),
            CGPoint(x: 0.49, y: 0.38),
            CGPoint(x: 0.46, y: 0.42),
            CGPoint(x: 0.42, y: 0.38),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.46, y: 0.37)
        let bounds = CGRect(x: 0.42, y: 0.32, width: 0.07, height: 0.10)

        return MapRegion(
            id: "france",
            displayName: "France",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - West Germany

    private static func createWestGermany() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.48, y: 0.30),
            CGPoint(x: 0.50, y: 0.28),
            CGPoint(x: 0.51, y: 0.32),
            CGPoint(x: 0.50, y: 0.36),
            CGPoint(x: 0.48, y: 0.34),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.49, y: 0.32)
        let bounds = CGRect(x: 0.48, y: 0.28, width: 0.03, height: 0.08)

        return MapRegion(
            id: "west_germany",
            displayName: "W. Germany",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - Japan

    private static func createJapan() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.90, y: 0.38),
            CGPoint(x: 0.94, y: 0.36),
            CGPoint(x: 0.94, y: 0.44),
            CGPoint(x: 0.90, y: 0.46),
            CGPoint(x: 0.88, y: 0.42),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.91, y: 0.41)
        let bounds = CGRect(x: 0.88, y: 0.36, width: 0.06, height: 0.10)

        return MapRegion(
            id: "japan",
            displayName: "Japan",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .capitalist
        )
    }

    // MARK: - India

    private static func createIndia() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.66, y: 0.42),
            CGPoint(x: 0.72, y: 0.40),
            CGPoint(x: 0.74, y: 0.48),
            CGPoint(x: 0.70, y: 0.56),
            CGPoint(x: 0.66, y: 0.52),
            CGPoint(x: 0.64, y: 0.46),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.69, y: 0.48)
        let bounds = CGRect(x: 0.64, y: 0.40, width: 0.10, height: 0.16)

        return MapRegion(
            id: "india",
            displayName: "India",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .nonAligned
        )
    }

    // MARK: - Yugoslavia

    private static func createYugoslavia() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.50, y: 0.38),
            CGPoint(x: 0.54, y: 0.36),
            CGPoint(x: 0.55, y: 0.40),
            CGPoint(x: 0.52, y: 0.43),
            CGPoint(x: 0.49, y: 0.41),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.52, y: 0.40)
        let bounds = CGRect(x: 0.49, y: 0.36, width: 0.06, height: 0.07)

        return MapRegion(
            id: "yugoslavia",
            displayName: "Yugoslavia",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .nonAligned
        )
    }

    // MARK: - Egypt

    private static func createEgypt() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.54, y: 0.46),
            CGPoint(x: 0.58, y: 0.44),
            CGPoint(x: 0.60, y: 0.50),
            CGPoint(x: 0.56, y: 0.54),
            CGPoint(x: 0.52, y: 0.50),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.56, y: 0.49)
        let bounds = CGRect(x: 0.52, y: 0.44, width: 0.08, height: 0.10)

        return MapRegion(
            id: "egypt",
            displayName: "Egypt",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .nonAligned
        )
    }

    // MARK: - Mexico

    private static func createMexico() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.06, y: 0.44),
            CGPoint(x: 0.12, y: 0.46),
            CGPoint(x: 0.16, y: 0.50),
            CGPoint(x: 0.12, y: 0.56),
            CGPoint(x: 0.06, y: 0.54),
            CGPoint(x: 0.04, y: 0.48),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.10, y: 0.50)
        let bounds = CGRect(x: 0.04, y: 0.44, width: 0.12, height: 0.12)

        return MapRegion(
            id: "mexico",
            displayName: "Mexico",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .nonAligned
        )
    }

    // MARK: - Atlantic Ocean

    private static func createAtlanticOcean() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.26, y: 0.20),
            CGPoint(x: 0.42, y: 0.20),
            CGPoint(x: 0.42, y: 0.80),
            CGPoint(x: 0.26, y: 0.80),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.34, y: 0.50)
        let bounds = CGRect(x: 0.26, y: 0.20, width: 0.16, height: 0.60)

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
            CGPoint(x: 0.00, y: 0.20),
            CGPoint(x: 0.06, y: 0.20),
            CGPoint(x: 0.06, y: 0.80),
            CGPoint(x: 0.00, y: 0.80),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.03, y: 0.50)
        let bounds = CGRect(x: 0.00, y: 0.20, width: 0.06, height: 0.60)

        return MapRegion(
            id: "pacific_ocean",
            displayName: "Pacific Ocean",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .ocean
        )
    }

    // MARK: - Indian Ocean

    private static func createIndianOcean() -> MapRegion {
        let points: [CGPoint] = [
            CGPoint(x: 0.58, y: 0.56),
            CGPoint(x: 0.74, y: 0.56),
            CGPoint(x: 0.74, y: 0.80),
            CGPoint(x: 0.58, y: 0.80),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = CGPoint(x: 0.66, y: 0.68)
        let bounds = CGRect(x: 0.58, y: 0.56, width: 0.16, height: 0.24)

        return MapRegion(
            id: "indian_ocean",
            displayName: "Indian Ocean",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .ocean
        )
    }
}

// MARK: - Deprecated Alias

/// Type alias for backwards compatibility
typealias AlternateWorldMap = WorldMapData
