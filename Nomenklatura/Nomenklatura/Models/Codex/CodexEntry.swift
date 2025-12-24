//
//  CodexEntry.swift
//  Nomenklatura
//
//  Lore encyclopedia entry model for the Codex system
//

import Foundation

// MARK: - Codex Entry

struct CodexEntry: Codable, Identifiable, Hashable {
    var id: String                    // e.g., "vwp", "presidium", "volkhrad"
    var term: String                  // Display term: "The People's Worker Party"
    var shortDescription: String      // One-line tooltip
    var fullDescription: String       // Multi-paragraph lore
    var category: CodexCategory
    var relatedEntries: [String]      // IDs of related entries
    var unlockedByDefault: Bool       // Some entries unlock through gameplay

    init(
        id: String,
        term: String,
        shortDescription: String,
        fullDescription: String,
        category: CodexCategory,
        relatedEntries: [String] = [],
        unlockedByDefault: Bool = true
    ) {
        self.id = id
        self.term = term
        self.shortDescription = shortDescription
        self.fullDescription = fullDescription
        self.category = category
        self.relatedEntries = relatedEntries
        self.unlockedByDefault = unlockedByDefault
    }
}

// MARK: - Codex Category

enum CodexCategory: String, Codable, CaseIterable, Hashable {
    case factions       // Player-selectable political factions
    case institutions   // "The Party", "Politburo", "Bureau of People's Security"
    case concepts       // "Socialist Realism", "Five-Year Plan"
    case history        // "The Second Revolution", "The Great Purge"
    case characters     // NPC entries (unlocked when met)
    case regions        // Domestic zones of the PSRA
    case worldAtlas     // Foreign nations and international blocs

    var displayName: String {
        switch self {
        case .factions: return "Factions"
        case .institutions: return "Institutions"
        case .concepts: return "Concepts"
        case .history: return "History"
        case .characters: return "Figures"
        case .regions: return "Regions"
        case .worldAtlas: return "World Atlas"
        }
    }

    var iconName: String {
        switch self {
        case .factions: return "flag.fill"
        case .institutions: return "building.columns.fill"
        case .concepts: return "lightbulb.fill"
        case .history: return "clock.fill"
        case .characters: return "person.fill"
        case .regions: return "globe.europe.africa.fill"
        case .worldAtlas: return "globe"
        }
    }
}

// MARK: - Codex Database

class CodexDatabase {
    static let shared = CodexDatabase()

    private var entries: [String: CodexEntry] = [:]
    private var unlockedEntries: Set<String> = []

    private init() {
        loadDefaultEntries()
    }

    // MARK: - Public API

    func entry(for id: String) -> CodexEntry? {
        entries[id]
    }

    func unlock(_ id: String) {
        unlockedEntries.insert(id)
    }

    func isUnlocked(_ id: String) -> Bool {
        if let entry = entries[id], entry.unlockedByDefault {
            return true
        }
        return unlockedEntries.contains(id)
    }

    func entriesInCategory(_ category: CodexCategory) -> [CodexEntry] {
        entries.values
            .filter { $0.category == category && isUnlocked($0.id) }
            .sorted { $0.term < $1.term }
    }

    func allEntries() -> [CodexEntry] {
        entries.values
            .filter { isUnlocked($0.id) }
            .sorted { $0.term < $1.term }
    }

    func searchEntries(_ query: String) -> [CodexEntry] {
        let lowercased = query.lowercased()
        return entries.values
            .filter { isUnlocked($0.id) }
            .filter {
                $0.term.lowercased().contains(lowercased) ||
                $0.shortDescription.lowercased().contains(lowercased)
            }
            .sorted { $0.term < $1.term }
    }

    // MARK: - Load Default Entries

