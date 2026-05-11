//
//  NomenklaturaSchemaV1.swift
//  Nomenklatura
//
//  Baseline (V1) versioned schema for SwiftData persistence.
//
//  This enumerates every @Model type in the app as of the V1 schema
//  freeze. Adding a new @Model class requires either bumping this
//  schema (creating V2) and providing a MigrationStage, or — if the
//  change is purely additive / nullable — being conservative and still
//  declaring a new versioned schema so that downstream apps can roll
//  back via a migration plan instead of wiping user data.
//
//  See: NomenklaturaMigrationPlan.swift
//

import Foundation
import SwiftData

enum NomenklaturaSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            // Core game aggregate root + immediate children
            Game.self,
            GameCharacter.self,
            GameFaction.self,
            GameEvent.self,
            DeskDocument.self,

            // Achievements + journal
            UnlockedAchievement.self,

            // Codex (in-game messaging system)
            CodexMessage.self,

            // Position / succession / purge mechanics
            PositionHolder.self,
            PositionOffer.self,
            SuccessionRelationship.self,
            PurgeCampaign.self,

            // Player dynasty / family
            PlayerFamily.self,
            // DynastyLegacy is currently orphan code (no live game system reads or writes it),
            // but it remains registered here because it is part of the V1 persisted schema.
            // Removing it requires a V2 schema + MigrationStage to drop the table; defer to the
            // next schema bump rather than risking a data-loss migration mid-wave.
            DynastyLegacy.self,

            // Policy + standing-committee infrastructure
            Policy.self,
            PolicySlot.self,
            StandingCommittee.self,

            // Economic / world / regions
            Region.self,
            ForeignCountry.self,
            TradeAgreement.self,

            // Legal + congressional bodies
            Law.self,
            CongressSession.self,

            // NPC autonomy + world events
            NPCRelationship.self,
            WorldEventRecord.self,

            // Historical run records
            HistoricalSession.self
        ]
    }
}
