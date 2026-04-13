//
//  PortalSectionBar.swift
//  Nomenklatura
//
//  Shared section bar for all portal views
//

import SwiftUI

struct PortalSectionBar<S: PortalSection>: View {
    @Binding var selectedSection: S
    let accessLevel: AccessLevel
    let featureCategory: FeatureCategory
    let accentColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(S.allCases), id: \.self) { section in
                let hasAccess = accessLevel.effectiveLevel(for: featureCategory) >= section.requiredLevel

                PortalSectionButton(
                    section: section,
                    isSelected: selectedSection == section,
                    isLocked: !hasAccess,
                    accentColor: accentColor
                ) {
                    if hasAccess {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSection = section
                        }
                    }
                }
            }
        }
    }
}
