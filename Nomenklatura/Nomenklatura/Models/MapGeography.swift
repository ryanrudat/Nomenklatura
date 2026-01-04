//
//  MapGeography.swift
//  Nomenklatura
//
//  Geographic data structures for world map rendering
//  The PSR is a large fictional island nation in the mid-Atlantic
//  All other powers are real circa 1950/1951
//
//  Coordinate System:
//  - x: 0.0 = 180°W, 0.5 = 0° (Prime Meridian), 1.0 = 180°E
//  - y: 0.0 = 90°N (North Pole), 0.5 = 0° (Equator), 1.0 = 90°S (South Pole)
//

import Foundation
import CoreGraphics

// MARK: - Map Region

/// Represents a geographic region for map rendering
struct MapRegion: Codable, Identifiable {
    let id: String
    let displayName: String
    let polygons: [MapPolygon]
    let centroid: CGPoint
    let bounds: CGRect
    let politicalAlignment: PoliticalAlignment
    let isOccupied: Bool
    let controlledBy: String?

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

struct MapPolygon: Codable {
    let points: [CGPoint]
    let isHole: Bool

    init(points: [CGPoint], isHole: Bool = false) {
        self.points = points
        self.isHole = isHole
    }
}

// MARK: - Coordinate Helpers

/// Convert longitude (-180 to 180) to normalized x (0 to 1)
private func lonToX(_ longitude: Double) -> CGFloat {
    CGFloat((longitude + 180.0) / 360.0)
}

/// Convert latitude (90 to -90) to normalized y (0 to 1)
private func latToY(_ latitude: Double) -> CGFloat {
    CGFloat((90.0 - latitude) / 180.0)
}

/// Create a CGPoint from longitude/latitude
private func coord(_ lon: Double, _ lat: Double) -> CGPoint {
    CGPoint(x: lonToX(lon), y: latToY(lat))
}

// MARK: - World Map Data

/// Static world map data for the 1950s world with fictional PSR
struct WorldMapData {

    static func loadRegions() -> [MapRegion] {
        var regions: [MapRegion] = []

        // The People's Socialist Republic (Player's Homeland)
        regions.append(contentsOf: createPSR())

        // Socialist Bloc
        regions.append(createSovietUnion())
        regions.append(createPoland())
        regions.append(createEastGermany())
        regions.append(createCzechoslovakia())
        regions.append(createHungary())
        regions.append(createRomania())
        regions.append(createBulgaria())
        regions.append(createChina())
        regions.append(createNorthKorea())

        // Western Powers
        regions.append(createUnitedStates())
        regions.append(createCanada())
        regions.append(createUnitedKingdom())
        regions.append(createFrance())
        regions.append(createWestGermany())
        regions.append(createItaly())
        regions.append(createSpain())
        regions.append(createPortugal())
        regions.append(createJapan())
        regions.append(createSouthKorea())
        regions.append(createAustralia())

        // Non-Aligned / Neutral
        regions.append(createIndia())
        regions.append(createYugoslavia())
        regions.append(createEgypt())
        regions.append(createIndonesia())
        regions.append(createBrazil())
        regions.append(createArgentina())
        regions.append(createMexico())
        regions.append(createTurkey())
        regions.append(createIran())
        regions.append(createSaudiArabia())
        regions.append(createSouthAfrica())

        // Africa (simplified regions)
        regions.append(createNorthAfrica())
        regions.append(createWestAfrica())
        regions.append(createCentralAfrica())
        regions.append(createEastAfrica())

        // Oceans
        regions.append(createAtlanticOcean())
        regions.append(createPacificOcean())
        regions.append(createIndianOcean())
        regions.append(createArcticOcean())

        return regions
    }

    // MARK: - PSR (Player Homeland)

