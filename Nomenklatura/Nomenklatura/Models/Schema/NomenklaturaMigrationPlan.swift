//
//  NomenklaturaMigrationPlan.swift
//  Nomenklatura
//
//  Top-level SwiftData migration plan. As new schema versions are
//  introduced, add their VersionedSchema types to `schemas` and add a
//  corresponding MigrationStage to `stages` (lightweight when the
//  change is additive / property-only; custom when a transform is
//  needed).
//
//  V1 is the baseline — no stages yet.
//
//  See: NomenklaturaSchemaV1.swift
//

import Foundation
import SwiftData

enum NomenklaturaMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [
            NomenklaturaSchemaV1.self
        ]
    }

    static var stages: [MigrationStage] {
        // No migrations yet — V1 is the baseline schema.
        // When introducing V2, append e.g.:
        //
        //   MigrationStage.lightweight(
        //       fromVersion: NomenklaturaSchemaV1.self,
        //       toVersion:   NomenklaturaSchemaV2.self
        //   )
        []
    }
}
