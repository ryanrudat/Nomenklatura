//
//  TradeProposalSheet.swift
//  Nomenklatura
//
//  Interactive trade proposal negotiation sheet
//

import SwiftUI

struct TradeProposalSheet: View {
    @Bindable var game: Game
    let country: ForeignCountry
    @Environment(\.theme) var theme
    @Environment(\.dismiss) var dismiss

    @State private var step: ProposalStep = .chooseType
    @State private var selectedType: AgreementType?
    @State private var favorability: Double = 0.5 // 0 = favor us, 0.5 = equal, 1 = favor them
    @State private var selectedDuration: DurationOption = .medium
    @State private var showResult = false
    @State private var proposalAccepted = false

    enum ProposalStep {
        case chooseType, setTerms, preview
    }

    enum DurationOption: String, CaseIterable {
        case short, medium, permanent

        var displayName: String {
            switch self {
            case .short: return "SHORT (8 TURNS)"
            case .medium: return "MEDIUM (16 TURNS)"
            case .permanent: return "PERMANENT"
            }
        }

        var turns: Int? {
            switch self {
            case .short: return 8
            case .medium: return 16
            case .permanent: return nil
            }
        }

        var effectMultiplier: Double {
            switch self {
            case .short: return 0.8
            case .medium: return 1.0
            case .permanent: return 1.3
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    partnerHeader

                    switch step {
                    case .chooseType:
                        typeSelectionSection
                    case .setTerms:
                        termsSection
                    case .preview:
                        previewSection
                    }
                }
                .padding(.horizontal, 15)
                .padding(.bottom, 40)
            }
            .background(theme.parchment)
            .navigationTitle("TRADE PROPOSAL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("CANCEL") { dismiss() }
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundColor(FiftiesColors.stampRed)
                }
            }
            .alert(proposalAccepted ? "PROPOSAL ACCEPTED" : "PROPOSAL REJECTED",
                   isPresented: $showResult) {
                Button("Understood") { dismiss() }
            } message: {
                Text(proposalAccepted
                     ? "\(country.name) has accepted the terms. The agreement is now active."
                     : "\(country.name) has rejected the proposal. Relations and terms were insufficiently favorable.")
            }
        }
    }

    // MARK: - Partner Header

    private var partnerHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("NEGOTIATING WITH")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(FiftiesColors.carbonCopy)
                Text(country.name.uppercased())
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(FiftiesColors.typewriterInk)
                Text("Relations: \(country.relationshipScore > 0 ? "+" : "")\(country.relationshipScore)  |  Econ. Power: \(country.economicPower)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
            }
            Spacer()
        }
        .padding(14)
        .background(FiftiesColors.cardstock)
        .overlay(
            Rectangle()
                .stroke(theme.borderTan, lineWidth: 1)
        )
    }

    // MARK: - Step A: Choose Type

    private var typeSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            stepHeader("STEP I: SELECT AGREEMENT TYPE", step: "1/3")

            ForEach(AgreementType.allCases, id: \.rawValue) { type in
                agreementTypeCard(type)
            }
        }
    }

    private func agreementTypeCard(_ type: AgreementType) -> some View {
        let effects = baseEffects(for: type)
        let minRelationship = minimumRelationship(for: type)
        let meetsRequirement = country.relationshipScore >= minRelationship
        let isSelected = selectedType == type

        return Button {
            guard meetsRequirement else { return }
            selectedType = type
            step = .setTerms
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: type.iconName)
                        .font(.system(size: 14))
                        .foregroundColor(isSelected ? FiftiesColors.brassGold : FiftiesColors.typewriterInk)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(type.displayName.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(meetsRequirement ? FiftiesColors.typewriterInk : FiftiesColors.carbonCopy)
                        Text(type.description)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                            .lineLimit(2)
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    effectBadge("Treasury", value: effects.treasury)
                    effectBadge("Industry", value: effects.industrial)
                    effectBadge("Food", value: effects.food)
                    effectBadge("Tech", value: effects.technology)
                }

                if !meetsRequirement {
                    Text("REQUIRES RELATIONS \(minRelationship)+")
                        .font(.system(size: 8, weight: .bold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.stampRed)
                }
            }
            .padding(12)
            .background(FiftiesColors.cardstock)
            .overlay(
                Rectangle()
                    .stroke(isSelected ? FiftiesColors.brassGold : theme.borderTan, lineWidth: isSelected ? 2 : 1)
            )
            .opacity(meetsRequirement ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step B: Set Terms

    private var termsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("STEP II: SET TERMS", step: "2/3")

            if let type = selectedType {
                HStack(spacing: 8) {
                    Image(systemName: type.iconName)
                        .font(.system(size: 12))
                        .foregroundColor(FiftiesColors.brassGold)
                    Text(type.displayName.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(FiftiesColors.typewriterInk)
                    Spacer()
                    Button {
                        step = .chooseType
                    } label: {
                        Text("CHANGE")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(FiftiesColors.stampRed)
                    }
                }
                .padding(10)
                .background(FiftiesColors.cardstock)
                .overlay(
                    Rectangle()
                        .stroke(FiftiesColors.brassGold, lineWidth: 1)
                )
            }

            // Favorability
            VStack(alignment: .leading, spacing: 8) {
                Text("FAVORABILITY")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(FiftiesColors.typewriterInk)

                HStack(spacing: 4) {
                    Text("FAVORS US")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(FiftiesColors.approvedGreen)
                    Spacer()
                    Text("EQUAL")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(FiftiesColors.brassGold)
                    Spacer()
                    Text("FAVORS THEM")
                        .font(.system(size: 7, weight: .bold))
                        .tracking(0.3)
                        .foregroundColor(FiftiesColors.stampRed)
                }

                Slider(value: $favorability, in: 0...1, step: 0.1)
                    .tint(favorabilityColor)

                Text(favorabilityDescription)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(FiftiesColors.carbonCopy)
            }
            .padding(12)
            .background(FiftiesColors.cardstock)
            .overlay(
                Rectangle()
                    .stroke(theme.borderTan, lineWidth: 1)
            )

            // Duration
            VStack(alignment: .leading, spacing: 8) {
                Text("DURATION")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.5)
                    .foregroundColor(FiftiesColors.typewriterInk)

                ForEach(DurationOption.allCases, id: \.rawValue) { option in
                    Button {
                        selectedDuration = option
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedDuration == option ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 12))
                                .foregroundColor(selectedDuration == option ? FiftiesColors.brassGold : FiftiesColors.carbonCopy)
                            Text(option.displayName)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(FiftiesColors.cardstock)
            .overlay(
                Rectangle()
                    .stroke(theme.borderTan, lineWidth: 1)
            )

            // Continue button
            Button {
                step = .preview
            } label: {
                Text("REVIEW PROPOSAL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(FiftiesColors.brassGold)
                    .cornerRadius(3)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Step C: Preview & Confirm

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            stepHeader("STEP III: REVIEW & CONFIRM", step: "3/3")

            if let type = selectedType {
                let projected = projectedEffects(type: type)
                let acceptance = acceptanceProbability(type: type)

                // Agreement summary
                VStack(alignment: .leading, spacing: 10) {
                    Text("PROPOSED AGREEMENT")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.carbonCopy)

                    HStack(spacing: 8) {
                        Image(systemName: type.iconName)
                            .font(.system(size: 16))
                            .foregroundColor(FiftiesColors.brassGold)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(type.displayName.uppercased())
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(FiftiesColors.typewriterInk)
                            Text("with \(country.name)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(FiftiesColors.carbonCopy)
                        }
                    }

                    Rectangle()
                        .fill(FiftiesColors.brassGold.opacity(0.4))
                        .frame(height: 1)

                    // Duration
                    HStack {
                        Text("DURATION:")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                        Text(selectedDuration.displayName)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(FiftiesColors.typewriterInk)
                    }

                    // Favorability
                    HStack {
                        Text("TERMS:")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundColor(FiftiesColors.carbonCopy)
                        Text(favorabilityLabel.uppercased())
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(favorabilityColor)
                    }
                }
                .padding(14)
                .background(FiftiesColors.cardstock)
                .overlay(
                    Rectangle()
                        .stroke(theme.borderTan, lineWidth: 1)
                )

                // Projected effects
                VStack(alignment: .leading, spacing: 10) {
                    Text("PROJECTED EFFECTS (PER TURN)")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.carbonCopy)

                    HStack(spacing: 16) {
                        projectedStat("TREASURY", value: projected.treasury)
                        projectedStat("INDUSTRY", value: projected.industrial)
                        projectedStat("FOOD", value: projected.food)
                        projectedStat("TECH", value: projected.technology)
                    }

                    Rectangle()
                        .fill(FiftiesColors.brassGold.opacity(0.4))
                        .frame(height: 1)

                    HStack(spacing: 16) {
                        projectedStat("RELATIONS", value: projected.relationship)
                        projectedStat("STANDING", value: projected.standing)
                    }
                }
                .padding(14)
                .background(FiftiesColors.cardstock)
                .overlay(
                    Rectangle()
                        .stroke(theme.borderTan, lineWidth: 1)
                )

                // Acceptance probability
                VStack(alignment: .leading, spacing: 8) {
                    Text("ACCEPTANCE PROBABILITY")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.5)
                        .foregroundColor(FiftiesColors.carbonCopy)

                    HStack {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(theme.borderTan)
                                    .frame(height: 10)
                                Rectangle()
                                    .fill(acceptanceColor(acceptance))
                                    .frame(width: geo.size.width * CGFloat(acceptance) / 100, height: 10)
                            }
                            .cornerRadius(5)
                        }
                        .frame(height: 10)

                        Text("\(acceptance)%")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(acceptanceColor(acceptance))
                            .frame(width: 40, alignment: .trailing)
                    }

                    Text(acceptanceDescription(acceptance))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(FiftiesColors.carbonCopy)
                }
                .padding(14)
                .background(FiftiesColors.cardstock)
                .overlay(
                    Rectangle()
                        .stroke(theme.borderTan, lineWidth: 1)
                )

                // Action buttons
                HStack(spacing: 12) {
                    Button {
                        step = .setTerms
                    } label: {
                        Text("REVISE TERMS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(0.5)
                            .foregroundColor(FiftiesColors.typewriterInk)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(FiftiesColors.cardstock)
                            .overlay(
                                Rectangle()
                                    .stroke(theme.borderTan, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)

                    Button {
                        submitProposal(type: type, projected: projected, acceptance: acceptance)
                    } label: {
                        Text("PROPOSE DEAL")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(FiftiesColors.approvedGreen)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Helpers

    private func stepHeader(_ title: String, step: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(1)
                    .foregroundColor(theme.inkGray)
                Spacer()
                Text(step)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(FiftiesColors.brassGold)
            }
            Rectangle()
                .fill(FiftiesColors.brassGold)
                .frame(height: 2)
        }
    }

    private func effectBadge(_ label: String, value: Int) -> some View {
        HStack(spacing: 2) {
            Text(label.prefix(4).uppercased())
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(FiftiesColors.carbonCopy)
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0 ? FiftiesColors.approvedGreen : value < 0 ? FiftiesColors.stampRed : FiftiesColors.carbonCopy)
        }
    }

    private func projectedStat(_ label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.3)
                .foregroundColor(FiftiesColors.carbonCopy)
            Text("\(value > 0 ? "+" : "")\(value)")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(value > 0 ? FiftiesColors.approvedGreen : value < 0 ? FiftiesColors.stampRed : FiftiesColors.carbonCopy)
        }
    }

    // MARK: - Computed Values

    private struct AgreementEffects {
        var treasury: Int
        var industrial: Int
        var food: Int
        var technology: Int
        var relationship: Int
        var standing: Int
    }

    private func baseEffects(for type: AgreementType) -> AgreementEffects {
        switch type {
        case .basicTrade:
            return AgreementEffects(treasury: 2, industrial: 0, food: 0, technology: 0, relationship: 5, standing: 0)
        case .preferentialTrade:
            return AgreementEffects(treasury: 3, industrial: 1, food: 0, technology: 0, relationship: 8, standing: 1)
        case .aidPackage:
            return AgreementEffects(treasury: -5, industrial: 0, food: 0, technology: 0, relationship: 20, standing: 5)
        case .receivingAid:
            return AgreementEffects(treasury: 5, industrial: 1, food: 1, technology: 0, relationship: 10, standing: -2)
        case .oilDeal:
            return AgreementEffects(treasury: -2, industrial: 2, food: 0, technology: 0, relationship: 5, standing: 0)
        case .armsExport:
            return AgreementEffects(treasury: 4, industrial: -1, food: 0, technology: 0, relationship: 10, standing: -2)
        case .armsImport:
            return AgreementEffects(treasury: -4, industrial: 0, food: 0, technology: 1, relationship: 5, standing: 0)
        case .technicalCooperation:
            return AgreementEffects(treasury: -2, industrial: 1, food: 0, technology: 3, relationship: 10, standing: 2)
        case .jointVenture:
            return AgreementEffects(treasury: -3, industrial: 3, food: 0, technology: 1, relationship: 12, standing: 2)
        case .debtAgreement:
            return AgreementEffects(treasury: 4, industrial: 0, food: 0, technology: 0, relationship: -5, standing: 1)
        }
    }

    private func minimumRelationship(for type: AgreementType) -> Int {
        switch type {
        case .basicTrade: return -20
        case .preferentialTrade: return 10
        case .aidPackage: return 0
        case .receivingAid: return 20
        case .oilDeal: return -10
        case .armsExport: return 0
        case .armsImport: return 10
        case .technicalCooperation: return 20
        case .jointVenture: return 30
        case .debtAgreement: return -10
        }
    }

    private func projectedEffects(type: AgreementType) -> AgreementEffects {
        let base = baseEffects(for: type)
        let durationMult = selectedDuration.effectMultiplier

        // Favorability shifts effects: favor us = better treasury/industry, favor them = better relationship
        let usFactor = 1.0 + (0.5 - favorability) * 1.2   // 0.0->1.6, 0.5->1.0, 1.0->0.4
        let themFactor = 1.0 + (favorability - 0.5) * 1.2  // 0.0->0.4, 0.5->1.0, 1.0->1.6

        return AgreementEffects(
            treasury: Int(Double(base.treasury) * usFactor * durationMult),
            industrial: Int(Double(base.industrial) * usFactor * durationMult),
            food: Int(Double(base.food) * usFactor * durationMult),
            technology: Int(Double(base.technology) * durationMult),
            relationship: Int(Double(base.relationship) * themFactor),
            standing: Int(Double(base.standing) * durationMult)
        )
    }

    private func acceptanceProbability(type: AgreementType) -> Int {
        var probability = 40

        // Relationship bonus
        probability += country.relationshipScore / 3

        // Favorability: favoring them greatly increases acceptance
        probability += Int(favorability * 40) // 0 to 40 bonus

        // Economic compatibility
        let compatibility = country.economicCompatibility(with: game.currentEconomicSystem)
        probability += compatibility * 5

        // Bloc alignment
        if country.politicalBloc == .socialist {
            probability += 15
        } else if country.politicalBloc == .capitalist {
            probability -= 10
        }

        // Duration: shorter is easier
        switch selectedDuration {
        case .short: probability += 10
        case .medium: break
        case .permanent: probability -= 15
        }

        // Existing agreements make new ones easier
        let existingCount = game.agreements(with: country.countryId).filter(\.isActive).count
        probability += existingCount * 5

        return max(5, min(95, probability))
    }

    private var favorabilityLabel: String {
        if favorability < 0.3 { return "Highly Favorable to Us" }
        if favorability < 0.45 { return "Favorable to Us" }
        if favorability < 0.55 { return "Equal Terms" }
        if favorability < 0.7 { return "Favorable to Partner" }
        return "Highly Favorable to Partner"
    }

    private var favorabilityColor: Color {
        if favorability < 0.3 { return FiftiesColors.approvedGreen }
        if favorability < 0.55 { return FiftiesColors.brassGold }
        return FiftiesColors.stampRed
    }

    private var favorabilityDescription: String {
        if favorability < 0.3 {
            return "Terms strongly favor us. Better economic effects but very low acceptance chance."
        } else if favorability < 0.55 {
            return "Balanced terms. Reasonable effects and acceptance chance."
        } else {
            return "Terms favor the partner. Reduced economic benefit but high acceptance chance and relationship boost."
        }
    }

    private func acceptanceColor(_ probability: Int) -> Color {
        if probability >= 70 { return FiftiesColors.approvedGreen }
        if probability >= 40 { return FiftiesColors.brassGold }
        return FiftiesColors.stampRed
    }

    private func acceptanceDescription(_ probability: Int) -> String {
        if probability >= 70 {
            return "High likelihood of acceptance. The partner finds these terms agreeable."
        } else if probability >= 40 {
            return "Moderate chance of acceptance. The partner may agree or demand better terms."
        } else {
            return "Low probability. Consider more favorable terms or improving relations first."
        }
    }

    // MARK: - Submit

    private func submitProposal(type: AgreementType, projected: AgreementEffects, acceptance: Int) {
        let agreement = TradeAgreement(
            partnerId: country.countryId,
            partnerName: country.name,
            type: type
        )

        agreement.treasuryEffect = projected.treasury
        agreement.industrialEffect = projected.industrial
        agreement.foodEffect = projected.food
        agreement.technologyEffect = projected.technology
        agreement.relationshipEffect = projected.relationship
        agreement.standingEffect = projected.standing
        agreement.durationTurns = selectedDuration.turns

        // Roll for acceptance
        let roll = Int.random(in: 1...100)
        if roll <= acceptance {
            agreement.activate(on: game.turnNumber)
            proposalAccepted = true
        } else {
            agreement.agreementStatus = AgreementStatus.terminated.rawValue
            proposalAccepted = false
        }

        game.tradeAgreements.append(agreement)
        showResult = true
    }
}
