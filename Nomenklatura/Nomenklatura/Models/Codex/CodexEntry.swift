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
    case history        // "The Revolution", "The Great Purge"
    case characters     // NPC entries (unlocked when met)
    case regions        // Domestic zones of the PSR
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
                The Princelings are descendants of the Revolution's founders and heroes—a "Red Aristocracy" whose parents fought in the Revolutionary War and built the People's Socialist Republic. Their names carry weight in every corridor of power; doors open for them that remain closed to others.

                Princeling networks span the highest levels of Party, military, and security services. They grew up together in exclusive compounds, attended the same schools, and married into each other's families. Their loyalty is primarily to each other and to preserving their inherited status.

                In factional terms, Princelings defend the privileges of the elite against reform movements and meritocratic challenges. They are vulnerable to anti-corruption campaigns—their wealth and connections make tempting targets when political winds shift.

                "My father died storming the colonial capital. What did yours do?"
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
                The Proletariat Union are the keepers of ideological orthodoxy—officials who remember why the Revolution was fought and resist any deviation from socialist principles. They view reform as betrayal and modernization as capitulation to enemy values.

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
                shortDescription: "Provincial Networks - power built far from the capital",
                fullDescription: """
                Regional faction leaders built their careers in the provinces, far from the intrigues of The Capital. They cultivated loyal networks among local officials, factory directors, and Party secretaries. When they arrived in the corridors of central power, they brought armies of supporters.

                The regional power base provides both strength and vulnerability. Regional patrons can mobilize resources and personnel beyond the reach of capital elites. But they are also viewed as outsiders with "provincial thinking"—unsophisticated, parochial, and potentially disloyal to central authority.

                "Localism" is a serious accusation. Regional leaders must constantly demonstrate their commitment to the whole Republic, not just their home zones. Those who fail this test can be purged for putting regional interests above the state.

                "We built real socialism in the heartland while they were playing politics in the capital."
                """,
                category: .factions,
                relatedEntries: ["nomenklatura", "region_industrial", "region_agricultural"]
            ),

            // INSTITUTIONS
            CodexEntry(
                id: "vwp",
                term: "The Communist Party",
                shortDescription: "The ruling political party of the PSR",
                fullDescription: """
                The Communist Party is the sole legal political party in the nation. Founded in the crucible of the Revolutionary War, the Party serves as the "vanguard of the working class" and exercises complete control over all aspects of state and society.

                The Party is organized along democratic centralist principles: decisions flow from the top down, while information and obedience flow from the bottom up. At its apex sits the General Secretary, who chairs the Politburo and effectively rules the People's Socialist Republic.

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
                The Politburo is the supreme decision-making body of the Communist Party. Consisting of approximately 15-25 full members and candidate members, the Politburo meets weekly to determine policy on all matters of state.

                In theory, the Politburo is elected by the Central Committee. In practice, its composition is determined by the General Secretary and reflects the current balance of power among Party factions. A seat on the Politburo represents the pinnacle of political achievement in the PSR.

                Politburo meetings are conducted in strict secrecy. Members are expected to present a united front to the outside world—public disagreements are unthinkable. Behind closed doors, however, fierce factional struggles determine the fate of policies and people alike.

                Those who fall from Politburo favor rarely land softly.
                """,
                category: .institutions,
                relatedEntries: ["vwp", "general_secretary", "central_committee"]
            ),

            CodexEntry(
                id: "general_secretary",
                term: "General Secretary",
                shortDescription: "The supreme leader of the PSR",
                fullDescription: """
                The General Secretary of the Communist Party is the most powerful person in the nation. While technically just "first among equals" on the Politburo, in practice the General Secretary exercises near-absolute authority over Party, state, and military.

                The position carries no term limits. A General Secretary rules until death, incapacitation, or—rarely—removal by his own colleagues. The succession process is notoriously opaque; when a General Secretary falls, the resulting power vacuum can reshape the entire political landscape.

                The current General Secretary resides in the Mitchell Compound, a fortified estate in central The Capital. His every word is treated as policy. His favor can elevate a minor official to the heights of power; his displeasure can mean exile, imprisonment, or worse.

                "We are all servants of the Party. The General Secretary is simply the first servant."
                """,
                category: .institutions,
                relatedEntries: ["politburo", "vwp", "nova_pravda"]
            ),

            CodexEntry(
                id: "state_protection",
                term: "Bureau of People's Security",
                shortDescription: "The secret police and intelligence service",
                fullDescription: """
                The Bureau of People's Security (BPS) is the PSR's feared security apparatus, responsible for internal surveillance, counterintelligence, and the suppression of dissent. Every citizen knows the Bureau's reputation; few speak of it openly.

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
                The Central Committee of the Communist Party consists of several hundred full and candidate members elected at the Party Congress. It meets in full session (plenary session) several times per year to ratify decisions made by the Politburo.

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
                shortDescription: "The armed forces of the PSR",
                fullDescription: """
                The People's Army stands as one of the larger military forces in its region. Numbering in the hundreds of thousands, it maintains conventional forces, a modest navy, and an air force equipped with Soviet-supplied aircraft.

                The Army's officer corps is deeply intertwined with the Party—political commissars serve alongside military commanders at every level, ensuring ideological reliability. Yet the military also maintains its own institutional culture and interests, sometimes at odds with civilian leadership.

                Historically, the Army has been a kingmaker in the PSR's politics. No General Secretary can rule without its acquiescence; those who threaten military prerogatives do so at their peril. General Raymond Carter, the current Deputy General Secretary, exemplifies the blurred line between military and political authority.

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
                The nomenklatura system is the mechanism by which the Party maintains control over all important positions in the PSR. Every significant post—from factory directors to university rectors, from military officers to newspaper editors—appears on a list (nomenclatura) maintained by the Party apparatus.

                Only Party members approved by the relevant Party committee may hold nomenklatura positions. Advancement depends not only on competence but on political reliability, factional connections, and the patronage of senior officials.

                The term "nomenklatura" has come to refer not just to the system but to the people who benefit from it—the ruling elite of the PSR. Nomenklatura members enjoy privileges invisible to ordinary citizens: special shops, better housing, foreign travel, and access to the best schools for their children.

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
                The PSR's economy operates according to Five-Year Plans—comprehensive documents setting production targets for every sector of the economy. The State Planning Commission coordinates the plan, attempting to balance competing demands for resources across thousands of enterprises.

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

                The doctrine emerged from the cultural campaigns following the Revolution, which suppressed all forms of artistic experimentation as "bourgeois formalism." Approved works celebrate collective labor, military valor, and Party loyalty. Abstract art and Western influences are condemned as decadent.

                For artists, Socialist Realism is both constraint and protection. Those who master the approved style enjoy state patronage; those who deviate face censorship or worse. A few push boundaries carefully, encoding subtle critiques within acceptable forms.

                The Workers' Cultural Palace hosts official exhibitions. Underground, a samizdat culture of forbidden works circulates among the brave.
                """,
                category: .concepts,
                relatedEntries: ["ideology", "propaganda", "censorship"]
            ),

            // HISTORY
            CodexEntry(
                id: "revolution",
                term: "The Revolution",
                shortDescription: "The founding event of the PSR",
                fullDescription: """
                The Revolution transformed a colonial territory into a socialist republic. Following years of exploitation by foreign powers, workers and peasants rose against the old order, establishing the People's Socialist Republic from the ashes of colonial rule.

                The Revolutionary War period saw fierce fighting between the revolutionary councils and colonial forces. The Soviet Union provided crucial aid—weapons, advisors, and supplies—turning the tide in favor of the revolutionaries.

                Today, the Revolution is the founding myth of the PSR. Every citizen knows its official history—though the actual events have been revised many times to reflect current political needs. Heroes become villains, and villains become non-persons, depending on the prevailing line.

                "We built a new nation from the wreckage of the old."
                """,
                category: .history,
                relatedEntries: ["vwp", "ideology", "founders"]
            ),

            CodexEntry(
                id: "purge",
                term: "The Consolidation Purges",
                shortDescription: "The terror of the early years",
                fullDescription: """
                The Consolidation Purges were a period of mass political repression following the Revolution's victory. Hundreds of thousands were arrested, imprisoned, or executed on charges of collaboration with the colonial regime, sabotage, and counter-revolutionary conspiracy.

                The Purges began as a campaign against colonial officials and collaborators but spiraled into generalized terror. Suspected enemies confessed to impossible crimes in show trials. Military officers were shot as spies. Ordinary citizens disappeared for a careless word.

                The Purges permanently traumatized society. Trust became impossible; denunciation became a survival strategy. Even decades later, the memory shapes political behavior—officials know that today's loyalty may not protect against tomorrow's terror.

                Some of those purged have since been "rehabilitated"—declared innocent posthumously. Their executioners often went unpunished.
                """,
                category: .history,
                relatedEntries: ["state_protection", "rehabilitation", "terror"]
            ),

            CodexEntry(
                id: "great_war",
                term: "The Border Wars",
                shortDescription: "Post-revolutionary conflicts that secured the frontiers",
                fullDescription: """
                The Border Wars followed the Revolution's victory, as the young socialist republic fought to secure its frontiers against hostile neighbors. Colonial powers and their allies probed for weakness; the People's Army pushed them back.

                The fighting secured the territory that would become the Seven Zones. The military commanders who led these campaigns became heroes—and later, in some cases, victims of the Purges that consumed their reputations along with their lives.

                The wars' legacy shapes the PSR's politics. Military spending remains sacrosanct. The threat from foreign powers is taken seriously. And the Party claims credit for victory, pointing to secured borders as proof of socialist strength.

                "They tried to strangle us in the cradle. We survived and grew stronger."
                """,
                category: .history,
                relatedEntries: ["peoples_army", "military_loyalty"]
            ),

            // MARK: - FOUNDERS OF THE REVOLUTION

            CodexEntry(
                id: "fitzgerald",
                term: "Chairman Robert Fitzgerald",
                shortDescription: "First General Secretary - Father of the Republic",
                fullDescription: """
                Robert Fitzgerald was a factory worker who became the first General Secretary of the PSR. Born to immigrant parents in a cramped tenement in what would become Fitzgerald City, he lost his father to a factory accident at age twelve. By twenty, he was organizing wildcat strikes; by thirty, he led the largest union local in the industrial zone.

                When revolutionary ferment spread through the factories, Fitzgerald transformed from labor organizer to revolutionary leader. His gift was making Marxism sound like common sense. "We're not asking for the moon," he'd say at rallies. "We're asking for what our labor already earns." He personally led the Fitzgerald City column in the March on the Capital and stood on the steps of the People's House to proclaim the Republic.

                As General Secretary, Fitzgerald walked an impossible line. He protected many during the early Purges—"These are our people, not enemies"—but signed death warrants when political necessity demanded. He built the Youth League as a meritocratic counterweight to emerging elite families. He chose Harold Mitchell as his successor.

                Several years after the Revolution's victory, Fitzgerald collapsed at his desk. Official cause: heart attack. He was in apparent good health. Every official biography celebrates him. Every faction claims his mantle. And everyone wonders: what really happened?

                "The Chairman lives in all of us who carry forward the Revolution."
                """,
                category: .history,
                relatedEntries: ["revolution", "youth_league", "purge"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "steele",
                term: "General Marcus Steele",
                shortDescription: "Hero of Fitzgerald City (executed during the Purges)",
                fullDescription: """
                Marcus Steele was the Revolution's greatest military commander—and its most dangerous man. A former colonial army officer who resigned in disgust after being ordered to fire on striking workers, Steele brought professional military expertise to the revolutionary militias.

                The Battle of Fitzgerald City was his masterpiece. Outnumbered three to one, he turned the city's factories and tenements into death traps for colonial forces. Forty thousand died in those brutal months; when it was over, the industrial heartland belonged to the Revolution.

                During the Border Wars that followed, Steele commanded the offensives that secured the nation's frontiers. His troops worshipped him. His officers feared him. And the Party—the civilian Party—grew increasingly nervous about a general more popular than any politician.

                During the Purges, Steele was arrested on charges of "military conspiracy with foreign powers." The Trial of the Thirty-Six saw 36 senior officers accused. Steele alone refused to confess. "History will judge," he said as they led him to execution.

                His legacy haunts the Princelings—the children of revolutionary families who remember what was done to their hero.
                """,
                category: .history,
                relatedEntries: ["battle_stahlgrad", "trial_thirtysix", "peoples_army"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "briggs",
                term: "Commissar Thomas Briggs",
                shortDescription: "Father of the Princelings (deceased)",
                fullDescription: """
                Thomas Briggs was a political commissar—a Party man who fought alongside soldiers to ensure ideological purity. At the Highland Decimation, when colonial troops opened fire on workers' families, Briggs organized the surviving men into a fighting force that held the revolutionary districts for six crucial weeks.

                Unlike Steele, Briggs understood that politics and guns must work together. He became the model political officer: brave enough for soldiers to respect, reliable enough for the Party to trust. His three children grew up in the compounds of the revolutionary elite.

                Briggs died a hero's death after the Revolution, leading a counterattack against foreign forces attempting to breach the frontier. The bullet that killed him came from enemy soldiers—not Party executioners. This made his death useful.

                His children married strategically: into the Carter family, the Fletcher family, the Crawford family. The Briggs bloodline runs through the Princeling elite like a golden thread. To claim descent from Thomas Briggs opens doors that merit cannot.

                "He gave his life for the Revolution. His children honor that sacrifice."
                """,
                category: .history,
                relatedEntries: ["gornoye_decimation", "princelings", "great_war"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "novak",
                term: "Dr. Helen Novak",
                shortDescription: "The Revolution's Conscience (executed during the Purges)",
                fullDescription: """
                Helen Novak was a physician who organized revolutionary field hospitals during the Revolutionary War. Trained abroad before returning to her homeland, she could have fled to comfortable exile. Instead, she set up operating theaters in factory basements and taught nurses to save lives under artillery fire.

                Novak believed the Revolution would build something better—not just seize power but create justice. She wrote pamphlets on public health. She advocated for workers' safety. She treated wounded colonial prisoners over the objections of Party hardliners. "They're workers too," she said. "Just workers in the wrong uniform."

                This idealism made her a target. During the Intellectuals' Purge, she was arrested on charges of "conspiracy" and "sabotage of revolutionary medicine." Her trial lasted twenty minutes.

                She was rehabilitated later—declared innocent—then de-rehabilitated when the political winds shifted again. Her medical manuals remain in use. Her name is never mentioned.

                "Some names are best forgotten. For the good of the Revolution."
                """,
                category: .history,
                relatedEntries: ["purge", "intellectuals_purge"],
                unlockedByDefault: true
            ),

            // MARK: - NAMED BATTLES

            CodexEntry(
                id: "march_capital",
                term: "The March on the Capital",
                shortDescription: "The shot that started the Revolution",
                fullDescription: """
                Two hundred thousand workers from Fitzgerald City, Red Harbor, Highland, and the surrounding regions began marching on the colonial capital. They demanded an end to repressive labor laws, recognition of workers' councils, and colonial withdrawal. They carried signs, not guns.

                Chairman Fitzgerald led the Fitzgerald City column personally. The marchers expected resistance. They did not expect massacre.

                As the columns converged on the central plaza, colonial troops opened fire. Official records claim 47 dead. The true number was far higher. The March on the Capital became "Bloody Sunday"—the moment when peaceful protest became armed revolution.

                Within a week, workers' councils across the industrial zones declared open rebellion. The Revolutionary War had begun.

                The anniversary is commemorated as Revolutionary Martyrs' Day.
                """,
                category: .history,
                relatedEntries: ["revolution", "fitzgerald"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "battle_stahlgrad",
                term: "The Battle of Fitzgerald City",
                shortDescription: "The bloodbath that won the war",
                fullDescription: """
                Fitzgerald City was the war's decisive battle—and its bloodiest. General Steele commanded revolutionary forces defending a city of hundreds of thousands against a colonial army determined to crush the uprising's heart.

                The fighting lasted nearly three months. Colonial artillery reduced entire neighborhoods to rubble. Revolutionary fighters held individual buildings for weeks. The steel mills became fortresses; the factory districts threw up an impenetrable defensive line. An estimated 40,000 people died—soldiers, workers, civilians caught in the crossfire.

                When colonial forces finally withdrew, Fitzgerald City was a ruin—but a ruin in revolutionary hands. The industrial heartland had fallen. General Steele became a legend.

                Raymond Carter, then a young officer, earned his reputation in the street fighting. He carries the scars still.

                "Fitzgerald City bled. Fitzgerald City held. Fitzgerald City won."
                """,
                category: .history,
                relatedEntries: ["steele", "revolution"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "gornoye_decimation",
                term: "The Highland Decimation",
                shortDescription: "The day the Revolution became total",
                fullDescription: """
                Not all turning points are victories. The Highland Decimation was a slaughter that transformed the Revolution from political uprising to total war.

                Colonial troops surrounded a workers' district in Highland where women and children had gathered while men fought on the front lines. Someone fired a shot—no one knows who. In response, the troops opened fire on the crowd.

                Three hundred and twelve people died, including forty-seven children. Among the dead: Maria Briggs, wife of Commissar Thomas Briggs, and their youngest daughter.

                Briggs organized the surviving men into fighting units that held the revolutionary districts through the winter. But something hardened in the Revolution that day. Prisoners began to be shot rather than captured. Colonial sympathizers were no longer detained but disappeared.

                The Highland Decimation proved that the enemy would show no mercy—so neither would the Revolution.
                """,
                category: .history,
                relatedEntries: ["briggs", "revolution"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "siege_stahlgrad",
                term: "The Siege of Fitzgerald City",
                shortDescription: "Ninety days that shook the world",
                fullDescription: """
                Fitzgerald City was supposed to fall quickly. The colonial army that surrounded the city outnumbered the defenders, controlled supply lines, and expected the harsh winter to break revolutionary resistance.

                They underestimated factory workers.

                The factories became fortresses. Women ran ammunition to the lines. Children served as messengers. Workers who had built machinery now built improvised armored vehicles and homemade mortars. And somewhere beyond the borders, ships bearing Soviet weapons steamed toward friendly ports.

                Chairman Fitzgerald arrived personally, smuggled through the lines. His presence electrified the defenders. With the spring thaw approaching and Soviet equipment finally arriving, Fitzgerald led the counteroffensive that shattered the siege.

                Fitzgerald City became proof that the Revolution could not be crushed by force alone.
                """,
                category: .history,
                relatedEntries: ["fitzgerald", "revolution", "soviet_union"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "fall_capital",
                term: "The Fall of the Capital",
                shortDescription: "The end and the beginning",
                fullDescription: """
                By the Revolution's final months, the colonial government controlled only a shrinking perimeter around the capital itself. The colonial governor refused to surrender, refused to negotiate, refused to acknowledge that his government had lost.

                Revolutionary forces—now called the People's Army—entered the capital. Street-by-street fighting lasted four days. The Governor's Palace, symbol of colonial rule, fell. The governor and his officials fled by ship, heading for exile.

                Fitzgerald stood on the steps of the Palace—now renamed the People's House—and proclaimed the People's Socialist Republic. Behind the cheering crowds, intelligence officer Arthur Wallace and his men secured colonial archives—files that would prove useful in the years to come.

                The Revolutionary War was over. The harder work of governing had begun.

                The anniversary is celebrated as Liberation Day, the PSR's founding holiday.
                """,
                category: .history,
                relatedEntries: ["fitzgerald", "revolution"],
                unlockedByDefault: true
            ),

            // MARK: - PURGE EVENTS

            CodexEntry(
                id: "trial_thirtysix",
                term: "The Trial of the Thirty-Six",
                shortDescription: "Show trial that decapitated the military",
                fullDescription: """
                Thirty-six senior military officers—including General Marcus Steele—were accused of conspiring with foreign powers to overthrow the PSR. The evidence was fabricated. The confessions were coerced. Thirty-five of the accused confessed; Steele refused. "History will judge," he said.

                Thirty-four were executed. Two received labor camp sentences. The military was decapitated—and would never again threaten civilian Party control.

                The Trial served multiple purposes: it eliminated popular military leaders who might challenge the Party, demonstrated that no one was safe from the Purges, and provided a narrative of constant danger from internal enemies.

                Director Wallace oversaw the interrogations personally. Carter served under Steele. The rift between the Princelings and the security services has never healed.

                "The traitors confessed their crimes. Justice was done."
                """,
                category: .history,
                relatedEntries: ["steele", "purge", "state_protection"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "intellectuals_purge",
                term: "The Intellectuals' Purge",
                shortDescription: "The cleansing of universities",
                fullDescription: """
                Universities and academies were "cleansed" of "bourgeois influences." Twelve thousand academics were arrested, fired, or exiled. The charges ranged from "idealist deviation" to "conspiracy" to simple association with the wrong colleagues.

                Dr. Helen Novak was swept up in this wave—her trial lasted twenty minutes. Her crime: treating wounded colonial prisoners with the same care as revolutionary soldiers.

                Science and education never fully recovered. An entire generation of scholars was lost. Those who remained learned to say only what was safe, to cite only approved sources, to produce research that supported Party conclusions.

                Some of the purged have since been rehabilitated. Others remain unpersons. The universities rebuilt, but the culture of fear persists. Original thought is dangerous. Conformity is survival.
                """,
                category: .history,
                relatedEntries: ["novak", "purge"],
                unlockedByDefault: true
            ),

            CodexEntry(
                id: "blackwood",
                term: "Director Samuel Blackwood",
                shortDescription: "First BPS Director (deceased) - Architect of the Purges",
                fullDescription: """
                The first Director of the Bureau of People's Security built the machinery of terror. A former police investigator under the colonial regime who switched sides early, Blackwood believed in efficiency: systematic arrests, standardized interrogation techniques, careful record-keeping.

                Under Blackwood, the BPS developed its network of informants, its interrogation protocols, its filing system that tracked millions of citizens. The Consolidation Purges were his masterwork—a comprehensive cleansing of suspected enemies.

                But eventually, the records contained too much. Blackwood knew who had denounced whom, which confessions were real and which fabricated, where the bodies were buried. He had become dangerous.

                His deputy, Arthur Wallace, orchestrated his downfall: accusations of "wrecking" and "anti-Party activities." Blackwood's own techniques were used against him. He confessed to everything and was executed.

                Wallace inherited his position—and his files.

                "The first servant of socialist justice."
                """,
                category: .history,
                relatedEntries: ["purge", "state_protection"],
                unlockedByDefault: true
            ),

            // MARK: - SECRET ENTRIES (Unlocked through gameplay)

            CodexEntry(
                id: "warren_secret",
                term: "Elizabeth 'Red Betty' Warren",
                shortDescription: "The Voice They Couldn't Silence",
                fullDescription: """
                Elizabeth Warren was the Revolution's firebrand—an orator whose voice could turn a crowd into an army. A former schoolteacher from the coastal towns, she discovered her gift during the labor struggles before the Revolution. By the time of the uprising, she was the most famous woman in the country.

                The Red Harbor General Strike was her triumph. For three weeks, the port city ceased to function. Workers controlled the streets, the docks, the warehouses. The Revolutionary Council—with Warren as its public face—became a parallel government.

                But Warren's independence made her dangerous. She criticized the early Purges. She questioned the Party's direction. She was accused of "factionalism" and "deviation."

                The official record says she was executed. But there are whispers—rumors that she was exiled rather than killed. That somewhere in the Mountain Zone, in a mining town where no one asks questions, an old woman lives under a false name.

                Her speeches circulate as samizdat—underground literature. To speak her name is dangerous. To possess her writings is a crime.

                Is she alive? Some say yes. Most say it's better not to ask.
                """,
                category: .history,
                relatedEntries: ["purge", "region_mountain"],
                unlockedByDefault: false
            ),

            CodexEntry(
                id: "fitzgerald_death",
                term: "The Fitzgerald Question",
                shortDescription: "What really happened to the Chairman?",
                fullDescription: """
                Several years after the Revolution's victory, Chairman Robert Fitzgerald collapsed at his desk. The official cause of death was a heart attack. He was in apparent good health.

                The medical records were sealed. Rumors persisted.

                Everyone who rose under Fitzgerald owes their position to him—Mitchell, Patterson, Henderson, dozens of others. And everyone who rose under Fitzgerald has reason to wonder: who betrayed him?

                Some whisper Wallace arranged the poison, eliminating a leader who might have reformed the system. Others suspect Patterson, ambitious even then, who advanced rapidly after his death. A few believe Mitchell himself—the chosen successor who inherited too conveniently.

                The truth is buried with the Chairman. But the uncertainty poisons relationships at the highest levels. If anyone could betray Fitzgerald, anyone could betray anyone.

                "The Chairman's heart gave out. The Party mourns. There is nothing more to say."
                """,
                category: .history,
                relatedEntries: ["fitzgerald", "purge"],
                unlockedByDefault: false
            ),

            // MARK: - REGIONS (Domestic Zones)

            CodexEntry(
                id: "region_capital",
                term: "Zone 1: Capital District",
                shortDescription: "The Capital - the political heart of the PSR",
                fullDescription: """
                The Capital District encompasses The Capital and its surrounding administrative zone. It is the seat of all central government institutions: the Politburo, the Council of Ministers, the Central Committee, and the Bureau of People's Security.

                The former colonial administrative buildings have been repurposed for the Revolution. The Governor's Palace became the People's House; the Colonial Assembly now houses the People's Congress. New brutalist ministry buildings have risen alongside the old monuments.

                The Capital is where careers are made and destroyed. Every ambitious official schemes to secure a posting here. To be "sent to the provinces" is understood as punishment. Yet the watchers are also watched—nowhere is surveillance more intense than in the capital itself.

                The Metro has been expanded and beautified in socialist style: palatial stations decorated with murals celebrating the Revolution. Deep underground, it also serves as a bomb shelter for the war everyone fears.
                """,
                category: .regions,
                relatedEntries: ["nova_pravda", "politburo", "general_secretary", "state_protection"]
            ),

            CodexEntry(
                id: "region_industrial",
                term: "Zone 2: Industrial Zone",
                shortDescription: "Fitzgerald City - manufacturing heartland and revolution's birthplace",
                fullDescription: """
                The Industrial Zone encompasses Fitzgerald City and the surrounding factory belt—the original stronghold of the Revolution. Its factories, steel mills, and manufacturing plants produce the goods that power the socialist economy. These cities saw the first workers' council uprisings; their workers remember when they marched on the capital.

                Millions of workers labor here in conditions transformed since the Revolution, though not always for the better. The twelve-hour shifts remain; the factory discipline is stricter than ever. Yet workers take fierce pride in their role as the vanguard of socialism. "We started this Revolution," they say, "and we'll defend it."

                Politically, the Industrial Zone is the Party's most reliable base—its workers are among the most committed Party members in the country. But reliability has limits. When conditions become unbearable, wildcat strikes erupt despite official prohibition. The Party learned early that pushing the zone too hard risks unrest that could spread nationwide.

                The region's Party boss is traditionally one of the most powerful figures in the country, commanding millions of workers and controlling the industrial output that keeps the Republic running.
                """,
                category: .regions,
                relatedEntries: ["five_year_plan", "industrial_output", "revolution"]
            ),

            CodexEntry(
                id: "region_agricultural",
                term: "Zone 3: Agricultural Zone",
                shortDescription: "The People's Proletarian Town - the breadbasket of the PSR",
                fullDescription: """
                The Agricultural Zone stretches across the fertile plains—the breadbasket of the PSR. Vast collective farms have replaced family homesteads, their combines harvesting grain that feeds millions of citizens. The transformation of agriculture into socialist production was brutal but effective.

                The independent farmer—that icon of the old ways—has been replaced by the collective farm worker, living in planned agricultural communities and meeting production quotas set in The Capital. Some adapted; others resisted and were "relocated" to less pleasant assignments.

                The collectivization campaigns left deep scars. Farmers who resisted saw their land seized, their families broken apart. The term "kulak" was applied to any farmer deemed insufficiently enthusiastic about surrendering his property. Many were sent to labor camps; many never returned.

                Today, the zone produces surplus grain that the PSR exports to allied nations. The trauma of collectivization has faded into bitter memory, but the older generation remembers. They work the collective fields and say nothing.
                """,
                category: .regions,
                relatedEntries: ["purge", "five_year_plan", "revolution"]
            ),

            CodexEntry(
                id: "region_northern",
                term: "Zone 4: Northern Zone",
                shortDescription: "Upton on Tye - harsh climate, vast resources, labor camps",
                fullDescription: """
                The Northern Zone encompasses the arctic territories—a vast region of harsh climate and valuable resources. Mining operations extract coal, iron, and precious metals. The cold keeps all but the hardiest workers away—and makes it ideal territory for labor camps.

                The zone serves as the PSR's gulag territory—political prisoners and class enemies contribute their labor to socialist construction in its mines and camps. Those sent here rarely return. The "Northern Archipelago" is a name whispered with dread.

                For those not in the camps, life is hard but offers a certain freedom from the intense surveillance found elsewhere. The vastness breeds independence of spirit that the Party tolerates as long as quotas are met. Some exiles, released but forbidden to return home, have built new lives in mining towns where no one asks too many questions.

                Assignment to the Northern Zone is usually punishment for officials. Yet control of its mineral wealth means control of strategic resources. A few ambitious administrators have transformed exile into opportunity.
                """,
                category: .regions,
                relatedEntries: ["purge", "state_protection", "industrial_output"]
            ),

            CodexEntry(
                id: "region_coastal",
                term: "Zone 5: Coastal Zone",
                shortDescription: "Red Harbor - ports and the nation's window to the world",
                fullDescription: """
                The Coastal Zone encompasses Red Harbor and the surrounding port cities—the PSR's connection to the outside world. Ships from friendly nations dock here; the fishing fleet operates from these harbors. Foreign influences seep in despite Party controls.

                The ports handle trade with socialist allies and neutral nations willing to deal with the PSR. Soviet ships bring machinery and take away raw materials. The occasional Western vessel arrives with goods that cannot be produced domestically—carefully controlled trade that benefits both sides.

                Smugglers and black marketeers find opportunities in the gaps between socialist ideology and human desire. The Bureau maintains a heavy presence, but the cosmopolitan nature of port life makes total control impossible. Here, more than anywhere, citizens glimpse the outside world.

                The Coastal Zone's Party boss must balance the demands of ideological purity with the practical necessity of foreign trade. It's a delicate position—too much openness invites accusations of "bourgeois contamination," too little and the economy suffers.
                """,
                category: .regions,
                relatedEntries: ["state_protection", "soviet_union"]
            ),

            CodexEntry(
                id: "region_mountain",
                term: "Zone 6: Mountain Zone",
                shortDescription: "Highland - mining, isolation, and internal exile",
                fullDescription: """
                The Mountain Zone encompasses the highland territories—rugged terrain sheltering isolated communities. Mining operations extract valuable minerals from the mountains; the remoteness makes this zone ideal for "internal exile."

                Internal exiles are those who have served their sentences in labor camps but cannot return to normal society. They are sent here, to remote towns where they can work and live under less intense—but still present—surveillance. Some build new lives; others waste away in obscurity.

                The mountain communities have preserved traditions that predate the Revolution. Far from the capital, far from the factories, life continues in patterns the Party has never fully penetrated. The Bureau monitors, but its reach is limited by geography and resources.

                For officials, the Mountain Zone represents either punishment or opportunity. Some are sent here as exile; others volunteer, seeking to build power bases far from the capital's intrigues.
                """,
                category: .regions,
                relatedEntries: ["purge", "warren_secret"]
            ),

            CodexEntry(
                id: "region_border",
                term: "Zone 7: Border Zone",
                shortDescription: "The Frontier - frontier territories and careful watching",
                fullDescription: """
                The Border Zone encompasses the frontier territories—where the PSR meets the outside world. Border crossings, customs stations, and military fortifications mark the line between socialist territory and whatever lies beyond.

                The population here has ties to neighboring countries—shared languages, shared customs, family connections that cross the frontier. The Party views such connections with deep suspicion. The Bureau maintains its heaviest presence here, watching for spies, smugglers, and those who might flee.

                Trade routes pass through the Border Zone—both legal commerce and smuggling that no amount of surveillance can fully suppress. Information flows both ways; news of the outside world reaches citizens here before anywhere else.

                For the ambitious, the Border Zone offers opportunities in trade and intelligence. For the unfortunate, it represents the edge of the world—the last posting before exile or worse. Everyone watches everyone else, and everyone is watched from above.
                """,
                category: .regions,
                relatedEntries: ["state_protection"]
            ),

            // MARK: - WORLD ATLAS (Foreign Nations)

            // SOCIALIST ALLIES

            CodexEntry(
                id: "soviet_union",
                term: "Soviet Union",
                shortDescription: "Revolutionary ally - the world's first socialist state",
                fullDescription: """
                The Union of Soviet Socialist Republics is the world's first socialist state and our revolutionary ally. When the Revolutionary War began, Moscow saw an opportunity to spread world revolution—and seized it.

                Geography: Spanning Eurasia from Eastern Europe to the Pacific. The largest country on Earth, with vast resources and harsh climate.

                Population: 200 million people organized under Communist Party rule. Their industrial capacity is immense; their military might deters our enemies.

                Government: Communist state under the Communist Party of the Soviet Union. Stalin's death has brought uncertainty; his successors maneuver for power.

                Relations: Complicated gratitude. They saved our Revolution with weapons, advisors, and supplies. Moscow expects ideological conformity; we increasingly chafe at being treated as a junior partner. We are allies, not satellites—but the distinction grows finer each year.

                "The Soviet Union is the motherland of world socialism. We honor our debt—but we are not children."
                """,
                category: .worldAtlas,
                relatedEntries: ["revolution", "peoples_army"]
            ),

            CodexEntry(
                id: "china",
                term: "People's Republic of China",
                shortDescription: "Fellow revolutionary state - Mao's new China",
                fullDescription: """
                The People's Republic of China emerged from revolution in 1949, just as we did decades earlier. Mao Zedong's victory created another socialist ally—and another model for revolutionary development.

                Geography: East Asia. Vast territory, enormous population, sharing a long border with the Soviet Union.

                Population: 550 million Chinese—the largest nation on Earth—now organized under Communist Party rule. Their revolutionary experience differs from ours but echoes familiar themes.

                Government: Communist state under the Communist Party of China. Chairman Mao pursues his own path to socialism, sometimes diverging from Soviet orthodoxy.

                Relations: Fraternal solidarity with complications. Both we and China owe much to Soviet aid, yet both seek independent paths. Beijing watches our relationship with Moscow closely; we watch theirs.

                "The Chinese Revolution proves that the old order can fall anywhere. Today China, tomorrow the world."
                """,
                category: .worldAtlas,
                relatedEntries: ["soviet_union", "revolution"]
            ),

            CodexEntry(
                id: "eastern_bloc",
                term: "Eastern Bloc",
                shortDescription: "Soviet satellites in Eastern Europe",
                fullDescription: """
                The Eastern Bloc comprises the socialist states of Eastern Europe: Poland, Czechoslovakia, Hungary, Romania, Bulgaria, and East Germany. These nations fell under Soviet influence after World War II and now follow Moscow's lead.

                Geography: Central and Eastern Europe. A buffer zone between the Soviet Union and the capitalist West.

                Population: Combined, over 100 million people living under communist rule of varying intensity.

                Government: Communist states with limited independence. Local Party leaders rule, but Moscow's word is final on matters of importance.

                Relations: We maintain diplomatic ties and trade agreements with all Eastern Bloc nations. Their status as Soviet satellites serves as both example and warning—proof of socialist success, but also of the price of dependence.

                "Fraternal socialist republics—though some brothers have more freedom than others."
                """,
                category: .worldAtlas,
                relatedEntries: ["soviet_union"]
            ),

            // CAPITALIST ADVERSARIES

            CodexEntry(
                id: "united_states",
                term: "United States of America",
                shortDescription: "Global capitalist superpower - our ideological enemy",
                fullDescription: """
                The United States of America is the world's dominant capitalist power. Washington leads the Western bloc against socialism worldwide, viewing any revolutionary state as a threat to be contained or destroyed.

                Geography: North America. Vast territory, abundant resources, protected by two oceans.

                Population: 150 million Americans living under capitalist democracy. Their industrial capacity rivals the Soviet Union's; their military reach spans the globe.

                Government: Capitalist democracy under President Eisenhower. The American system combines electoral politics with corporate power in ways our theorists find contemptible.

                Relations: No formal relations exist. Washington refuses to recognize the PSR, viewing us as a Soviet proxy. American economic pressure limits our access to Western markets and technology. CIA operations probe constantly for weakness.

                "The American empire reaches everywhere. Everywhere, that is, except where socialism has triumphed."
                """,
                category: .worldAtlas,
                relatedEntries: ["soviet_union", "united_kingdom"]
            ),

            CodexEntry(
                id: "united_kingdom",
                term: "United Kingdom",
                shortDescription: "Declining empire - follows Washington's lead",
                fullDescription: """
                The United Kingdom of Great Britain and Northern Ireland clings to the remnants of its empire while following American leadership in the Cold War. British power has declined since World War II, but London remains influential.

                Geography: Island nation off Western Europe, with colonial holdings scattered across Africa, Asia, and the Caribbean.

                Population: 50 million Britons, plus colonial subjects numbering in the hundreds of millions. The sun still sets reluctantly on British dominion.

                Government: Constitutional Monarchy with Parliament. Prime Minister Eden maintains firm anti-socialist policies while managing imperial decline.

                Relations: Britain follows Washington's lead on non-recognition but maintains more flexibility than its American ally. British intelligence services are skilled and persistent enemies.

                "The British lion grows old, but still has claws."
                """,
                category: .worldAtlas,
                relatedEntries: ["united_states", "france"]
            ),

            CodexEntry(
                id: "france",
                term: "France",
                shortDescription: "Unstable republic - swings between left and right",
                fullDescription: """
                The French Republic is the most unpredictable power in Europe. French politics swing wildly between left and right, between accommodation with socialism and fierce anti-communism. Today's enemy might be tomorrow's friend.

                Geography: Western Europe. Industrial north, agricultural south, colonial possessions in Africa and Asia.

                Population: 42 million French citizens, plus colonial subjects. A large Communist Party provides both opportunity and concern.

                Government: Unstable parliamentary republic. Governments rise and fall with dizzying speed as parties fragment and reform.

                Relations: Complicated. Official relations are strained but not frozen. French intellectuals debate our system endlessly; French communists look to us for inspiration.

                "If France goes socialist, the capitalist bloc fractures. If France goes fascist, we face another enemy. French politics bear constant watching."
                """,
                category: .worldAtlas,
                relatedEntries: ["united_kingdom", "eastern_bloc"]
            ),

            CodexEntry(
                id: "west_germany",
                term: "West Germany",
                shortDescription: "Bundesrepublik - firmly in the Western camp",
                fullDescription: """
                The Federal Republic of Germany (West Germany) emerged from the ashes of Nazi defeat, rebuilt under American occupation and now firmly aligned with the Western bloc.

                Geography: Central Europe. Industrial heartland divided from its socialist counterpart in the East.

                Population: 50 million Germans living under a capitalist democracy. German engineering and manufacturing remain legendary.

                Government: Parliamentary democracy under Chancellor Adenauer. The Bundesrepublik has renounced its Nazi past and embraced Western integration.

                Relations: No formal relations. West Germany follows the American line on non-recognition. German industrial expertise would be valuable; German politics make cooperation impossible.

                "Germany divided is Germany weakened. We prefer it that way."
                """,
                category: .worldAtlas,
                relatedEntries: ["eastern_bloc", "united_states"]
            ),

            // NON-ALIGNED

            CodexEntry(
                id: "yugoslavia",
                term: "Yugoslavia",
                shortDescription: "Socialist but independent - Tito's third way",
                fullDescription: """
                The Socialist Federal Republic of Yugoslavia proves that socialism need not mean Soviet domination. Marshal Tito broke with Stalin in 1948 and has charted an independent course ever since.

                Geography: Southeastern Europe. A federation of diverse nations held together by Tito's personality and the Party's power.

                Population: 17 million Yugoslavs of various ethnicities—Serbs, Croats, Slovenes, and others—united under socialist rule.

                Government: Socialist state under the League of Communists, led by President Tito. Yugoslavia maintains a "third way" between Soviet orthodoxy and Western capitalism.

                Relations: We study Yugoslavia's model with great interest. Tito proves that a socialist state can maintain independence from Moscow. Our Reformists cite his example; our conservatives view it with suspicion.

                "Yugoslavia shows another path. Whether we can follow it remains to be seen."
                """,
                category: .worldAtlas,
                relatedEntries: ["soviet_union", "reformists"]
            ),

            CodexEntry(
                id: "india",
                term: "India",
                shortDescription: "Non-aligned giant - Nehru's neutral path",
                fullDescription: """
                The Republic of India gained independence from Britain in 1947 and has chosen neutrality in the Cold War. Nehru's India maintains friendly relations with both East and West, refusing to join either bloc.

                Geography: South Asia. Vast subcontinent with enormous population and ancient civilizations.

                Population: 360 million Indians—the world's largest democracy—living under a parliamentary system that blends socialist economics with democratic politics.

                Government: Parliamentary democracy under Prime Minister Nehru. India pursues a "non-aligned" foreign policy, seeking to lead the developing world between the superpowers.

                Relations: We seek Indian recognition and trade. Nehru's neutrality frustrates both Washington and Moscow, which we find useful. India proves that the Cold War need not consume everyone.

                "India charts its own course. We respect that—and hope to benefit from it."
                """,
                category: .worldAtlas,
                relatedEntries: ["egypt"]
            ),

            CodexEntry(
                id: "egypt",
                term: "Egypt",
                shortDescription: "Revolutionary potential - watching Cairo closely",
                fullDescription: """
                The Kingdom of Egypt stands on the brink of transformation. The corrupt monarchy of King Farouk teeters; military officers plot; the masses grow restless. Revolution may come to Cairo.

                Geography: Northeast Africa and Sinai. The Suez Canal makes Egypt strategically vital to global trade.

                Population: 21 million Egyptians living under an increasingly unstable monarchy. British influence persists despite nominal independence.

                Government: Constitutional monarchy under King Farouk—for now. Military officers have organized the Free Officers Movement; change is coming.

                Relations: We watch Egyptian developments with keen interest. A revolutionary Egypt would shake the entire Middle East. Colonel Nasser and his fellow officers may provide the spark.

                "Egypt could go many directions. We hope to be friends with whoever emerges."
                """,
                category: .worldAtlas,
                relatedEntries: ["india", "united_kingdom"]
            ),

            CodexEntry(
                id: "japan",
                term: "Japan",
                shortDescription: "Defeated empire - now American ally",
                fullDescription: """
                The Empire of Japan was crushed in World War II and rebuilt under American occupation. Today, Japan is firmly in the Western camp, its militarism replaced by economic ambition.

                Geography: Island nation in the Western Pacific. Former empire now confined to the home islands.

                Population: 85 million Japanese living under a constitutional democracy with American military bases on their soil.

                Government: Constitutional monarchy with parliamentary democracy. The Emperor reigns symbolically; elected politicians govern under American supervision.

                Relations: No formal relations. Japan follows American policy on recognition. Japanese goods are of high quality but unavailable to us due to Western embargo.

                "The samurai have become shopkeepers. American shopkeepers."
                """,
                category: .worldAtlas,
                relatedEntries: ["united_states"]
            ),

            CodexEntry(
                id: "mexico",
                term: "Mexico",
                shortDescription: "Southern neighbor - helpful but not allied",
                fullDescription: """
                The United Mexican States walks a careful line between the Cold War blocs. Mexico is neither socialist nor fully capitalist—a one-party state that mouths revolutionary rhetoric while maintaining capitalist structures.

                Geography: Shares our southern border. Long frontier, shared history, strategic position.

                Population: 28 million Mexicans. Their own revolution, decades past, created a unique system that has made peace with capitalism.

                Government: One-party rule under the PRI (Institutional Revolutionary Party). Mexican presidents focus on development, not ideology.

                Relations: Helpful neighbors who refuse to become allies. They have aided us when useful—supplies and diplomatic cover flow through Mexican ports—but Mexico will not join our bloc. We share a long border and must maintain working relations.

                "Mexico remembers its own revolution. They understand us, even if they won't join us."
                """,
                category: .worldAtlas,
                relatedEntries: ["revolution"]
            )
        ]

        for entry in defaultEntries {
            entries[entry.id] = entry
        }
    }
}