    /// The People's Socialist Republic - a large island nation in the mid-Atlantic
    /// Located northwest of the Azores, between 40°N-52°N latitude
    /// Approximately 500,000 square miles (larger than Madagascar, smaller than Australia)
    private static func createPSR() -> [MapRegion] {
        // Main island - large landmass with realistic coastline
        // Centered around 45°W longitude, 46°N latitude
        let mainIslandPoints: [CGPoint] = [
            // Northern coast (rugged, fjord-like)
            coord(-52, 51),
            coord(-50, 52),
            coord(-47, 51.5),
            coord(-44, 52),
            coord(-41, 51),
            coord(-38, 51.5),
            coord(-36, 50),

            // Eastern coast (facing Europe)
            coord(-35, 48),
            coord(-34, 46),
            coord(-35, 44),
            coord(-36, 42),
            coord(-37, 40),

            // Southern coast (warmer, agricultural)
            coord(-39, 39),
            coord(-42, 38.5),
            coord(-45, 39),
            coord(-48, 38),
            coord(-51, 39),

            // Western coast (facing Americas)
            coord(-53, 41),
            coord(-54, 43),
            coord(-55, 45),
            coord(-54, 47),
            coord(-53, 49),
        ]

        let mainPolygon = MapPolygon(points: mainIslandPoints)
        let mainCentroid = coord(-45, 45)
        let mainBounds = CGRect(
            x: lonToX(-55),
            y: latToY(52),
            width: lonToX(-34) - lonToX(-55),
            height: latToY(38) - latToY(52)
        )

        let mainIsland = MapRegion(
            id: "psr",
            displayName: "P.S.R.",
            polygons: [mainPolygon],
            centroid: mainCentroid,
            bounds: mainBounds,
            politicalAlignment: .homeland
        )

        // Island Cluster - 4 small islands southwest of main island
        // Strategic naval bases and fishing grounds

        // Island 1 - Largest of the cluster
        let island1Points: [CGPoint] = [
            coord(-58, 38),
            coord(-56, 37.5),
            coord(-55, 38.5),
            coord(-56, 39.5),
            coord(-58, 39),
        ]
        let island1 = MapRegion(
            id: "psr_island1",
            displayName: "Krasny Island",
            polygons: [MapPolygon(points: island1Points)],
            centroid: coord(-56.5, 38.5),
            bounds: CGRect(x: lonToX(-58), y: latToY(39.5), width: 0.01, height: 0.01),
            politicalAlignment: .homeland
        )

        // Island 2 - Naval base
        let island2Points: [CGPoint] = [
            coord(-60, 37),
            coord(-58.5, 36.5),
            coord(-58, 37.5),
            coord(-59, 38),
            coord(-60, 37.5),
        ]
        let island2 = MapRegion(
            id: "psr_island2",
            displayName: "Svoboda Island",
            polygons: [MapPolygon(points: island2Points)],
            centroid: coord(-59, 37.2),
            bounds: CGRect(x: lonToX(-60), y: latToY(38), width: 0.008, height: 0.008),
            politicalAlignment: .homeland
        )

        // Island 3 - Smaller island
        let island3Points: [CGPoint] = [
            coord(-57, 36),
            coord(-55.5, 35.5),
            coord(-55, 36.5),
            coord(-56, 37),
        ]
        let island3 = MapRegion(
            id: "psr_island3",
            displayName: "Trudovaya Island",
            polygons: [MapPolygon(points: island3Points)],
            centroid: coord(-56, 36.2),
            bounds: CGRect(x: lonToX(-57), y: latToY(37), width: 0.006, height: 0.006),
            politicalAlignment: .homeland
        )

        // Island 4 - Smallest, exile colony
        let island4Points: [CGPoint] = [
            coord(-59, 35),
            coord(-57.5, 34.5),
            coord(-57, 35.5),
            coord(-58, 36),
        ]
        let island4 = MapRegion(
            id: "psr_island4",
            displayName: "Dalny Island",
            polygons: [MapPolygon(points: island4Points)],
            centroid: coord(-58, 35.2),
            bounds: CGRect(x: lonToX(-59), y: latToY(36), width: 0.005, height: 0.005),
            politicalAlignment: .homeland
        )

        return [mainIsland, island1, island2, island3, island4]
    }

    // MARK: - Soviet Union