    private func loadDefaultEntries() {
        let defaultEntries: [CodexEntry] = [
            // FACTIONS (Player-selectable political backgrounds)
            CodexEntry(
                id: "youth_league",
                term: "Youth League",
                shortDescription: "The Meritocrats - rising through competence and dedication",
                fullDescription: """
                The Communist Youth League serves as the primary pipeline for talented young people seeking Party membership. Those who rise through its ranks prove themselves through competence, organizational ability, and demonstrated loyalty to socialist principles.

                Youth League cadres are respected for their abilities but often lack the elite connections that open doors in the upper echelons. They are outsiders to the aristocratic factions—meritocrats in a system that rewards bloodlines alongside achievement.

                In the factional struggles of the Politburo, Youth League alumni tend toward pragmatic alliances. They support policies that reward competence and open pathways for talented commoners. Their natural enemies are the Princelings, whose inherited privilege threatens the meritocratic ideal.

                "We earned our positions. Can they say the same?"
                """,
                category: .factions,
                relatedEntries: ["princelings", "nomenklatura", "vwp"]
            ),

            CodexEntry(
                id: "princelings",
                term: "Princelings",
                shortDescription: "Red Aristocracy - descendants of revolutionary heroes",
                fullDescription: """
                The Princelings are descendants of the Second Revolution's founders and heroes—a "Red Aristocracy" whose parents fought in the Civil War and built the People's Socialist Republic of America. Their names carry weight in every corridor of power; doors open for them that remain closed to others.

                Princeling networks span the highest levels of Party, military, and security services. They grew up together in exclusive compounds, attended the same schools, and married into each other's families. Their loyalty is primarily to each other and to preserving their inherited status.

                In factional terms, Princelings defend the privileges of the elite against reform movements and meritocratic challenges. They are vulnerable to anti-corruption campaigns—their wealth and connections make tempting targets when political winds shift.

                "My father died storming the White House. What did yours do?"
                """,
                category: .factions,
                relatedEntries: ["youth_league", "nomenklatura", "revolution"]
            ),

            CodexEntry(
                id: "reformists",
                term: "Reformists",
                shortDescription: "The Pragmatists - believing in progress through careful change",
                fullDescription: """
                The Reformist faction believes in practical results over ideological purity. They advocate for economic modernization, measured opening to the outside world, and gradual liberalization of the planning system. To them, socialism must adapt or perish.

                Reformists draw support from technocrats, economists, and officials who see the system's inefficiencies firsthand. They point to stagnating growth, inferior consumer goods, and the gap between plan targets and reality. "Results matter more than slogans," they argue.

                Their enemies call them "capitalist roaders" and "revisionists"—dangerous accusations in a system where ideological deviation can be fatal. Reformists walk a careful line, packaging their proposals in orthodox language while pushing the boundaries of acceptable discourse.

                "The question is not whether we remain socialist, but whether socialism can deliver results."
                """,
                category: .factions,
                relatedEntries: ["old_guard", "five_year_plan", "nomenklatura"]
            ),

            CodexEntry(
                id: "old_guard",
                term: "Proletariat Union",
                shortDescription: "Ideological Guardians - keepers of revolutionary faith",
                fullDescription: """
                The Proletariat Union are the keepers of ideological orthodoxy—officials who remember why the Second Revolution was fought and resist any deviation from socialist principles. They view reform as betrayal and modernization as capitulation to enemy values.

                Union members dominate the Party apparatus and security services. They control the mechanisms of ideological discipline: propaganda, education, and the suppression of heterodox thought. When campaigns against "bourgeois influence" or "revisionism" arise, they lead the charge.

                Their strength is ideological legitimacy—no one can question their socialist credentials. Their weakness is results. The planned economy they defend produces shortages and inefficiency. When economic crises strike, their resistance to reform makes them convenient scapegoats.

                "We did not sacrifice everything to build socialism only to abandon it now."
                """,
                category: .factions,
                relatedEntries: ["reformists", "purge", "socialist_realism"]
            ),

            CodexEntry(
                id: "regional",
                term: "People's Provincial Administration",
                shortDescription: "Provincial Networks - power built far from Washington",
                fullDescription: """
                Regional faction leaders built their careers in the provinces, far from the intrigues of Washington. They cultivated loyal networks among local officials, factory directors, and Party secretaries. When they arrived in the corridors of central power, they brought armies of supporters.

                The regional power base provides both strength and vulnerability. Regional patrons can mobilize resources and personnel beyond the reach of capital elites. But they are also viewed as outsiders with "provincial thinking"—unsophisticated, parochial, and potentially disloyal to central authority.

                "Localism" is a serious accusation. Regional leaders must constantly demonstrate their commitment to the whole Republic, not just their home zones. Those who fail this test can be purged for putting regional interests above the state.

                "We built real socialism in the heartland while they were playing politics in Washington."
                """,
                category: .factions,
                relatedEntries: ["nomenklatura", "region_greatlakes", "region_southern"]
            ),

            // INSTITUTIONS
            CodexEntry(
                id: "vwp",
                term: "The Communist Party of America",
                shortDescription: "The ruling political party of the PSRA",
                fullDescription: """
                The Communist Party of America is the sole legal political party in the nation. Founded in the crucible of the Second American Civil War (1936-1940), the Party serves as the "vanguard of the working class" and exercises complete control over all aspects of state and society.

                The Party is organized along democratic centralist principles: decisions flow from the top down, while information and obedience flow from the bottom up. At its apex sits the General Secretary, who chairs the Politburo and effectively rules the People's Socialist Republic of America.

                Party membership is both a privilege and a necessity for advancement. To hold any position of authority—in government, industry, or the military—one must be a Party member in good standing. The Party controls appointments through the nomenklatura system, maintaining lists of positions and the cadres approved to fill them.

                "The Party is the mind, honor, and conscience of our epoch."
                """,
                category: .institutions,
                relatedEntries: ["politburo", "general_secretary", "central_committee"]
            ),

            CodexEntry(
                id: "politburo",
                term: "The Politburo",
                shortDescription: "The highest executive body of the Party",
                fullDescription: """
                The Politburo is the supreme decision-making body of the Communist Party of America. Consisting of approximately 15-25 full members and candidate members, the Politburo meets weekly to determine policy on all matters of state.

                In theory, the Politburo is elected by the Central Committee. In practice, its composition is determined by the General Secretary and reflects the current balance of power among Party factions. A seat on the Politburo represents the pinnacle of political achievement in the PSRA.

                Politburo meetings are conducted in strict secrecy. Members are expected to present a united front to the outside world—public disagreements are unthinkable. Behind closed doors, however, fierce factional struggles determine the fate of policies and people alike.

                Those who fall from Politburo favor rarely land softly.
                """,
                category: .institutions,
                relatedEntries: ["vwp", "general_secretary", "central_committee"]
            ),

            CodexEntry(
                id: "general_secretary",
                term: "General Secretary",
                shortDescription: "The supreme leader of the PSRA",
                fullDescription: """
                The General Secretary of the Communist Party of America is the most powerful person in the nation. While technically just "first among equals" on the Politburo, in practice the General Secretary exercises near-absolute authority over Party, state, and military.

                The position carries no term limits. A General Secretary rules until death, incapacitation, or—rarely—removal by his own colleagues. The succession process is notoriously opaque; when a General Secretary falls, the resulting power vacuum can reshape the entire political landscape.

                The current General Secretary resides in the Mitchell Compound, a fortified estate in central Washington. His every word is treated as policy. His favor can elevate a minor official to the heights of power; his displeasure can mean exile, imprisonment, or worse.

                "We are all servants of the Party. The General Secretary is simply the first servant."
                """,
                category: .institutions,
                relatedEntries: ["politburo", "vwp", "washington"]
            ),

            CodexEntry(
                id: "state_protection",
                term: "Bureau of People's Security",
                shortDescription: "The secret police and intelligence service",
                fullDescription: """
                The Bureau of People's Security (BPS) is the PSRA's feared security apparatus, responsible for internal surveillance, counterintelligence, and the suppression of dissent. Every citizen knows the Bureau's reputation; few speak of it openly.

                The Bureau maintains files on millions of citizens. Its informant network penetrates every workplace, apartment block, and social organization. To be "invited for a conversation" by Bureau officers is to face the possibility of never returning home.

                Officially, the Bureau reports to the Council of Ministers. In reality, the Bureau Director answers only to the General Secretary—and sometimes not even to him. The Bureau's institutional interests do not always align with the Party's, creating a delicate balance of mutual surveillance.

                Those who work for the Bureau are privileged but never trusted. Those who attract its attention are neither.
                """,
                category: .institutions,
                relatedEntries: ["wallace", "purge", "dissent"]
            ),

            CodexEntry(
                id: "central_committee",
                term: "Central Committee",
                shortDescription: "The Party's governing body between congresses",
                fullDescription: """
                The Central Committee of the Communist Party of America consists of several hundred full and candidate members elected at the Party Congress. It meets in full session (plenary session) several times per year to ratify decisions made by the Politburo.

                In theory, the Central Committee is the supreme body of the Party between congresses. In practice, it serves as a rubber stamp for Politburo decisions—though in moments of crisis, an assertive Central Committee has occasionally removed General Secretaries who lost the confidence of the elite.

                Membership in the Central Committee marks one as a member of the nomenklatura—the ruling elite. Central Committee members enjoy special privileges: better housing, access to restricted shops, the ability to travel abroad. They also face special scrutiny.

                A plenary session that goes "off script" can be the beginning of a political earthquake.
                """,
                category: .institutions,
                relatedEntries: ["vwp", "politburo", "nomenklatura"]
            ),

            CodexEntry(
                id: "peoples_army",
                term: "People's Army",
                shortDescription: "The armed forces of the PSRA",
                fullDescription: """
                The People's Army stands as one of the largest military forces in the world. Numbering in the millions, it maintains vast arsenals of conventional and nuclear weapons, a powerful navy, and an air force capable of projecting power across continents.

                The Army's officer corps is deeply intertwined with the Party—political commissars serve alongside military commanders at every level, ensuring ideological reliability. Yet the military also maintains its own institutional culture and interests, sometimes at odds with civilian leadership.

                Historically, the Army has been a kingmaker in the PSRA's politics. No General Secretary can rule without its acquiescence; those who threaten military prerogatives do so at their peril. General Raymond Carter, the current Deputy General Secretary, exemplifies the blurred line between military and political authority.

                "The Party commands the gun, but the gun has its own ideas."
                """,
                category: .institutions,
                relatedEntries: ["carter", "military_loyalty"]
            ),

            // CONCEPTS
            CodexEntry(
                id: "nomenklatura",
                term: "Nomenklatura",
                shortDescription: "The system of Party-controlled appointments",
                fullDescription: """
                The nomenklatura system is the mechanism by which the Party maintains control over all important positions in the PSRA. Every significant post—from factory directors to university rectors, from military officers to newspaper editors—appears on a list (nomenclatura) maintained by the Party apparatus.

                Only Party members approved by the relevant Party committee may hold nomenklatura positions. Advancement depends not only on competence but on political reliability, factional connections, and the patronage of senior officials.

                The term "nomenklatura" has come to refer not just to the system but to the people who benefit from it—the ruling elite of the PSRA. Nomenklatura members enjoy privileges invisible to ordinary citizens: special shops, better housing, foreign travel, and access to the best schools for their children.

                This game is named after this system. Your career depends on mastering it.
                """,
                category: .concepts,
                relatedEntries: ["vwp", "patron", "standing"]
            ),

            CodexEntry(
                id: "five_year_plan",
                term: "Five-Year Plan",
                shortDescription: "The economic planning framework",
                fullDescription: """
                The PSRA's economy operates according to Five-Year Plans—comprehensive documents setting production targets for every sector of the economy. The State Planning Commission coordinates the plan, attempting to balance competing demands for resources across thousands of enterprises.

                Fulfilling plan targets is the primary measure of success for economic officials. Quotas must be met—or exceeded—regardless of the human cost. Officials who fail to meet targets face disgrace; those who exceed them earn medals and promotions.

                The planning system produces both achievements and absurdities. The Republic has industrialized at remarkable speed, but the focus on quantity over quality leads to warehouses full of unusable goods. Falsified statistics are endemic, as officials at every level inflate their numbers to avoid punishment.

                "The Plan is the law. Failure to fulfill it is sabotage."
                """,
                category: .concepts,
                relatedEntries: ["industrial_output", "treasury", "economic_planning"]
            ),

            CodexEntry(
                id: "socialist_realism",
                term: "Socialist Realism",
                shortDescription: "The official artistic doctrine",
                fullDescription: """
                Socialist Realism is the only permitted artistic style in the Socialist Republic. Art must be "national in form, socialist in content"—depicting the heroic struggles of workers and peasants, the wise leadership of the Party, and the inevitable triumph of socialism.

                The doctrine emerged from the cultural campaigns of the 1930s, which suppressed all forms of artistic experimentation as "bourgeois formalism." Approved works celebrate collective labor, military valor, and Party loyalty. Abstract art, jazz, and Western influences are condemned as decadent.

                For artists, Socialist Realism is both constraint and protection. Those who master the approved style enjoy state patronage; those who deviate face censorship or worse. A few push boundaries carefully, encoding subtle critiques within acceptable forms.

                The Workers' Cultural Palace hosts official exhibitions. Underground, a samizdat culture of forbidden works circulates among the brave.
                """,
                category: .concepts,
                relatedEntries: ["ideology", "propaganda", "censorship"]
            ),

            // HISTORY
            CodexEntry(
                id: "revolution",
                term: "The Second American Revolution",
                shortDescription: "The founding event of the PSRA (1936-1940)",
                fullDescription: """
                The Second American Revolution transformed the United States from a failing capitalist democracy into a socialist republic. Following Herbert Hoover's disastrous response to the Great Depression, workers and union members rose against the old order, establishing the People's Socialist Republic of America from the ashes of the Federal Government.

                The Civil War period (1936-1940) saw fierce fighting between the Labour Councils and Federal/National Guard forces. The Soviet Union provided crucial aid—weapons, advisors, and supplies—turning the tide in favor of the revolutionaries. In exchange, part of Alaska was ceded to the USSR.

                Today, the Revolution is the founding myth of the PSRA. Every citizen knows its official history—though the actual events have been revised many times to reflect current political needs. Heroes become villains, and villains become non-persons, depending on the prevailing line.

                "We built a new America from the wreckage of the old."
                """,
                category: .history,
                relatedEntries: ["vwp", "ideology", "founders"]
            ),

            CodexEntry(
                id: "purge",
                term: "The Consolidation Purges",
                shortDescription: "The terror of the early years (1942-1944)",
                fullDescription: """
                The Consolidation Purges (1942-1944) were a period of mass political repression following the Revolution's victory. Hundreds of thousands were arrested, imprisoned, or executed on charges of collaboration with the old regime, sabotage, and counter-revolutionary conspiracy.

                The Purges began as a campaign against former Federal officials and capitalists but spiraled into generalized terror. Suspected collaborators confessed to impossible crimes in show trials. Military officers were shot as spies for the government-in-exile. Ordinary citizens disappeared for a careless word about the old days.

                The Purges permanently traumatized American society. Trust became impossible; denunciation became a survival strategy. Even a decade later, the memory shapes political behavior—officials know that today's loyalty may not protect against tomorrow's terror.

                Some of those purged have since been "rehabilitated"—declared innocent posthumously. Their executioners often went unpunished.
                """,
                category: .history,
                relatedEntries: ["state_protection", "rehabilitation", "terror"]
            ),

            CodexEntry(
                id: "great_war",
                term: "The Intervention War",
                shortDescription: "The British-Canadian invasion (1941-1942)",
                fullDescription: """
                The Intervention War (1941-1942) saw Britain and Canada attempt to crush the young socialist republic and restore the Federal Government. Their forces crossed from Canada, hoping to link up with loyalist remnants—but the People's Army, hardened by civil war, threw them back.

                The counteroffensive pushed into Canada itself. British Columbia and Alberta fell to revolutionary forces, becoming the People's Federated Territory. The British Empire, overextended and facing unrest in its colonies, was forced to accept an armistice.

                The war's legacy shapes the PSRA's politics. Military spending remains sacrosanct. The threat from Canada and Britain is taken seriously. And the Party claims credit for victory, pointing to the conquered territories as proof of socialist strength.

                "They tried to strangle us in the cradle. We survived and grew stronger."
                """,
                category: .history,
                relatedEntries: ["peoples_army", "military_loyalty", "canada", "united_kingdom"]
            ),

            // MARK: - REGIONS (Domestic Zones)

            CodexEntry(
                id: "region_capital",
                term: "Capital District",
                shortDescription: "Washington D.C. - the political heart of the PSRA",
                fullDescription: """
                The Capital District encompasses Washington D.C. and its surrounding administrative zone. Home to three million people, it is the seat of all central government institutions: the Politburo, the Council of Ministers, the Central Committee, and the Bureau of People's Security.

                The old Federal buildings have been repurposed for the Revolution. The Capitol houses the People's Congress; the White House—renamed the People's House—serves ceremonial functions. New brutalist ministry buildings have risen alongside the old monuments. The Lincoln Memorial remains, reinterpreted as honoring a "proto-revolutionary" who freed the slaves.

                Washington is where careers are made and destroyed. Every ambitious official schemes to secure a posting here. To be "sent to the provinces" is understood as punishment. Yet the watchers are also watched—nowhere is surveillance more intense than in the capital itself.

                The Metro has been expanded and beautified in socialist style: palatial stations decorated with murals celebrating the Second Revolution. Deep underground, it also serves as a bomb shelter for the war everyone fears.
                """,
                category: .regions,
                relatedEntries: ["washington", "politburo", "general_secretary", "state_protection"]
            ),

            CodexEntry(
                id: "region_northeast",
                term: "Northeast Industrial Zone",
                shortDescription: "The manufacturing heartland and revolution's birthplace",
                fullDescription: """
                The Northeast Industrial Zone stretches from Boston to Philadelphia—the original stronghold of the Revolution. Its factories, shipyards, and mills produce the goods that power the socialist economy. These cities saw the first Labour Council uprisings; their workers remember when they marched on Washington.

                Forty million workers labor here in conditions transformed since the Revolution, though not always for the better. The twelve-hour shifts remain; the factory discipline is stricter than ever. Yet workers take fierce pride in their role as the vanguard of American socialism. "We started this Revolution," they say, "and we'll defend it."

                Politically, the Northeast is the Party's most reliable base—its workers are among the most committed Party members in the country. But reliability has limits. When conditions become unbearable, wildcat strikes erupt despite official prohibition. The Party learned early that pushing the Northeast too hard risks unrest that could spread nationwide.

                The region's Party boss is traditionally one of the most powerful figures in the country, commanding millions of workers and controlling the industrial output that keeps the Republic running.
                """,
                category: .regions,
                relatedEntries: ["five_year_plan", "industrial_output", "revolution"]
            ),

            CodexEntry(
                id: "region_greatlakes",
                term: "Great Lakes Zone",
                shortDescription: "Heavy industry and the union power base",
                fullDescription: """
                The Great Lakes Zone—Detroit, Chicago, Cleveland, Milwaukee—is the beating heart of American heavy industry. Auto plants converted to tractor factories, steel mills nationalized and expanded, the great union halls now serving as Party headquarters. This is where American industrial might was forged, and where socialist production now reaches its peak.

                Thirty-five million inhabitants live in factory cities built around massive enterprises. The Detroit Tractor Collective alone employs 120,000 workers; the Gary Steel Works produces the metal that builds everything from farm equipment to tanks. These are company towns in the purest sense—the enterprise provides housing, schools, clinics, and culture.

                The Great Lakes were union country before the Revolution, and that tradition persists. Workers here have a strong sense of their collective power. The Party channels this through official union structures, but the memory of independent labor action remains. When the workers of the Great Lakes speak, the Politburo listens.

                Production quotas dominate life. Every factory has its targets, every shift its norms. The pressure to meet the Plan creates its own pathologies: falsified statistics, hidden defects, goods that exist on paper but crumble in practice.
                """,
                category: .regions,
                relatedEntries: ["five_year_plan", "industrial_output", "peoples_army"]
            ),

            CodexEntry(
                id: "region_pacific",
                term: "Pacific Zone",
                shortDescription: "West coast ports and the seized Canadian territories",
                fullDescription: """
                The Pacific Zone encompasses the former states of California, Oregon, and Washington—plus the People's Federated Territory seized from Canada during the Intervention War. From San Francisco to Vancouver, this zone controls America's window to the Pacific and the confrontation with Imperial Japan.

                Fifty million people inhabit this diverse region. The ports of Los Angeles, San Francisco, Seattle, and Vancouver handle trade with Asia and project naval power across the Pacific. The film industry in Hollywood has been nationalized, producing socialist cinema that rivals anything from Germany or the USSR.

                The People's Federated Territory—former British Columbia and Alberta—presents unique challenges. The Canadian population was not liberated but conquered, and resentment simmers beneath the surface. Surveillance is intense; the BPS maintains a heavy presence. Yet the territory's resources—timber, minerals, oil—make it too valuable to release.

                Hawaii's occupation by Japan casts a shadow over the entire zone. Every sailor, every soldier knows that someday the Republic must reclaim those islands. The Pacific Fleet trains constantly for that day.
                """,
                category: .regions,
                relatedEntries: ["peoples_army", "japan", "canada", "great_war"]
            ),

            CodexEntry(
                id: "region_southern",
                term: "Southern Zone",
                shortDescription: "Former Confederate states with complex political dynamics",
                fullDescription: """
                The Southern Zone encompasses the former Confederate states—a region whose history of slavery, segregation, and racial violence presented unique challenges for the Revolution. The transformation has been dramatic but incomplete.

                Sixty million people call the South home. The old plantation system was abolished entirely; land was redistributed to collective farms worked by former sharecroppers, both Black and white. Jim Crow laws were swept away, replaced by enforced socialist equality. For Black Americans, the Revolution delivered what Reconstruction had promised and failed to provide.

                Yet the old attitudes persist in corners. Former segregationists who mouthed socialist slogans to survive sometimes reveal their true beliefs. The Party monitors closely for "bourgeois racism" and punishes it severely—but changing hearts takes longer than changing laws.

                The South's agricultural output feeds the nation. Cotton, tobacco, and food crops flow north to the industrial zones. The region's Party boss must balance the demands of production with the ongoing project of social transformation.
                """,
                category: .regions,
                relatedEntries: ["state_protection", "revolution", "five_year_plan"]
            ),

            CodexEntry(
                id: "region_plains",
                term: "Plains Zone",
                shortDescription: "Agricultural heartland and farming collectives",
                fullDescription: """
                The Plains Zone stretches from Texas to the Dakotas—the breadbasket of the PSRA. Vast collective farms have replaced family homesteads, their combines harvesting wheat that feeds two hundred million citizens. The transformation of American agriculture into socialist production was brutal but effective.

                Twenty-five million people work this land. The independent farmer—that icon of old America—has been replaced by the collective farm worker, living in planned agricultural communities and meeting production quotas set in Washington. Some adapted; others resisted and were "relocated" to less pleasant assignments.

                The collectivization campaigns of 1942-1945 left deep scars. Farmers who resisted saw their land seized, their families broken apart. The term "kulak"—borrowed from Soviet experience—was applied to any farmer deemed insufficiently enthusiastic about surrendering his property. Many were sent to labor camps in Alaska; many never returned.

                Today, the Plains produce surplus grain that the PSRA exports to allied nations. The trauma of collectivization has faded into bitter memory, but the older generation remembers. They work the collective fields and say nothing.
                """,
                category: .regions,
                relatedEntries: ["purge", "five_year_plan", "revolution"]
            ),

            CodexEntry(
                id: "region_mountain",
                term: "Mountain Zone",
                shortDescription: "Mining, resources, and exile territories",
                fullDescription: """
                The Mountain Zone encompasses the Rocky Mountain states—a vast territory of mines, forests, and the labor camps that extract their wealth. From Montana to Arizona, this zone provides the raw materials that fuel socialist construction: copper, uranium, coal, and the timber that builds the cities of the coasts.

                Fifteen million people inhabit this harsh region, many of them not by choice. The Mountain Zone serves as the PSRA's internal exile territory—political prisoners, class enemies, and the merely unlucky are sent here to contribute their labor to socialist construction. Some work in the open; others in the vast camp system that stretches across the wilderness.

                For those not in the camps, life is hard but free of the intense surveillance found elsewhere. The mountains breed a certain independence of spirit that the Party tolerates as long as quotas are met. Some exiles, released but forbidden to return home, have built new lives in mining towns where no one asks too many questions.

                Assignment to the Mountain Zone is usually punishment for officials. Yet control of its mineral wealth means control of strategic resources. A few ambitious administrators have transformed exile into opportunity.
                """,
                category: .regions,
                relatedEntries: ["purge", "state_protection", "industrial_output"]
            ),

            // MARK: - WORLD ATLAS (Foreign Nations)

            // SOCIALIST ALLIES

            CodexEntry(
                id: "soviet_union",
                term: "Soviet Union",
                shortDescription: "Revolutionary ally who helped the Second Revolution",
                fullDescription: """
                The Union of Soviet Socialist Republics is the world's first socialist state and our revolutionary ally. When the Second American Civil War began, Moscow saw an opportunity to spread world revolution—and seized it.

                Geography: Spanning Eurasia from Eastern Europe to the Pacific. The largest country on Earth, with vast resources and harsh climate.

                Population: 200 million people organized under Communist Party rule. Their industrial capacity rivals our own; their military might deters our enemies.

                Government: Communist state under the Communist Party of the Soviet Union. Premier Malenkov pursues a cautious foreign policy after Stalin's death.

                Relations: Complicated gratitude. They saved our Revolution with weapons, advisors, and supplies. In exchange, we ceded part of Alaska—a debt some resent. Moscow expects ideological conformity; we increasingly chafe at being treated as a junior partner.

                Dynamic Potential: Relations can improve through cooperation or sour through conflict. We are allies, not satellites.
                """,
                category: .worldAtlas,
                relatedEntries: ["revolution", "peoples_army"]
            ),

            CodexEntry(
                id: "germany",
                term: "Germany",
                shortDescription: "Socialist republic - ally to both USSR and PSRA",
                fullDescription: """
                The German Socialist Republic proves that socialism can triumph through democratic means. In this timeline, the Nazis never rose to power—the Social Democrats and Communists united against them in 1932, transforming Germany into a socialist state without civil war.

                Geography: Central Europe. Industrial heartland, rebuilt and thriving under socialist management.

                Population: 70 million highly educated workers. German engineering and precision manufacturing remain legendary; their economy rivals any in Europe.

                Government: Socialist Republic under the Socialist Unity Party. Chairman Ernst Thälmann leads a coalition of former Social Democrats and Communists.

                Relations: Our closest ideological ally. German-American socialist solidarity predates both our revolutions. Trade is substantial; their machinery builds our factories. More importantly, Germany proves socialism can succeed democratically—a model we find appealing.

                Dynamic Potential: A bridge between American and Soviet socialism. Germany's success validates our system worldwide.
                """,
                category: .worldAtlas,
                relatedEntries: ["soviet_union", "five_year_plan"]
            ),

            // CAPITALIST ADVERSARIES

            CodexEntry(
                id: "cuba",
                term: "Cuba",
                shortDescription: "Hosts the US Government-in-Exile - our mortal enemy",
                fullDescription: """
                The Republic of Cuba hosts what claims to be the legitimate United States government. When the Federal Government collapsed in 1940, President Hoover and key officials fled to Havana, where they established a government-in-exile that still plots our overthrow.

                Geography: Caribbean island, ninety miles from our shores. Strategic position commanding the Gulf of Mexico.

                Population: 6 million Cubans plus thousands of American emigres who fled the Revolution. The exile community seethes with hatred and dreams of return.

                Government: The Batista regime hosts the "President-in-Exile" Robert Taft Jr., who claims to lead the legitimate United States. Britain and Canada recognize this fiction; most of the world does not.

                Relations: Existential enmity. They claim our government is illegitimate; we claim theirs is a puppet show. No diplomatic relations. Every exile is a potential saboteur; every fishing boat might carry agents.

                Dynamic Potential: The Cuba question must be resolved someday—through negotiation, subversion, or force.
                """,
                category: .worldAtlas,
                relatedEntries: ["state_protection", "united_kingdom", "revolution"]
            ),

            CodexEntry(
                id: "canada",
                term: "Canada",
                shortDescription: "Lost territory to PSRA - bitter revanchist enemy",
                fullDescription: """
                The Dominion of Canada is our neighbor to the north, now bitterly hostile. When Britain and Canada intervened in 1941 to help the Federal Government, our forces pushed back—and kept pushing. British Columbia and Alberta now fly our flag.

                Geography: Northern North America. Vast territory, harsh climate, reduced by our conquest of its western provinces.

                Population: 14 million Canadians, consumed by resentment. "The Lost Provinces" dominate every election; military spending drains the treasury.

                Government: Constitutional Monarchy under the British Crown. Prime Minister George Drew leads a government defined by revanchism.

                Relations: Bitter enmity. They intervened; we conquered. The border bristles with fortifications. Incidents occur regularly—sometimes shots are fired. Neither side wants full-scale war, but neither side will back down.

                Dynamic Potential: Could negotiate return of territory (unlikely), could launch another war, could accept reality. The wound festers.
                """,
                category: .worldAtlas,
                relatedEntries: ["united_kingdom", "great_war", "region_pacific"]
            ),

            CodexEntry(
                id: "united_kingdom",
                term: "United Kingdom",
                shortDescription: "Empire intact - leads global opposition to American socialism",
                fullDescription: """
                The United Kingdom of Great Britain and Northern Ireland remains the world's greatest imperial power. Without a World War to drain their resources, Britain retains much of its colonial empire—and leads the capitalist world's opposition to American socialism.

                Geography: Island nation off Western Europe, commanding a global empire from India to Africa to the Caribbean.

                Population: 50 million Britons, plus hundreds of millions of colonial subjects. The sun still never sets on British dominion.

                Government: Constitutional Monarchy with Parliament. Prime Minister Anthony Eden maintains firm anti-socialist policies while managing a restless empire.

                Relations: They tried to crush our Revolution and failed. We humiliated them in Canada. Their spies swarm through Cuba and Mexico. Our agents work to undermine their colonial rule. The "special relationship" is one of mutual hostility.

                Dynamic Potential: Britain is the enemy we must eventually either defeat or accommodate. Their empire may crumble; their resolve may weaken. Nothing lasts forever.
                """,
                category: .worldAtlas,
                relatedEntries: ["canada", "cuba", "great_war"]
            ),

            CodexEntry(
                id: "france",
                term: "France",
                shortDescription: "Unstable - swings between left and right",
                fullDescription: """
                The French Republic is the most unpredictable power in Europe. French politics swing wildly between left and right, between accommodation with socialism and fierce anti-communism. Today's enemy might be tomorrow's friend.

                Geography: Western Europe. Industrial north, agricultural south, colonial possessions in Africa and Asia.

                Population: 42 million French citizens, plus colonial subjects. A large Communist Party provides both opportunity and concern.

                Government: Unstable parliamentary republic. Governments rise and fall with dizzying speed. Premier Mendès France leads the latest fragile coalition.

                Relations: Complicated. Official relations are strained but not frozen. Trade continues. French intellectuals debate our system endlessly; French communists look to us for inspiration.

                Dynamic Potential: If France goes socialist, the capitalist bloc fractures. If France goes fascist, we face another enemy. French politics bear constant watching.
                """,
                category: .worldAtlas,
                relatedEntries: ["united_kingdom", "germany"]
            ),

            // FASCIST POWERS

            CodexEntry(
                id: "italy",
                term: "Italy",
                shortDescription: "Mussolini still in power - controls North Africa",
                fullDescription: """
                The Italian Social Republic is fascism's original home, still standing. Without a World War to destroy him, Mussolini remains in power, his regime controlling Italy and much of North Africa.

                Geography: Southern Europe and North Africa. Mediterranean power controlling vital shipping lanes.

                Population: 47 million Italians, plus colonial subjects in Libya, Ethiopia, and beyond. The fascist experiment continues.

                Government: Fascist dictatorship under Benito Mussolini. The aging Duce still commands; succession looms uncertain.

                Relations: Ideological enemies but not at war. Mussolini hates communism but hates British imperialism too. Italian intelligence cooperates with British services against us—but also competes with them.

                Dynamic Potential: When Mussolini falls—and he will—Italy could go any direction. We should be ready.
                """,
                category: .worldAtlas,
                relatedEntries: ["spain", "united_kingdom"]
            ),

            CodexEntry(
                id: "spain",
                term: "Spain",
                shortDescription: "Franco's fascist state - isolated",
                fullDescription: """
                The Spanish State is Franco's creation—victorious in civil war, isolated in peace. The Spanish Civil War of 1936-1939 ended in Nationalist victory, establishing a fascist state that survives through repression.

                Geography: Southwestern Europe. Strategic position controlling access to the Mediterranean.

                Population: 28 million Spaniards living under authoritarian rule. Spanish republicans in exile dream of liberation.

                Government: Fascist dictatorship under Francisco Franco. The Caudillo grows old; his regime ossifies.

                Relations: Blood enemies. We backed the Spanish Republic; Franco killed it. Spanish refugees who fought in our own Revolution live in our territory, plotting return.

                Dynamic Potential: When Franco falls, Spain could go socialist, could go democratic, could descend into chaos. Spanish exiles wait for their moment.
                """,
                category: .worldAtlas,
                relatedEntries: ["italy", "revolution"]
            ),

            // PACIFIC POWERS

            CodexEntry(
                id: "japan",
                term: "Japan",
                shortDescription: "Imperial Japan holding Hawaii - major strategic threat",
                fullDescription: """
                The Empire of Japan is the rising sun that never set. While America tore itself apart in civil war, Imperial Japan seized Hawaii and expanded across Asia. They hold our islands hostage; their empire stretches from Manchuria to the mid-Pacific.

                Geography: Island nation commanding the Western Pacific. Colonial possessions include Korea, Manchuria, parts of China, and Hawaii.

                Population: 85 million Japanese, plus tens of millions of colonial subjects. A militarist government pursues expansion.

                Government: Constitutional monarchy dominated by military cliques. The Emperor reigns; the generals rule.

                Relations: They stole Hawaii when we were weak. We have never recognized their occupation; they have never recognized our government. Japanese-American citizens in Hawaii face persecution.

                Dynamic Potential: Someday, there will be a reckoning. Liberating Hawaii is a national priority that events have not yet permitted.
                """,
                category: .worldAtlas,
                relatedEntries: ["china", "region_pacific", "peoples_army"]
            ),

            CodexEntry(
                id: "china",
                term: "China",
                shortDescription: "Under Japanese occupation - potential future ally",
                fullDescription: """
                The Republic of China groans under Japanese occupation. The Kuomintang government has retreated to the interior; Communist guerrillas fight in the north; Japanese forces control the coast. China's fate remains undecided.

                Geography: East Asia. Vast territory, enormous population, currently torn apart by invasion and civil conflict.

                Population: 450 million Chinese—the largest nation on Earth—divided between Japanese occupation, Nationalist resistance, and Communist guerrillas.

                Government: Contested. Chiang Kai-shek's Nationalists claim legitimacy from Chongqing; Mao Zedong's Communists grow stronger in the countryside.

                Relations: Potential allies against a common enemy. Both Chinese factions seek our support; we provide what we can without provoking Japan into wider conflict.

                Dynamic Potential: Whoever helps free China from Japan will have enormous influence over its future. The situation is fluid, the stakes enormous.
                """,
                category: .worldAtlas,
                relatedEntries: ["japan", "soviet_union"]
            ),

            // NEIGHBORS

            CodexEntry(
                id: "mexico",
                term: "Mexico",
                shortDescription: "Oligarchy playing both sides - helped during revolution",
                fullDescription: """
                The United Mexican States walks a careful line. Mexico is neither socialist nor fully capitalist—a one-party state run by an oligarchy that mouths revolutionary rhetoric while maintaining capitalist structures.

                Geography: Southern neighbor. Long border, shared history, strategic position.

                Population: 28 million Mexicans. Their own revolution, decades before ours, created a unique system that has made peace with capitalism.

                Government: One-party rule under the PRI (Institutional Revolutionary Party). President Alemán focuses on development, not ideology.

                Relations: Helpful neighbors who refuse to become allies. They aided our Revolution—Soviet weapons flowed through Mexican ports—but will not join our bloc. We share a long border and longer history; they remember the wars of the 19th century.

                Dynamic Potential: If Mexico joined the capitalist bloc, we would face enemies on two land borders. Keeping Mexico neutral—or better—is essential.
                """,
                category: .worldAtlas,
                relatedEntries: ["revolution", "region_southern"]
            )
        ]

        for entry in defaultEntries {
            entries[entry.id] = entry
        }
    }
}