    private static func createSovietUnion() -> MapRegion {
        // Massive territory from Eastern Europe to the Pacific
        let points: [CGPoint] = [
            // Baltic/Eastern Europe
            coord(20, 60),
            coord(28, 56),
            coord(24, 54),
            coord(22, 52),
            coord(28, 50),
            coord(32, 48),
            coord(40, 46),
            // Caucasus
            coord(42, 42),
            coord(48, 40),
            // Central Asia
            coord(55, 38),
            coord(62, 36),
            coord(70, 38),
            coord(75, 42),
            coord(80, 44),
            // Siberia/Mongolia border
            coord(90, 46),
            coord(100, 50),
            coord(110, 52),
            coord(120, 50),
            coord(130, 48),
            // Pacific coast
            coord(135, 50),
            coord(140, 54),
            coord(160, 60),
            coord(170, 64),
            // Arctic coast
            coord(180, 68),
            coord(150, 72),
            coord(120, 74),
            coord(90, 72),
            coord(60, 70),
            coord(40, 68),
            coord(30, 65),
        ]

        let polygon = MapPolygon(points: points)
        let centroid = coord(90, 58)
        let bounds = CGRect(x: lonToX(20), y: latToY(74), width: lonToX(180) - lonToX(20), height: latToY(36) - latToY(74))

        return MapRegion(
            id: "soviet_union",
            displayName: "Soviet Union",
            polygons: [polygon],
            centroid: centroid,
            bounds: bounds,
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Eastern Bloc

    private static func createPoland() -> MapRegion {
        let points: [CGPoint] = [
            coord(14, 54),
            coord(18, 55),
            coord(23, 54),
            coord(24, 52),
            coord(24, 50),
            coord(19, 49),
            coord(14, 50),
            coord(14, 52),
        ]
        return MapRegion(
            id: "poland",
            displayName: "Poland",
            polygons: [MapPolygon(points: points)],
            centroid: coord(19, 52),
            bounds: CGRect(x: lonToX(14), y: latToY(55), width: 0.03, height: 0.03),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createEastGermany() -> MapRegion {
        let points: [CGPoint] = [
            coord(10, 54),
            coord(14, 54),
            coord(15, 51),
            coord(12, 50),
            coord(10, 51),
        ]
        return MapRegion(
            id: "east_germany",
            displayName: "E. Germany",
            polygons: [MapPolygon(points: points)],
            centroid: coord(12, 52),
            bounds: CGRect(x: lonToX(10), y: latToY(54), width: 0.015, height: 0.02),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createCzechoslovakia() -> MapRegion {
        let points: [CGPoint] = [
            coord(12, 51),
            coord(18, 50),
            coord(22, 49),
            coord(18, 48),
            coord(14, 48),
            coord(12, 49),
        ]
        return MapRegion(
            id: "czechoslovakia",
            displayName: "Czechoslovakia",
            polygons: [MapPolygon(points: points)],
            centroid: coord(16, 49.5),
            bounds: CGRect(x: lonToX(12), y: latToY(51), width: 0.03, height: 0.02),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createHungary() -> MapRegion {
        let points: [CGPoint] = [
            coord(16, 48),
            coord(22, 48.5),
            coord(23, 46),
            coord(19, 45.5),
            coord(16, 46),
        ]
        return MapRegion(
            id: "hungary",
            displayName: "Hungary",
            polygons: [MapPolygon(points: points)],
            centroid: coord(19, 47),
            bounds: CGRect(x: lonToX(16), y: latToY(48.5), width: 0.02, height: 0.02),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createRomania() -> MapRegion {
        let points: [CGPoint] = [
            coord(22, 48),
            coord(28, 48),
            coord(30, 46),
            coord(29, 44),
            coord(25, 44),
            coord(22, 45),
        ]
        return MapRegion(
            id: "romania",
            displayName: "Romania",
            polygons: [MapPolygon(points: points)],
            centroid: coord(25, 46),
            bounds: CGRect(x: lonToX(22), y: latToY(48), width: 0.025, height: 0.02),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createBulgaria() -> MapRegion {
        let points: [CGPoint] = [
            coord(22, 44),
            coord(28, 44),
            coord(29, 42),
            coord(26, 41),
            coord(22, 42),
        ]
        return MapRegion(
            id: "bulgaria",
            displayName: "Bulgaria",
            polygons: [MapPolygon(points: points)],
            centroid: coord(25, 42.5),
            bounds: CGRect(x: lonToX(22), y: latToY(44), width: 0.02, height: 0.015),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createChina() -> MapRegion {
        let points: [CGPoint] = [
            // Northern border with USSR
            coord(75, 42),
            coord(90, 46),
            coord(100, 50),
            coord(115, 50),
            coord(125, 48),
            coord(130, 44),
            // Pacific coast
            coord(122, 40),
            coord(120, 32),
            coord(118, 26),
            coord(110, 22),
            // Southern border
            coord(100, 22),
            coord(98, 24),
            coord(92, 28),
            coord(88, 28),
            coord(80, 30),
            // Western border
            coord(74, 36),
        ]
        return MapRegion(
            id: "china",
            displayName: "China",
            polygons: [MapPolygon(points: points)],
            centroid: coord(105, 36),
            bounds: CGRect(x: lonToX(74), y: latToY(50), width: 0.16, height: 0.16),
            politicalAlignment: .socialistAlly
        )
    }

    private static func createNorthKorea() -> MapRegion {
        let points: [CGPoint] = [
            coord(124, 43),
            coord(130, 43),
            coord(129, 40),
            coord(127, 38),
            coord(124, 40),
        ]
        return MapRegion(
            id: "north_korea",
            displayName: "N. Korea",
            polygons: [MapPolygon(points: points)],
            centroid: coord(127, 40),
            bounds: CGRect(x: lonToX(124), y: latToY(43), width: 0.02, height: 0.03),
            politicalAlignment: .socialistAlly
        )
    }

    // MARK: - Western Powers

    private static func createUnitedStates() -> MapRegion {
        // Continental USA (simplified)
        let points: [CGPoint] = [
            // Pacific Northwest
            coord(-124, 48),
            coord(-122, 46),
            coord(-124, 42),
            // California
            coord(-122, 38),
            coord(-118, 34),
            coord(-117, 32),
            // Southwest
            coord(-110, 32),
            coord(-104, 32),
            // Texas
            coord(-100, 28),
            coord(-97, 26),
            coord(-94, 30),
            // Gulf Coast
            coord(-88, 30),
            coord(-84, 30),
            // Florida
            coord(-82, 28),
            coord(-80, 26),
            coord(-82, 30),
            // East Coast
            coord(-76, 34),
            coord(-74, 40),
            coord(-70, 42),
            coord(-68, 44),
            // Northern border
            coord(-72, 45),
            coord(-80, 42),
            coord(-84, 46),
            coord(-92, 48),
            coord(-104, 49),
            coord(-116, 49),
            coord(-124, 48),
        ]
        return MapRegion(
            id: "united_states",
            displayName: "United States",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-98, 38),
            bounds: CGRect(x: lonToX(-124), y: latToY(49), width: 0.15, height: 0.14),
            politicalAlignment: .capitalist
        )
    }

    private static func createCanada() -> MapRegion {
        let points: [CGPoint] = [
            // Alaska border
            coord(-140, 60),
            coord(-130, 54),
            coord(-124, 48),
            // US border
            coord(-116, 49),
            coord(-104, 49),
            coord(-92, 48),
            coord(-84, 46),
            coord(-80, 42),
            coord(-72, 45),
            // Atlantic
            coord(-60, 47),
            coord(-55, 50),
            coord(-58, 52),
            coord(-65, 60),
            coord(-80, 64),
            // Arctic
            coord(-90, 70),
            coord(-110, 72),
            coord(-130, 70),
            coord(-140, 68),
        ]
        return MapRegion(
            id: "canada",
            displayName: "Canada",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-100, 58),
            bounds: CGRect(x: lonToX(-140), y: latToY(72), width: 0.23, height: 0.17),
            politicalAlignment: .capitalist
        )
    }

    private static func createUnitedKingdom() -> MapRegion {
        let points: [CGPoint] = [
            // Scotland
            coord(-6, 58),
            coord(-2, 58),
            coord(-1, 55),
            // England
            coord(2, 53),
            coord(1, 51),
            coord(-1, 50),
            coord(-5, 50),
            coord(-5, 52),
            coord(-3, 54),
            coord(-5, 56),
        ]
        return MapRegion(
            id: "united_kingdom",
            displayName: "United Kingdom",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-2, 54),
            bounds: CGRect(x: lonToX(-6), y: latToY(58), width: 0.025, height: 0.045),
            politicalAlignment: .capitalist
        )
    }

    private static func createFrance() -> MapRegion {
        let points: [CGPoint] = [
            coord(-2, 48),
            coord(2, 51),
            coord(8, 49),
            coord(8, 46),
            coord(6, 44),
            coord(3, 42),
            coord(-1, 43),
            coord(-2, 46),
        ]
        return MapRegion(
            id: "france",
            displayName: "France",
            polygons: [MapPolygon(points: points)],
            centroid: coord(2, 46),
            bounds: CGRect(x: lonToX(-2), y: latToY(51), width: 0.03, height: 0.05),
            politicalAlignment: .capitalist
        )
    }

    private static func createWestGermany() -> MapRegion {
        let points: [CGPoint] = [
            coord(6, 54),
            coord(10, 54),
            coord(12, 50),
            coord(10, 47),
            coord(6, 47),
            coord(6, 50),
        ]
        return MapRegion(
            id: "west_germany",
            displayName: "W. Germany",
            polygons: [MapPolygon(points: points)],
            centroid: coord(9, 50),
            bounds: CGRect(x: lonToX(6), y: latToY(54), width: 0.02, height: 0.04),
            politicalAlignment: .capitalist
        )
    }

    private static func createItaly() -> MapRegion {
        let points: [CGPoint] = [
            coord(7, 46),
            coord(12, 46),
            coord(14, 42),
            coord(18, 40),
            coord(16, 38),
            coord(12, 37),
            coord(9, 40),
            coord(8, 44),
        ]
        return MapRegion(
            id: "italy",
            displayName: "Italy",
            polygons: [MapPolygon(points: points)],
            centroid: coord(12, 42),
            bounds: CGRect(x: lonToX(7), y: latToY(46), width: 0.03, height: 0.05),
            politicalAlignment: .capitalist
        )
    }

    private static func createSpain() -> MapRegion {
        let points: [CGPoint] = [
            coord(-9, 44),
            coord(-2, 44),
            coord(3, 42),
            coord(0, 38),
            coord(-5, 36),
            coord(-8, 37),
            coord(-9, 40),
        ]
        return MapRegion(
            id: "spain",
            displayName: "Spain",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-3, 40),
            bounds: CGRect(x: lonToX(-9), y: latToY(44), width: 0.035, height: 0.045),
            politicalAlignment: .capitalist
        )
    }

    private static func createPortugal() -> MapRegion {
        let points: [CGPoint] = [
            coord(-9, 42),
            coord(-7, 42),
            coord(-7, 37),
            coord(-9, 37),
        ]
        return MapRegion(
            id: "portugal",
            displayName: "Portugal",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-8, 39.5),
            bounds: CGRect(x: lonToX(-9), y: latToY(42), width: 0.01, height: 0.03),
            politicalAlignment: .capitalist
        )
    }

    private static func createJapan() -> MapRegion {
        let points: [CGPoint] = [
            // Hokkaido
            coord(140, 44),
            coord(145, 44),
            coord(145, 42),
            coord(140, 42),
            // Honshu
            coord(138, 40),
            coord(141, 38),
            coord(140, 35),
            coord(136, 34),
            coord(130, 34),
            coord(130, 36),
            coord(134, 38),
        ]
        return MapRegion(
            id: "japan",
            displayName: "Japan",
            polygons: [MapPolygon(points: points)],
            centroid: coord(138, 38),
            bounds: CGRect(x: lonToX(130), y: latToY(44), width: 0.04, height: 0.06),
            politicalAlignment: .capitalist
        )
    }

    private static func createSouthKorea() -> MapRegion {
        let points: [CGPoint] = [
            coord(126, 38),
            coord(129, 38),
            coord(129, 35),
            coord(126, 34),
            coord(126, 36),
        ]
        return MapRegion(
            id: "south_korea",
            displayName: "S. Korea",
            polygons: [MapPolygon(points: points)],
            centroid: coord(127.5, 36),
            bounds: CGRect(x: lonToX(126), y: latToY(38), width: 0.01, height: 0.02),
            politicalAlignment: .capitalist
        )
    }

    private static func createAustralia() -> MapRegion {
        let points: [CGPoint] = [
            coord(114, -20),
            coord(130, -12),
            coord(142, -10),
            coord(150, -12),
            coord(153, -25),
            coord(150, -35),
            coord(140, -38),
            coord(130, -35),
            coord(116, -34),
            coord(114, -26),
        ]
        return MapRegion(
            id: "australia",
            displayName: "Australia",
            polygons: [MapPolygon(points: points)],
            centroid: coord(134, -25),
            bounds: CGRect(x: lonToX(114), y: latToY(-10), width: 0.11, height: 0.16),
            politicalAlignment: .capitalist
        )
    }

    // MARK: - Non-Aligned / Neutral

    private static func createIndia() -> MapRegion {
        let points: [CGPoint] = [
            coord(68, 34),
            coord(76, 36),
            coord(88, 28),
            coord(92, 26),
            coord(88, 22),
            coord(80, 8),
            coord(76, 10),
            coord(72, 20),
            coord(68, 24),
        ]
        return MapRegion(
            id: "india",
            displayName: "India",
            polygons: [MapPolygon(points: points)],
            centroid: coord(80, 22),
            bounds: CGRect(x: lonToX(68), y: latToY(36), width: 0.07, height: 0.16),
            politicalAlignment: .nonAligned
        )
    }

    private static func createYugoslavia() -> MapRegion {
        let points: [CGPoint] = [
            coord(14, 46),
            coord(19, 46),
            coord(23, 44),
            coord(22, 42),
            coord(19, 42),
            coord(14, 44),
        ]
        return MapRegion(
            id: "yugoslavia",
            displayName: "Yugoslavia",
            polygons: [MapPolygon(points: points)],
            centroid: coord(18, 44),
            bounds: CGRect(x: lonToX(14), y: latToY(46), width: 0.025, height: 0.025),
            politicalAlignment: .nonAligned
        )
    }

    private static func createEgypt() -> MapRegion {
        let points: [CGPoint] = [
            coord(25, 32),
            coord(35, 32),
            coord(36, 30),
            coord(35, 22),
            coord(25, 22),
            coord(25, 30),
        ]
        return MapRegion(
            id: "egypt",
            displayName: "Egypt",
            polygons: [MapPolygon(points: points)],
            centroid: coord(30, 27),
            bounds: CGRect(x: lonToX(25), y: latToY(32), width: 0.03, height: 0.06),
            politicalAlignment: .nonAligned
        )
    }

    private static func createIndonesia() -> MapRegion {
        let points: [CGPoint] = [
            coord(95, 6),
            coord(110, -2),
            coord(120, -4),
            coord(140, -4),
            coord(140, -8),
            coord(115, -8),
            coord(105, -6),
            coord(95, 0),
        ]
        return MapRegion(
            id: "indonesia",
            displayName: "Indonesia",
            polygons: [MapPolygon(points: points)],
            centroid: coord(115, -2),
            bounds: CGRect(x: lonToX(95), y: latToY(6), width: 0.13, height: 0.08),
            politicalAlignment: .nonAligned
        )
    }

    private static func createBrazil() -> MapRegion {
        let points: [CGPoint] = [
            coord(-70, 4),
            coord(-60, 4),
            coord(-50, 0),
            coord(-35, -4),
            coord(-38, -14),
            coord(-48, -28),
            coord(-54, -34),
            coord(-58, -32),
            coord(-58, -20),
            coord(-68, -12),
            coord(-72, -8),
            coord(-70, 0),
        ]
        return MapRegion(
            id: "brazil",
            displayName: "Brazil",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-52, -12),
            bounds: CGRect(x: lonToX(-72), y: latToY(4), width: 0.10, height: 0.21),
            politicalAlignment: .nonAligned
        )
    }

    private static func createArgentina() -> MapRegion {
        let points: [CGPoint] = [
            coord(-68, -22),
            coord(-58, -22),
            coord(-56, -34),
            coord(-62, -40),
            coord(-68, -52),
            coord(-72, -50),
            coord(-70, -40),
            coord(-70, -30),
        ]
        return MapRegion(
            id: "argentina",
            displayName: "Argentina",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-64, -35),
            bounds: CGRect(x: lonToX(-72), y: latToY(-22), width: 0.05, height: 0.17),
            politicalAlignment: .nonAligned
        )
    }

    private static func createMexico() -> MapRegion {
        let points: [CGPoint] = [
            coord(-117, 32),
            coord(-104, 32),
            coord(-100, 28),
            coord(-97, 26),
            coord(-98, 20),
            coord(-90, 18),
            coord(-87, 20),
            coord(-90, 22),
            coord(-96, 18),
            coord(-105, 20),
            coord(-110, 24),
            coord(-115, 28),
        ]
        return MapRegion(
            id: "mexico",
            displayName: "Mexico",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-102, 24),
            bounds: CGRect(x: lonToX(-117), y: latToY(32), width: 0.08, height: 0.08),
            politicalAlignment: .nonAligned
        )
    }

    private static func createTurkey() -> MapRegion {
        let points: [CGPoint] = [
            coord(26, 42),
            coord(36, 42),
            coord(44, 40),
            coord(44, 37),
            coord(36, 36),
            coord(28, 36),
            coord(26, 40),
        ]
        return MapRegion(
            id: "turkey",
            displayName: "Turkey",
            polygons: [MapPolygon(points: points)],
            centroid: coord(35, 39),
            bounds: CGRect(x: lonToX(26), y: latToY(42), width: 0.05, height: 0.035),
            politicalAlignment: .neutral
        )
    }

    private static func createIran() -> MapRegion {
        let points: [CGPoint] = [
            coord(44, 40),
            coord(50, 38),
            coord(62, 36),
            coord(62, 28),
            coord(55, 25),
            coord(48, 28),
            coord(44, 32),
        ]
        return MapRegion(
            id: "iran",
            displayName: "Iran",
            polygons: [MapPolygon(points: points)],
            centroid: coord(53, 32),
            bounds: CGRect(x: lonToX(44), y: latToY(40), width: 0.05, height: 0.08),
            politicalAlignment: .neutral
        )
    }

    private static func createSaudiArabia() -> MapRegion {
        let points: [CGPoint] = [
            coord(35, 32),
            coord(42, 28),
            coord(55, 24),
            coord(55, 18),
            coord(45, 14),
            coord(35, 18),
            coord(35, 28),
        ]
        return MapRegion(
            id: "saudi_arabia",
            displayName: "Saudi Arabia",
            polygons: [MapPolygon(points: points)],
            centroid: coord(45, 24),
            bounds: CGRect(x: lonToX(35), y: latToY(32), width: 0.055, height: 0.1),
            politicalAlignment: .neutral
        )
    }

    private static func createSouthAfrica() -> MapRegion {
        let points: [CGPoint] = [
            coord(17, -22),
            coord(32, -22),
            coord(32, -28),
            coord(28, -34),
            coord(18, -34),
            coord(17, -28),
        ]
        return MapRegion(
            id: "south_africa",
            displayName: "South Africa",
            polygons: [MapPolygon(points: points)],
            centroid: coord(25, -28),
            bounds: CGRect(x: lonToX(17), y: latToY(-22), width: 0.04, height: 0.07),
            politicalAlignment: .neutral
        )
    }

    // MARK: - Africa (Colonial/Simplified)

    private static func createNorthAfrica() -> MapRegion {
        // Libya, Tunisia, Algeria, Morocco
        let points: [CGPoint] = [
            coord(-12, 36),
            coord(10, 38),
            coord(25, 32),
            coord(25, 22),
            coord(10, 20),
            coord(-12, 28),
        ]
        return MapRegion(
            id: "north_africa",
            displayName: "North Africa",
            polygons: [MapPolygon(points: points)],
            centroid: coord(5, 28),
            bounds: CGRect(x: lonToX(-12), y: latToY(38), width: 0.10, height: 0.10),
            politicalAlignment: .neutral
        )
    }

    private static func createWestAfrica() -> MapRegion {
        let points: [CGPoint] = [
            coord(-18, 28),
            coord(-12, 18),
            coord(-5, 5),
            coord(5, 5),
            coord(5, 15),
            coord(-5, 22),
        ]
        return MapRegion(
            id: "west_africa",
            displayName: "West Africa",
            polygons: [MapPolygon(points: points)],
            centroid: coord(-5, 15),
            bounds: CGRect(x: lonToX(-18), y: latToY(28), width: 0.065, height: 0.13),
            politicalAlignment: .neutral
        )
    }

    private static func createCentralAfrica() -> MapRegion {
        let points: [CGPoint] = [
            coord(5, 15),
            coord(25, 22),
            coord(32, 12),
            coord(32, 0),
            coord(15, -5),
            coord(5, 5),
        ]
        return MapRegion(
            id: "central_africa",
            displayName: "Central Africa",
            polygons: [MapPolygon(points: points)],
            centroid: coord(18, 8),
            bounds: CGRect(x: lonToX(5), y: latToY(22), width: 0.075, height: 0.15),
            politicalAlignment: .neutral
        )
    }

    private static func createEastAfrica() -> MapRegion {
        let points: [CGPoint] = [
            coord(32, 12),
            coord(48, 12),
            coord(52, 0),
            coord(42, -12),
            coord(32, -15),
            coord(25, -5),
            coord(32, 0),
        ]
        return MapRegion(
            id: "east_africa",
            displayName: "East Africa",
            polygons: [MapPolygon(points: points)],
            centroid: coord(40, 0),
            bounds: CGRect(x: lonToX(25), y: latToY(12), width: 0.075, height: 0.15),
            politicalAlignment: .neutral
        )
    }

    // MARK: - Oceans

    private static func createAtlanticOcean() -> MapRegion {
        MapRegion(
            id: "atlantic_ocean",
            displayName: "Atlantic Ocean",
            polygons: [],
            centroid: coord(-30, 20),
            bounds: CGRect(x: lonToX(-80), y: latToY(60), width: 0.22, height: 0.44),
            politicalAlignment: .ocean
        )
    }

    private static func createPacificOcean() -> MapRegion {
        MapRegion(
            id: "pacific_ocean",
            displayName: "Pacific Ocean",
            polygons: [],
            centroid: coord(-150, 0),
            bounds: CGRect(x: lonToX(-180), y: latToY(60), width: 0.30, height: 0.44),
            politicalAlignment: .ocean
        )
    }

    private static func createIndianOcean() -> MapRegion {
        MapRegion(
            id: "indian_ocean",
            displayName: "Indian Ocean",
            polygons: [],
            centroid: coord(75, -10),
            bounds: CGRect(x: lonToX(40), y: latToY(20), width: 0.20, height: 0.33),
            politicalAlignment: .ocean
        )
    }

    private static func createArcticOcean() -> MapRegion {
        MapRegion(
            id: "arctic_ocean",
            displayName: "Arctic Ocean",
            polygons: [],
            centroid: coord(0, 80),
            bounds: CGRect(x: 0, y: 0, width: 1.0, height: 0.06),
            politicalAlignment: .ocean
        )
    }
}

// MARK: - Deprecated Alias

typealias AlternateWorldMap = WorldMapData
