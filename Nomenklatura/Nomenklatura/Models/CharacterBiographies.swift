//
//  CharacterBiographies.swift
//  Nomenklatura
//
//  Deep biographical data for major characters
//  Contains extended histories, family connections, and discoverable secrets
//

import Foundation

// MARK: - Biography Data Structures

/// Extended biography for a character with deep narrative content
struct CharacterBiography: Codable, Identifiable {
    var id: String // matches character id
    var fullName: String
    var aliases: [String] // other names they've used
    var ageCategory: String // "elderly", "middle-aged", "young", "very young"
    var birthPlace: String
    var isDeceased: Bool // if deceased
    var education: [EducationEntry]
    var careerTimeline: [BiographyCareerEvent]
    var familyTree: FamilyTree
    var personalTraits: PersonalTraits
    var revolutionaryHistory: RevolutionaryHistory
    var darkSecrets: [DarkSecret] // deeper than CharacterSecret
    var quotations: [CharacterQuote] // things they've said
    var physicalDescription: String
    var psychologicalProfile: String
}

struct EducationEntry: Codable {
    var institution: String
    var years: String
    var degree: String?
    var notes: String
}

struct BiographyCareerEvent: Codable {
    var era: String // "before the Revolution", "during the Revolution", "after the Revolution", etc.
    var position: String
    var location: String
    var significance: String
}

struct FamilyTree: Codable {
    var father: FamilyMember?
    var mother: FamilyMember?
    var spouse: FamilyMember?
    var children: [FamilyMember]
    var siblings: [FamilyMember]
    var extendedFamily: [FamilyMember] // significant relatives
}

struct FamilyMember: Codable {
    var name: String
    var relation: String
    var status: String // alive, deceased, unknown
    var occupation: String?
    var notes: String
    var isSecret: Bool // hidden from player initially
}

struct PersonalTraits: Codable {
    var vices: [String]
    var virtues: [String]
    var fears: [String]
    var desires: [String]
    var habits: [String]
    var beliefs: [String]
}

struct RevolutionaryHistory: Codable {
    var joinedMovement: String // "before the Revolution", "during the Revolution", etc.
    var recruitedBy: String?
    var civilWarRole: String
    var purgeExperience: String
    var keyMoments: [HistoricalMoment]
}

struct HistoricalMoment: Codable {
    var era: String // "before the Revolution", "during the Revolution", "during the Purges", etc.
    var event: String
    var impact: String
    var witnesses: [String] // character ids who know about this
}

struct DarkSecret: Codable, Identifiable {
    var id: String
    var title: String
    var fullContent: String // longer than CharacterSecret
    var discoveryDifficulty: Int // 1-10
    var evidenceLocations: [String] // where proof can be found
    var potentialConsequences: String
    var whoKnows: [String] // character ids
    var canBeUsedFor: [String] // blackmail, alliance, exposure, etc.
}

struct CharacterQuote: Codable {
    var quote: String
    var context: String
    var era: String? // "before the Revolution", "during the Purges", etc.
    var isPublic: Bool
}

// MARK: - Biography Provider

class CharacterBiographyProvider {
    static let shared = CharacterBiographyProvider()

    private var biographies: [String: CharacterBiography] = [:]

    private init() {
        loadBiographies()
    }

    func getBiography(for characterId: String) -> CharacterBiography? {
        return biographies[characterId]
    }

    private func loadBiographies() {
        // Load all deep biographies
        // NOTE: IDs must match templateIds in CampaignConfig.swift

        // Top Leadership
        biographies["brenner"] = createMitchellBiography()      // Harold Mitchell (General Secretary)
        biographies["ozols"] = createCarterBiography()          // General Raymond Carter

        // Security Services Track
        biographies["wallace"] = createWallaceBiography()
        biographies["edwards"] = createEdwardsBiography()
        biographies["strickland"] = createStricklandBiography()
        biographies["reynolds"] = createReynoldsBiography()

        // Party Apparatus Track
        biographies["morozova"] = createPattersonBiography()    // Eleanor Patterson
        biographies["kadaris"] = createHendersonBiography()     // Comrade Henderson
        biographies["steinmetz"] = createHoffmanBiography()     // Walter Hoffman
        biographies["polzin"] = createRawlingsBiography()       // Victor Rawlings
        biographies["kirillova"] = createDonovanBiography()     // Clara Donovan

        // State Ministry Track
        biographies["crawford"] = createCrawfordBiography()
        biographies["mason"] = createMasonBiography()
        biographies["sullivan_i"] = createSullivanBiography()
        biographies["collins"] = createCollinsBiography()

        // Economic Planning Track
        biographies["kowalski"] = createKowalskiBiography()
        biographies["carpenter"] = createCarpenterBiography()
        biographies["erickson"] = createEricksonBiography()

        // Military-Political Track
        biographies["fletcher"] = createFletcherBiography()
        biographies["spencer"] = createSpencerBiography()
        biographies["bodine"] = createBodineBiography()
        biographies["thompson"] = createThompsonBiography()
    }

    // MARK: - Harold Mitchell Biography

    private func createMitchellBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "brenner",
            fullName: "Harold James Mitchell",
            aliases: ["Comrade Secretary", "The Gray Man"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Left school at 14 to work in the factories"
                ),
                EducationEntry(
                    institution: "Workers' Night School",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Self-educated in Marxist theory and economics"
                ),
                EducationEntry(
                    institution: "International Lenin School, Moscow",
                    years: "pre-Revolution",
                    degree: "Certificate in Revolutionary Leadership",
                    notes: "One year training with the Comintern; met future Soviet leaders"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Factory Worker", location: "Fitzgerald City", significance: "First exposure to labor organizing"),
                BiographyCareerEvent(era: "during the Depression", position: "Union Shop Steward", location: "Fitzgerald City", significance: "Began organizing activities"),
                BiographyCareerEvent(era: "during the Depression", position: "Youth League Organizer", location: "Zone 2", significance: "Rose to prominence under Fitzgerald's patronage"),
                BiographyCareerEvent(era: "during the Revolution", position: "Revolutionary Militia Commander", location: "Fitzgerald City", significance: "Led workers' militia during March on the Capital"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissar of Labor", location: "The Capital", significance: "First government position after Revolution"),
                BiographyCareerEvent(era: "during the Purges", position: "Commissar of Heavy Industry", location: "The Capital", significance: "Oversaw wartime production"),
                BiographyCareerEvent(era: "years later", position: "General Secretary", location: "The Capital", significance: "Succeeded Fitzgerald under mysterious circumstances")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "James Mitchell Sr.",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Factory Foreman",
                    notes: "Died of tuberculosis. Union man who taught Harold the importance of solidarity.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Mary Mitchell (née O'Brien)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Seamstress",
                    notes: "Immigrant worker. Died during the Civil War, caught in crossfire in Fitzgerald City.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Eleanor Mitchell (née Kowalski)",
                    relation: "Wife",
                    status: "Deceased",
                    occupation: "Party Organizer",
                    notes: "Committed suicide after learning Harold had signed death warrants for her cousins during the Purges. Official cause: 'illness.'",
                    isSecret: true
                ),
                children: [
                    FamilyMember(
                        name: "James Harold Mitchell Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Army Officer (Captain)",
                        notes: "Estranged from father. Suspects truth about mother's death.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Thomas Mitchell",
                        relation: "Brother",
                        status: "Deceased",
                        occupation: "Steel Worker",
                        notes: "Killed at the Battle of Fitzgerald City. A genuine martyr.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Insomnia", "Whiskey (private)", "Paranoid vigilance"],
                virtues: ["Tireless work ethic", "Genuine care for workers", "Strategic patience"],
                fears: ["Exposure of wife's suicide", "Being seen as weak", "Fitzgerald's ghost"],
                desires: ["Historical vindication", "Son's reconciliation", "Peaceful death in bed"],
                habits: ["Reads reports until 2am", "Takes long walks alone", "Writes letters he never sends"],
                beliefs: ["Socialism was worth the cost", "The ends justify the means", "He had no choice"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Chairman Robert Fitzgerald",
                civilWarRole: "Fitzgerald City Workers' Militia Commander; secured the city during the March on the Capital",
                purgeExperience: "Signed death warrants for 47 people, including wife's cousins. Protected by Fitzgerald until Fitzgerald died.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The March on the Capital",
                        impact: "Led the Fitzgerald City column. Fitzgerald trusted him with the rear guard.",
                        witnesses: ["ozols", "wallace", "kadaris"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Kowalski Warrants",
                        impact: "Signed death warrants for the Kowalski cousins (his wife's family) to prove loyalty during the Purges.",
                        witnesses: ["wallace"]
                    ),
                    HistoricalMoment(
                        era: "years later",
                        event: "Fitzgerald's Death",
                        impact: "Was with Fitzgerald the night he died. Official story: heart attack. Some whisper poison.",
                        witnesses: ["wallace"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "mitchell_wife_suicide",
                    title: "Eleanor's Suicide",
                    fullContent: "Eleanor Mitchell did not die of 'illness' during the Purges. She hanged herself in their apartment after discovering that Harold had personally signed the death warrants for her cousins, the Kowalski family members accused in the Zone 3 Conspiracy. She left a note that Wallace confiscated. The note is in Wallace's private files. Harold found her body. He has never forgiven himself, but he has never stopped signing warrants either.",
                    discoveryDifficulty: 8,
                    evidenceLocations: ["Wallace's private vault", "Dr. Petrov's medical records (sealed)", "The apartment building superintendent's memory"],
                    potentialConsequences: "If exposed, would shatter Mitchell's image as the 'Gray Man' who does what's necessary without emotion. His son would have confirmation of his suspicions. Political rivals could use it to paint him as unstable.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["blackmail", "alliance (if approached sympathetically)", "exposure"]
                ),
                DarkSecret(
                    id: "mitchell_fitzgerald",
                    title: "The Night Fitzgerald Died",
                    fullContent: "Mitchell was with Fitzgerald the night of the night Fitzgerald died. They were alone in Fitzgerald's study, drinking whiskey, discussing the future. Fitzgerald was ill—genuinely ill—but not dying. He was planning reforms that would have weakened the security apparatus. Wallace had asked Mitchell to 'make sure the Chairman gets his medicine.' Mitchell gave him the pills. Fitzgerald never woke up. Mitchell tells himself it was mercy. He knows it was murder.",
                    discoveryDifficulty: 10,
                    evidenceLocations: ["Wallace's memory", "The pharmacist who filled the prescription (deceased)", "Mitchell's own conscience"],
                    potentialConsequences: "Absolute destruction. The murder of the Revolution's father would delegitimize the entire current government. Mitchell would be executed. Wallace would fall with him.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["blackmail (if discovered)", "leverage over Wallace (mutual destruction)"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The Revolution asked everything of us. We gave it. Some of us are still paying.",
                    context: "Private conversation with Wallace, years after the Purges",
                    era: "present day",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "History will judge us by what we built, not by what we destroyed to build it.",
                    context: "Address to the Party Congress",
                    era: "in recent years",
                    isPublic: true
                ),
                CharacterQuote(
                    quote: "Eleanor understood. At the end, she understood everything. That's why she couldn't live with it.",
                    context: "Whispered to himself, drunk, alone",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Tall and gaunt, with gray hair that was once black. Deep-set eyes that have seen too much. Moves slowly, deliberately—conserving energy for the work. Wears plain gray suits. Hands are surprisingly rough—he still remembers the factory floor. A face that might have been handsome once, now carved by exhaustion and grief into something more severe.",
            psychologicalProfile: "Mitchell is a man divided against himself. He genuinely believes in the Revolution and its goals—workers' liberation, equality, the end of exploitation. He also knows the terrible price that has been paid, and he has paid more of it than most. His wife's suicide haunts him, but he has not changed his methods because he cannot admit they were wrong. He works twenty-hour days partly from dedication, partly from fear of being alone with his thoughts. He trusts Wallace because they are bound by shared guilt. He fears his son because James represents the judgment he deserves. He leads the Republic because no one else can, and because stopping would mean facing what he has become."
        )
    }

    // MARK: - Director Wallace Biography

    private func createWallaceBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "wallace",
            fullName: "Samuel Aaron Wallace",
            aliases: ["Director", "The Old Man", "The Shadow"],
            ageCategory: "elderly",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Harbor District Public School, Red Harbor",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Immigrant education. Learned the national language as second language."
                ),
                EducationEntry(
                    institution: "Red Harbor City College",
                    years: "pre-Revolution",
                    degree: "Incomplete (left for the war)",
                    notes: "Studied law. Too poor to continue after father's death."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Factory Worker", location: "Red Harbor", significance: "Radicalized by working conditions"),
                BiographyCareerEvent(era: "during the Depression", position: "Communist Party Organizer", location: "Red Harbor", significance: "Joined the underground movement"),
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Intelligence", location: "Nationwide", significance: "Built the first revolutionary spy networks"),
                BiographyCareerEvent(era: "during the Revolution", position: "Security Chief, Revolutionary Forces", location: "Mobile", significance: "Ran counter-intelligence during Civil War"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Director, Bureau of People's Security", location: "The Capital", significance: "Second to Blackwood"),
                BiographyCareerEvent(era: "during the Purges", position: "Director, Bureau of People's Security", location: "The Capital", significance: "Succeeded Blackwood (whom he destroyed)")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Aaron Wallace (né Walinsky)",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Tailor",
                    notes: "Immigrant from Eastern Europe. Died of influenza. Changed family name to Wallace for assimilation.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Rebecca Wallace (née Goldstein)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Seamstress",
                    notes: "Died in a tenement fire during the Revolution. Wallace was too busy to attend the funeral.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Sarah Wallace (née Bernstein)",
                    relation: "Wife",
                    status: "Deceased",
                    occupation: "Teacher",
                    notes: "Died of cancer. The only person Wallace ever truly loved. He visits her grave weekly.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "David Wallace",
                        relation: "Son",
                        status: "Deceased",
                        occupation: "Soldier",
                        notes: "Killed in the Border War, fighting foreign forces in Zone 7. His death broke something in Wallace.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Ruth Abramson (née Wallace)",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "School Administrator",
                        notes: "Lives in Zone 2. They exchange letters on holidays. She is the only family he has left.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Chess (obsessive)", "Collecting secrets", "Inability to trust"],
                virtues: ["Absolute loyalty to chosen causes", "Never forgets a kindness", "Protects his people"],
                fears: ["Dying alone", "Being forgotten", "Making the same mistakes as Blackwood"],
                desires: ["A worthy successor", "Vindication of his methods", "To see his son's grave one more time"],
                habits: ["Keeps files on everyone", "Speaks softly", "Never raises his voice—he doesn't need to", "Visits his wife's grave on Sundays"],
                beliefs: ["Trust no one completely", "The state must be protected from its enemies", "The ends justify the means—but only if you win"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Underground party organizers",
                civilWarRole: "Built and ran the revolutionary intelligence apparatus. Identified and neutralized government infiltrators. Saved the Revolution through information warfare.",
                purgeExperience: "Ran the Purges under Blackwood, then destroyed Blackwood and took his place. Has personally overseen thousands of interrogations. Has never tortured anyone himself—he has people for that.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Blackwood Files",
                        impact: "Discovered Blackwood was fabricating evidence. Kept the information until useful.",
                        witnesses: ["edwards"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Fall of Blackwood",
                        impact: "Exposed Blackwood's fabrications (selectively). Took his position. Inherited his files.",
                        witnesses: ["brenner", "edwards"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Steele Interrogation",
                        impact: "Personally oversaw the interrogation of General Steele. Never broke him. Signed the death warrant anyway.",
                        witnesses: ["edwards", "ozols"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "wallace_blackwood_murder",
                    title: "Blackwood's End",
                    fullContent: "Director Samuel Blackwood did not die in an 'accident' during the Purges. Wallace arranged his death to look like a car crash. Blackwood knew too much and was becoming erratic—he might have exposed the fabricated nature of many Purge trials. Wallace removed him surgically. He inherited Blackwood's files, his methods, and his guilt. He tells himself he was better than Blackwood. He hopes it's true.",
                    discoveryDifficulty: 9,
                    evidenceLocations: ["The mechanic who 'serviced' Blackwood's car (deceased)", "Wallace's private journals (if they exist)", "Blackwood's hidden papers (location unknown)"],
                    potentialConsequences: "Would prove the security apparatus has been run by murderers and liars from the beginning. Would delegitimize the entire Purge apparatus.",
                    whoKnows: [],
                    canBeUsedFor: ["blackmail", "exposure"]
                ),
                DarkSecret(
                    id: "wallace_son_sacrifice",
                    title: "David's Assignment",
                    fullContent: "Wallace's son David was assigned to a suicide mission in Zone 7—an assault on a fortified position that command knew was hopeless. Wallace could have intervened. He had the power. He chose not to, because pulling his son from danger would have looked like favoritism. David died, and Wallace has never forgiven himself. He keeps his son's last letter in his desk drawer.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Military records (classified)", "David's letters (in Wallace's possession)", "The surviving members of David's unit"],
                    potentialConsequences: "Humanizing. Would make Wallace vulnerable if used against him. Could also create sympathy if revealed carefully.",
                    whoKnows: [],
                    canBeUsedFor: ["leverage", "building alliance through shared grief"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "I know where the bodies are buried, Comrade. I buried most of them myself.",
                    context: "To a rival who threatened exposure, after the Purges",
                    era: "after the Purges",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "The Revolution requires clean hands and dirty work. I do the dirty work so others can keep their hands clean.",
                    context: "To a young officer questioning methods",
                    era: "years later",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "My son died believing in something. That's more than most people get.",
                    context: "To himself, at David's grave, annually",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Small and unremarkable—deliberately so. Gray hair, gray suit, gray demeanor. Spectacles that he peers over when making a point. Moves quietly; appears in rooms without warning. Hands that never shake. Eyes that miss nothing. The kind of man you wouldn't look at twice, which is exactly how he wants it.",
            psychologicalProfile: "Wallace is the most dangerous man in the Republic, and he knows it. He has survived longer than anyone in the security apparatus because he understands the system perfectly. He believes absolutely in the necessity of his work—the Revolution has enemies, and someone must protect it. He also believes he is damned for what he has done. He lost his son to the cause and his soul to the methods. He is looking for a successor who can do the job without becoming what he has become. Edwards is the obvious choice, but Wallace isn't sure Edwards can carry the weight. He maintains Mitchell in power because Mitchell is useful and because they are bound by shared guilt. He keeps files on everyone because knowledge is power and trust is weakness. He is not evil—he genuinely believes in what he does—but he is not good either. He is necessary, and he hates himself for it."
        )
    }

    // MARK: - General Carter Biography

    private func createCarterBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "ozols",
            fullName: "Raymond Elijah Carter",
            aliases: ["The General", "Old Ray", "The Lion of Fitzgerald City"],
            ageCategory: "middle-aged",
            birthPlace: "Zone 3, Agricultural Region",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Rural Public Schools, Zone 3",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Education ended at 14. Limited opportunities in the agricultural region."
                ),
                EducationEntry(
                    institution: "Army Correspondence Courses",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Self-educated in military history and tactics while fighting"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Farm Laborer", location: "Zone 3", significance: "Worked the fields until he was 18"),
                BiographyCareerEvent(era: "during the Depression", position: "Railroad Worker", location: "Fitzgerald City", significance: "Migrated to the industrial zone. Joined the Brotherhood."),
                BiographyCareerEvent(era: "during the Depression", position: "Labor Organizer", location: "Fitzgerald City", significance: "Organized workers despite threats"),
                BiographyCareerEvent(era: "during the Revolution", position: "Militia Commander", location: "Fitzgerald City", significance: "Led workers' militia in the Battle of Fitzgerald City"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "General, People's Army", location: "Various", significance: "Commander of the 3rd Revolutionary Corps"),
                BiographyCareerEvent(era: "after the Purges", position: "Deputy Commander, Armed Forces", location: "The Capital", significance: "Second-highest military position"),
                BiographyCareerEvent(era: "present day", position: "Deputy General Secretary", location: "The Capital", significance: "Moved into civilian leadership")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Elijah Carter",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Farm Laborer",
                    notes: "Killed by a mob for 'disrespecting' a landlord. Raymond was sixteen.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Ruth Carter (née Jackson)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Domestic Worker",
                    notes: "Died of exhaustion and heartbreak after years of poverty. Raymond carries her photograph.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Elizabeth Carter (née Briggs)",
                    relation: "Wife",
                    status: "Deceased",
                    occupation: "Teacher",
                    notes: "Married into the Briggs family—Commissar Briggs's niece. Died of pneumonia. A genuine love match despite the political advantages.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Marcus Carter",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Army Colonel",
                        notes: "Following in his father's footsteps. Raymond is proud and terrified for him.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Ruth Carter",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Doctor",
                        notes: "Named after Raymond's mother. Works in Zone 2. Rarely visits.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "James Carter",
                        relation: "Brother",
                        status: "Deceased",
                        occupation: "Worker",
                        notes: "Killed at the Battle of Fitzgerald City. Raymond held him as he died.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Bourbon (carefully hidden)", "Rage (suppressed)", "Pride"],
                virtues: ["Loyalty to his troops", "Physical courage", "Honesty (unusual in leadership)"],
                fears: ["Failing his soldiers again", "His son dying in war", "Being remembered as a politician rather than a soldier"],
                desires: ["Peace (genuine)", "His son's safety", "To stop fighting someday"],
                habits: ["Rises at 5am", "Exercises despite age", "Writes letters to his dead wife"],
                beliefs: ["The Revolution liberated the workers", "Violence is sometimes necessary", "He has killed enough"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Industrial union organizers",
                civilWarRole: "Commander, Workers' Militia. Led the defense of Fitzgerald City for 90 days. Won the battle that broke the old regime's forces in the industrial heartland.",
                purgeExperience: "Testified at the Trial of the Thirty-Six—against General Steele, his former commander. He has never forgiven himself.",
                keyMoments: [
                    HistoricalMoment(
                        era: "before the Revolution",
                        event: "Father's Murder",
                        impact: "Made Raymond a revolutionary. He swore the system would pay.",
                        witnesses: []
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Battle of Fitzgerald City",
                        impact: "90 days of street-to-street fighting. Lost his brother. Won the industrial zone. Became a legend.",
                        witnesses: ["fletcher", "thompson", "bodine"]
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Retreat at Highland",
                        impact: "Ordered retreating soldiers shot to prevent a rout. Saved the battle. Killed his own men.",
                        witnesses: ["fletcher"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Steele Trial",
                        impact: "Testified against Steele—his commander, his mentor. The guilt has never faded.",
                        witnesses: ["wallace", "fletcher", "brenner"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "carter_shooting_retreat",
                    title: "The Highland Decimation",
                    fullContent: "During the Battle of Highland, Carter's forces were retreating in disorder. Enemy troops were pursuing. To stop the rout, Carter ordered his officers to shoot any man who ran. Seventeen soldiers died by their own side's bullets. The line held. The battle was won. Carter has never admitted this in public. The soldiers who witnessed it are mostly dead. Fletcher knows. They never speak of it.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Fletcher's memory", "Survivors from the Highland campaign", "Carter's unpublished memoirs (if they exist)"],
                    potentialConsequences: "Would complicate Carter's image as a beloved military leader. Some would understand; others would call it murder.",
                    whoKnows: ["fletcher"],
                    canBeUsedFor: ["blackmail", "leverage"]
                ),
                DarkSecret(
                    id: "carter_steele_guilt",
                    title: "The Testimony",
                    fullContent: "Carter testified against General Steele at the Trial of the Thirty-Six. He told partial truths—Steele had been critical of Party leadership, had questioned orders—and let the prosecutors fill in the fabrications. He was afraid of being purged himself. Steele was executed. Carter received a promotion. He keeps Steele's last letter—smuggled out of prison—in a locked box. It says: 'I forgive you. You had no choice. But we both know you did.'",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["The letter in Carter's possession", "Trial transcripts (classified)", "Wallace's files on the Trial"],
                    potentialConsequences: "Would reveal Carter as complicit in the Purges' injustice. Would connect him to Fletcher's similar guilt.",
                    whoKnows: ["wallace", "fletcher"],
                    canBeUsedFor: ["blackmail", "alliance through shared guilt", "exposure"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "I've killed enough men to know it doesn't get easier. It shouldn't.",
                    context: "To a young officer asking about combat",
                    era: "years later",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "The Revolution gave the workers dignity. That's worth dying for. Whether it was worth killing for—I'm less sure.",
                    context: "Private reflection, late at night",
                    era: nil,
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "Steele was a better soldier than me. I'm alive because I was better at politics. That's not a compliment.",
                    context: "To Fletcher, drunk, years after the Purges",
                    era: "present day",
                    isPublic: false
                )
            ],
            physicalDescription: "Tall and powerfully built despite his fifty-plus years. Weathered by campaigns and sun. Gray at the temples now, giving him a distinguished air. Scars on his hands and one on his cheek from Fitzgerald City street fighting. Moves like a soldier still—purposeful, economical. Dress uniform immaculate; informal dress slightly rumpled. Eyes that have seen death and given it.",
            psychologicalProfile: "Carter is a soldier who became a politician because the Revolution needed him. He is most comfortable with troops, least comfortable in the Standing Committee. He genuinely believes the Revolution liberated the workers from tyranny, and that belief justifies much—but not everything. The Highland shootings haunt him. The Steele testimony destroys his sleep. He leads because he must, not because he wants to. He respects Mitchell as a necessary man. He fears Wallace because Wallace knows too much. He hopes his son will find a way to serve without becoming what he became. He is tired of war, tired of politics, tired of pretending the system is what they promised it would be. But he cannot stop serving—the Revolution made him, and he owes it everything."
        )
    }

    // MARK: - Eleanor Patterson Biography

    private func createPattersonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "morozova",
            fullName: "Eleanor Frances Patterson",
            aliases: ["Comrade Patterson", "The Iron Lady", "Ellie (childhood only)"],
            ageCategory: "middle-aged",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Red Harbor Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Working-class school. Excelled academically."
                ),
                EducationEntry(
                    institution: "Workers' Academy",
                    years: "pre-Revolution",
                    degree: "Certificate in Revolutionary Theory",
                    notes: "Top of her class. Attracted Fitzgerald's attention."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Youth League Organizer", location: "Red Harbor", significance: "Recruited by Father Brennan (later denounced)"),
                BiographyCareerEvent(era: "during the Depression", position: "Party Secretary, Harbor District", location: "Red Harbor", significance: "Rose rapidly through Youth League"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissar of Education", location: "The Capital", significance: "First government position"),
                BiographyCareerEvent(era: "during the Purges", position: "Commissar of Education", location: "The Capital", significance: "Oversaw ideological curriculum"),
                BiographyCareerEvent(era: "years later", position: "Second Secretary", location: "The Capital", significance: "Number two in Party hierarchy")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Thomas Patterson",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Longshoreman",
                    notes: "Killed in the March on the Capital. A genuine martyr.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Mary Patterson (née O'Brien)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Factory Worker",
                    notes: "Died of heart failure. Eleanor was too busy to be at her bedside.",
                    isSecret: false
                ),
                spouse: nil,
                children: [],
                siblings: [
                    FamilyMember(
                        name: "Thomas Patterson Jr.",
                        relation: "Brother",
                        status: "Alive",
                        occupation: "Factory Manager",
                        notes: "Lives in Zone 5. They exchange holiday cards. Nothing more.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Poetry (secret)", "Wine (private)", "Perfectionism"],
                virtues: ["Tireless work ethic", "Genuine belief in education", "Loyalty to mentors"],
                fears: ["Brennan's children", "Being exposed as a fraud", "Dying alone"],
                desires: ["Historical significance", "Genuine human connection", "To believe she was right"],
                habits: ["Works until midnight", "Memorizes poetry", "Never speaks of personal life"],
                beliefs: ["Education liberates the masses", "Personal sacrifice is necessary", "The Party is her family"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Father Brennan (denounced during the Purges)",
                civilWarRole: "Youth League organizer in Red Harbor. Kept the young people motivated during the siege.",
                purgeExperience: "Denounced her mentor, Father Brennan, to survive. His children were sent to orphanages. She has never seen them again.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Brennan Denunciation",
                        impact: "Testified that Father Brennan was a foreign spy. He wasn't. His execution saved her career.",
                        witnesses: ["wallace"]
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Harbor Siege",
                        impact: "Organized youth support during Red Betty Warren's strike. Learned how to inspire crowds.",
                        witnesses: []
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "patterson_brennan",
                    title: "The Brennan Lie",
                    fullContent: "Father Michael Brennan was a priest who secretly joined the revolutionary movement. He recruited young Eleanor Patterson, taught her to read Marx, gave her purpose. During the Religious Roundup during the Purges, Eleanor was pressured to denounce him as a foreign agent. She did. She testified to conversations that never happened, meetings that never occurred. Brennan was executed. His three children—Margaret, Michael Jr., and Thomas—were sent to state orphanages. Eleanor never learned what happened to them. She has spent ten years trying not to find out. She collects poetry because Brennan taught her to love it. She never reads religious poetry—it hurts too much.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Wallace's files on the Brennan case", "The orphanage records", "Surviving parishioners from Brennan's church"],
                    potentialConsequences: "Would expose Patterson as someone who destroyed an innocent man to save herself. The Brennan children, if found, could testify to their father's character.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["blackmail", "leverage", "exposure"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "We are married to the Party, comrade. It is a demanding spouse.",
                    context: "To a colleague asking about her personal life",
                    era: "in recent years",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "The children of the Revolution will be freer than we were. That's what we work for.",
                    context: "Address on Education Day",
                    era: "present day",
                    isPublic: true
                ),
                CharacterQuote(
                    quote: "I still remember his face when I testified. He looked at me like he understood. I think that was worse.",
                    context: "Private journal, never shown to anyone",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "A striking woman in her forties, with auburn hair now streaked with gray. Sharp features that might be called severe if they ever relaxed. Dress is professional, almost severe—dark suits, minimal jewelry. Moves with precision and purpose. Eyes that could be warm but usually aren't. The face of someone who has learned to control every emotion.",
            psychologicalProfile: "Patterson is the most ideologically committed member of the leadership, which is why she had to commit the greatest sin to survive. She genuinely believes in revolutionary education, in building a new generation of socialist citizens. She also knows she sacrificed an innocent man to maintain her position to do that work. She resolves the contradiction by working harder, achieving more, never resting. If she stops, she might have to think about Brennan. She might have to wonder what happened to his children. She collects poetry in secret because it was Brennan who taught her to love it, and poetry is the only way she allows herself to feel. She trusts Mitchell because he understands necessary crimes. She serves Wallace because Wallace knows her worst secret and has never used it. She grooms Donovan because Donovan is what Patterson could have been without the compromises. She is terrified of dying alone, which is exactly what she will do."
        )
    }

    // MARK: - Kowalski Biography

    private func createKowalskiBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "kowalski",
            fullName: "Stefan Adam Kowalski",
            aliases: ["Director Kowalski", "The Calculator"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Immigrant community school. Showed mathematical talent."
                ),
                EducationEntry(
                    institution: "Workers' University",
                    years: "pre-Revolution",
                    degree: "Bachelor of Science, Economics",
                    notes: "Pre-purge university. Genuinely talented at mathematics."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Junior Economist", location: "Fitzgerald City", significance: "First post-graduation job"),
                BiographyCareerEvent(era: "during the Revolution", position: "Statistical Analyst, Revolutionary Forces", location: "Mobile", significance: "Produced numbers that helped the cause"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissioner of Statistics", location: "The Capital", significance: "Rose through planning apparatus"),
                BiographyCareerEvent(era: "after the Purges", position: "Commissioner of Economic Statistics", location: "The Capital", significance: "Controlled the numbers"),
                BiographyCareerEvent(era: "present day", position: "Chairman, State Planning Commission", location: "The Capital", significance: "Apex of economic power")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Adam Kowalski",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Steel Mill Worker",
                    notes: "Died in a mill accident. Stefan was fifteen. Swore never to work with his hands.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Maria Kowalski (née Wozniak)",
                    relation: "Mother",
                    status: "Alive",
                    occupation: "Retired",
                    notes: "Lives in a state apartment in Fitzgerald City. Stefan sends money. Rarely visits.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Anna Kowalski (née Briggs)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Party Hostess",
                    notes: "Political marriage to a Briggs family member. Loveless but functional. She takes lovers; he pretends not to notice.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Katya Kowalski",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Student",
                        notes: "At the Party Academy in The Capital. Stefan loves her genuinely—perhaps the only person he does.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Expensive tastes", "Embezzlement", "Vanity"],
                virtues: ["Genuine mathematical talent", "Loves his daughter", "Can be charming"],
                fears: ["Exposure", "Wallace", "Carpenter's silent judgment", "Poverty"],
                desires: ["Wealth", "Security", "Katya's success", "Respect he doesn't deserve"],
                habits: ["Checks accounts obsessively", "Wears expensive suits", "Produces statistics on demand"],
                beliefs: ["The system is a game", "Everyone cheats", "Only fools believe the numbers"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "before the Revolution",
                recruitedBy: "No one—joined for career advancement",
                civilWarRole: "Statistical support for revolutionary logistics. Genuinely useful work.",
                purgeExperience: "Survived by producing the statistics the Party wanted. If they needed 30% growth, he calculated 30% growth. Whether it was true was irrelevant.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Zone 3 Famine Statistics",
                        impact: "Produced numbers showing no famine in Zone 3. People were dying; his reports showed bumper harvests. He knew.",
                        witnesses: ["erickson", "carpenter"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "kowalski_famine",
                    title: "The Zone 3 Numbers",
                    fullContent: "During the Zone 3 Famine during the Purges, Kowalski's office produced agricultural statistics showing record grain production in the Agricultural Zone. In reality, collectivization quotas were killing people. Thousands died while his reports showed success. He knew. He produced the numbers anyway because the alternative was being accused of 'spreading defeatism.' Laura Erickson's brother was one of those who died. If she ever sees the original data Kowalski suppressed, she will know he helped kill her family.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Original data files (if they still exist)", "Erickson's private research", "Surviving witnesses from Zone 3"],
                    potentialConsequences: "Would expose Kowalski as complicit in mass death. Would make him an enemy of Erickson and anyone who lost family in the famine.",
                    whoKnows: ["carpenter"],
                    canBeUsedFor: ["blackmail", "alliance with those seeking justice", "destruction"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The numbers say what we need them to say. That's called planning.",
                    context: "To a subordinate questioning data",
                    era: "years later",
                    isPublic: false
                ),
                CharacterQuote(
                    quote: "I survived because I understood the real economy: the economy of power. Numbers serve power. Always.",
                    context: "Private reflection",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "A soft man who has never worked with his hands. Well-dressed—too well for his official salary. Smooth features, manicured nails, an easy smile that doesn't reach his eyes. The body of someone who eats well and exercises never. Moves with the confidence of someone who has never faced real consequences.",
            psychologicalProfile: "Kowalski is the most corrupt senior official in the Republic, and he knows he doesn't deserve his position. He rose by telling people what they wanted to hear, producing statistics that supported political goals regardless of reality. He skims from the Treasury because he's terrified of returning to poverty—his father died in the mills, and Stefan swore he would never be poor. He married for connections, and the marriage is a hollow performance. His daughter Katya is the only thing he genuinely loves; he hopes she never learns what kind of man her father really is. He despises Carpenter because Carpenter is everything he isn't—brilliant, honest, principled. He fears Wallace because Wallace knows about the embezzlement. He survives because he's useful, and because the system he helped build protects people like him."
        )
    }

    // MARK: - Henderson Biography

    private func createHendersonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "kadaris",
            fullName: "William Joseph Henderson",
            aliases: ["Comrade Henderson", "The Idealist", "True Bill"],
            ageCategory: "middle-aged",
            birthPlace: "The People's Proletarian Town, Zone 3",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Rural Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Working-class education"
                ),
                EducationEntry(
                    institution: "Workers' Night School",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Self-educated in Marxist theory"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Union Organizer", location: "The People's Proletarian Town", significance: "Organized grain workers"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Commissar of Labor Relations", location: "The Capital", significance: "Champion of workers' rights"),
                BiographyCareerEvent(era: "present day", position: "Commissar of Agriculture", location: "The Capital", significance: "Fights for realistic quotas")
            ],
            familyTree: FamilyTree(
                father: nil,
                mother: nil,
                spouse: FamilyMember(
                    name: "Dorothy Henderson (née Wilson)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Retired Teacher",
                    notes: "Married 30 years. She keeps him grounded.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "William Henderson Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Factory Manager",
                        notes: "Doesn't share his father's idealism.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Naivety", "Stubbornness"],
                virtues: ["Genuine idealism", "Honesty", "Tireless advocacy"],
                fears: ["That the Revolution failed its promises", "That he's been a fool"],
                desires: ["A society that matches the rhetoric", "Workers' genuine liberation"],
                habits: ["Visits factories personally", "Reads workers' letters", "Argues with anyone"],
                beliefs: ["The Revolution was good", "The system can be reformed", "Workers deserve better"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Union organizers",
                civilWarRole: "Organized supply lines and worker support in the agricultural region",
                purgeExperience: "Survived by being too useful and too genuinely beloved. Even Wallace hesitated to touch him.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "henderson_knowledge",
                    title: "He Knows",
                    fullContent: "Henderson knows the system is corrupt. He knows the quotas are impossible. He knows people have died because of policies he implemented. He continues because he believes working within the system is better than abandoning it. But lately, he's not sure.",
                    discoveryDifficulty: 4,
                    evidenceLocations: ["His own conscience"],
                    potentialConsequences: "If Henderson ever fully accepts what the system has become, he might break—or rebel.",
                    whoKnows: [],
                    canBeUsedFor: ["recruitment to reform", "crisis of conscience"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "We promised them a better world. We owe them one.",
                    context: "To Mitchell, arguing for policy change",
                    era: "present day",
                    isPublic: false
                )
            ],
            physicalDescription: "A weathered man in his forties, with hands that remember manual labor. Plain suits, plain speech, plain manner. The face of someone who has spent his life fighting for others.",
            psychologicalProfile: "Henderson is what the Revolution was supposed to produce: a genuine advocate for workers who believes in the cause. The tragedy is that he works for a system that has betrayed everything he believes in. He continues because the alternative is despair."
        )
    }

    // MARK: - Edwards Biography

    private func createEdwardsBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "edwards",
            fullName: "Edward Thomas Williams (now Edwards)",
            aliases: ["Colonel Edwards", "The Ghost", "Williams (dead name)"],
            ageCategory: "middle-aged",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Harbor District Streets",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Mostly self-taught. Learned to survive."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Courier", location: "Red Harbor", significance: "Ran messages between cells"),
                BiographyCareerEvent(era: "during the Revolution", position: "Field Agent", location: "Behind Enemy Lines", significance: "Sabotage and assassination"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "BPS Officer", location: "The Capital", significance: "Wallace's protégé"),
                BiographyCareerEvent(era: "present day", position: "First Deputy Director", location: "The Capital", significance: "Wallace's likely successor")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Thomas Williams",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Dockworker",
                    notes: "Drank himself to death after mother died.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Mary Williams",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Seamstress",
                    notes: "Died of tuberculosis.",
                    isSecret: false
                ),
                spouse: nil,
                children: [],
                siblings: [
                    FamilyMember(
                        name: "Sarah Williams (now unknown name)",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "Unknown",
                        notes: "Lives in Zone 2 under a different name. Edwards has not contacted her in 15 years.",
                        isSecret: true
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Isolation", "Paranoia", "Inability to trust"],
                virtues: ["Loyalty to Wallace", "Competence", "Honesty with himself"],
                fears: ["Becoming like Blackwood", "Being alone forever", "The weight of succession"],
                desires: ["Escape", "His sister's safety", "To stop carrying secrets"],
                habits: ["Never sits with back to door", "Eyes sweep every room", "Silence is natural state"],
                beliefs: ["The work is necessary", "Trust no one completely", "Wallace knows best"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Harbor underground",
                civilWarRole: "Field operative behind enemy lines. Sabotage, assassination, intelligence.",
                purgeExperience: "Present at the Steele interrogation. Held the lamp. Helped break heroes.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Cell Executions",
                        impact: "Executed three members of his own cell on Wallace's orders. One was probably innocent. Changed his name afterward.",
                        witnesses: ["wallace"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Steele Interrogation",
                        impact: "Witnessed and participated in Steele's interrogation. Never broke him. Signed the warrant anyway.",
                        witnesses: ["wallace"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "edwards_sister",
                    title: "The Hidden Sister",
                    fullContent: "Edwards has a sister, Sarah, living under an assumed name in Zone 2. He has not contacted her in 15 years to protect her from his work. If enemies discovered her location, she could be used as leverage—or eliminated as a message. He would do almost anything to keep her safe.",
                    discoveryDifficulty: 8,
                    evidenceLocations: ["Pre-revolution Harbor records", "Edwards' personal effects (hidden photograph)", "Zone 2 identity registries"],
                    potentialConsequences: "Could be used to blackmail Edwards or force his compliance. If exposed, his sister's life would be in danger.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["blackmail", "leverage", "alliance"]
                ),
                DarkSecret(
                    id: "edwards_cell_executions",
                    title: "The Cell Executions",
                    fullContent: "During the Revolution, Edwards executed three members of his own cell on Wallace's orders. One was almost certainly innocent—the real informer was discovered later, already dead. Edwards changed his name afterward. He still sees the innocent man's face in his dreams.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Wallace's personal records", "Harbor underground archives (if they survived)", "Edwards' pre-revolution identity documents"],
                    potentialConsequences: "Would undermine Edwards' reputation for precision and judgment. Could be used to question Wallace's leadership if framed as an innocent man's murder.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["exposure", "leverage", "discrediting"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The work is necessary. That doesn't make it clean.",
                    context: "To a new recruit",
                    era: "in recent years",
                    isPublic: false
                )
            ],
            physicalDescription: "Average height, average build, average face. Forgettable by design. Moves like a predator—quiet, economical, dangerous. Eyes that never stop watching. Hands steady as stone.",
            psychologicalProfile: "Edwards is Wallace's creation: competent, loyal, ruthless. He is also Wallace's successor, whether he wants to be or not. He carries the weight of his work—the executions, the interrogations, the name he abandoned—but he continues because Wallace asks it and because someone has to do the job. He is not sure he can carry what Wallace carries. He is not sure anyone can."
        )
    }

    // MARK: - Fletcher Biography

    private func createFletcherBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "fletcher",
            fullName: "James Arthur Fletcher",
            aliases: ["General Fletcher", "The Commissar"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Middle-class education—not working-class as he claims"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Organizer", location: "Zone 2", significance: "Joined the movement"),
                BiographyCareerEvent(era: "during the Revolution", position: "Political Commissar", location: "Fitzgerald City", significance: "Attached to Steele's forces"),
                BiographyCareerEvent(era: "during the Purges", position: "Deputy Head, Political Directorate", location: "The Capital", significance: "Rose after Steele's fall"),
                BiographyCareerEvent(era: "present day", position: "Head, Political Directorate", location: "The Capital", significance: "Controls army ideology")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Arthur Fletcher",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Railroad Supervisor (not worker as claimed)",
                    notes: "Middle-class background Fletcher has hidden",
                    isSecret: true
                ),
                mother: FamilyMember(
                    name: "Elizabeth Fletcher (née Harper)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Schoolteacher",
                    notes: "The family had a piano.",
                    isSecret: true
                ),
                spouse: FamilyMember(
                    name: "Margaret Fletcher (née Briggs)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Party Hostess",
                    notes: "Commissar Briggs's niece. Political marriage that became genuine.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "James Fletcher Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Political Officer",
                        notes: "Serves in the Political Directorate under his father.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Pride", "Self-deception", "Political calculation"],
                virtues: ["Genuine leadership ability", "Courage under fire", "Loyalty to family"],
                fears: ["Exposure of false background", "Steele's ghost", "Being seen as a fraud"],
                desires: ["Historical vindication", "Family legacy", "Belief in his own story"],
                habits: ["Tells war stories with political morals", "Commands rooms through will", "Never admits doubt"],
                beliefs: ["The Revolution required sacrifice", "He made the right choices", "History will vindicate him"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "before the Revolution",
                recruitedBy: "Ideological conversion (not hardship)",
                civilWarRole: "Political commissar at Fitzgerald City. Held the line when others wavered.",
                purgeExperience: "Testified against Steele. His mentor. His friend. His guilt.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "fletcher_false_origins",
                    title: "The Middle-Class Commissar",
                    fullContent: "Fletcher claims working-class origins—a railroad worker's son who knew hardship. The truth is his father was a railroad supervisor, his mother a schoolteacher. The family had a piano. He learned revolutionary theory from books, not from hunger. His entire political identity is built on a fabricated biography.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Fitzgerald City public records", "Zone 2 school archives", "Railroad company employment records", "Fletcher family property deeds"],
                    potentialConsequences: "Would destroy Fletcher's credibility as a 'true worker' and undermine his authority in the Political Directorate. His rivals would use this to paint him as a fraud and class traitor.",
                    whoKnows: [],
                    canBeUsedFor: ["exposure", "blackmail", "discrediting", "political destruction"]
                ),
                DarkSecret(
                    id: "fletcher_steele_betrayal",
                    title: "The Mentor's Blood",
                    fullContent: "Fletcher testified against General Steele during the Purges—the man who had been his mentor, his friend, the leader who made him. Fletcher's testimony sealed Steele's fate. He tells himself it was necessary, that Steele had become a danger. But late at night, he knows the truth: he testified to save himself, and he let them execute the best man he ever knew.",
                    discoveryDifficulty: 4,
                    evidenceLocations: ["Purge tribunal transcripts (classified)", "Wallace's personal files", "Steele's case file"],
                    potentialConsequences: "Many veterans remember Steele fondly. If the details of Fletcher's testimony became known—especially if it was self-serving rather than principled—his reputation for loyalty would be shattered.",
                    whoKnows: ["wallace", "brenner"],
                    canBeUsedFor: ["leverage", "alliance", "exposure"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "At Fitzgerald City, the commissars held the line. That's what political officers do. We hold the line.",
                    context: "Address to young officers",
                    era: "in recent years",
                    isPublic: true
                )
            ],
            physicalDescription: "A commanding presence in his fifties. Military bearing despite being a political officer. Gray hair, strong features, the body of a man who kept fit through discipline. Commands attention in any room. Speaks with absolute certainty.",
            psychologicalProfile: "Fletcher is a man who has built his entire identity on a foundation of lies. He claims working-class origins he doesn't have. He betrayed his mentor to survive. He tells himself stories to justify what he did. He is genuinely capable—a leader men follow—but he knows, deep down, that his career is built on betrayal and deception. He passes this legacy to his son, hoping the next generation will be cleaner than he was."
        )
    }

    // MARK: - Major Strickland Biography

    private func createStricklandBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "strickland",
            fullName: "Marcus Strickland",
            aliases: ["Major Strickland", "The Hound"],
            ageCategory: "middle-aged",
            birthPlace: "State Orphanage #7, Zone 4",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "State Orphanage #7",
                    years: "during the Revolution",
                    degree: nil,
                    notes: "Raised by the state after parents were purged. Learned survival early."
                ),
                EducationEntry(
                    institution: "BPS Training Academy",
                    years: "after the Revolution",
                    degree: "Certificate in Security Operations",
                    notes: "Top marks in interrogation techniques."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "BPS Recruit", location: "The Capital", significance: "Recruited directly from orphanage"),
                BiographyCareerEvent(era: "during the Purges", position: "Interrogation Specialist", location: "Various detention facilities", significance: "Developed reputation for efficiency"),
                BiographyCareerEvent(era: "present day", position: "Chief of Counter-Intelligence Directorate", location: "The Capital", significance: "Wallace's enforcer")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Heinrich Strickland",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Factory Manager",
                    notes: "Purged as a 'class enemy' when Marcus was six. Executed in the first wave of the Consolidation.",
                    isSecret: true
                ),
                mother: FamilyMember(
                    name: "Anna Strickland (née Weber)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Music Teacher",
                    notes: "Sent to labor camp after husband's execution. Died within a year. Marcus was told she 'abandoned' him.",
                    isSecret: true
                ),
                spouse: nil,
                children: [],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Cruelty", "Obsessive record-keeping", "Voyeuristic tendencies"],
                virtues: ["Loyalty to Wallace", "Thoroughness", "Never lies about his work"],
                fears: ["Being seen as weak", "The orphanage", "Learning the truth about his parents"],
                desires: ["Power", "Respect", "To never be helpless again"],
                habits: ["Catalogues interrogation notes obsessively", "Never eats with others", "Watches people without speaking"],
                beliefs: ["Everyone is guilty of something", "The strong survive", "Mercy is weakness"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "State orphanage system",
                civilWarRole: "Too young to serve",
                purgeExperience: "Product of the Purges—made what he is by the system",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "strickland_parents",
                    title: "The Purged Parents",
                    fullContent: "Strickland's parents were purged when he was six. His father was a factory manager—enough to make him a 'class enemy' when the quotas demanded victims. His mother died in the camps. Strickland was told they abandoned him. If he ever learned the truth, it might break something—or make him infinitely worse.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Orphanage records (sealed)", "Wallace's files on all agents", "Zone 4 purge documentation"],
                    potentialConsequences: "Could shatter Strickland's worldview or turn him against the system that made him",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["leverage", "manipulation", "psychological destruction"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "Everyone has something to hide. Everyone.",
                    context: "Standard opening line in interrogations",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Hard eyes in a face that never learned to smile naturally. Athletic build maintained through rigid discipline. Moves like a predator assessing prey. Hands that never tremble.",
            psychologicalProfile: "Strickland is what the state creates when it raises children without love. The orphanage taught him that strength is the only virtue and weakness is death. He found purpose in the BPS—a place where his talents for observation and control were valued. He enjoys his work, which disturbs even Wallace. He believes everyone is guilty because believing otherwise would mean his parents were innocent, and that truth might destroy him."
        )
    }

    // MARK: - Captain Reynolds Biography

    private func createReynoldsBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "reynolds",
            fullName: "Helen Reynolds",
            aliases: ["Captain Reynolds", "The Invisible"],
            ageCategory: "middle-aged",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Red Harbor Technical Institute",
                    years: "after the Revolution",
                    degree: "Certificate in Communications",
                    notes: "Specialized in radio operations and cipher work"
                ),
                EducationEntry(
                    institution: "BPS Surveillance School",
                    years: "after the Revolution",
                    degree: "Advanced Certification",
                    notes: "Perfect scores in field surveillance"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Revolution", position: "Communications Operator", location: "Red Harbor", significance: "Intercepted enemy transmissions during the siege"),
                BiographyCareerEvent(era: "after the Revolution", position: "BPS Surveillance Specialist", location: "The Capital", significance: "Rose through technical competence"),
                BiographyCareerEvent(era: "present day", position: "Chief of Surveillance Operations", location: "The Capital", significance: "Runs the listening apparatus")
            ],
            familyTree: FamilyTree(
                father: nil,
                mother: nil,
                spouse: nil,
                children: [],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Emotional detachment", "Workaholism", "Trusts no one"],
                virtues: ["Absolute discretion", "Technical brilliance", "Never complains"],
                fears: ["Being known", "Intimacy", "The past catching up"],
                desires: ["To be left alone", "Professional respect", "Quiet retirement"],
                habits: ["Works eighteen-hour days", "Eats alone", "Never discusses personal life"],
                beliefs: ["Knowledge is protection", "Trust no one", "The work is all that matters"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Revolution",
                recruitedBy: "Red Harbor resistance",
                civilWarRole: "Radio operator—intercepted key enemy transmissions during siege",
                purgeExperience: "Watched colleagues disappear. Learned not to ask questions.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "reynolds_isolation",
                    title: "The Chosen Solitude",
                    fullContent: "Reynolds has no family because she chose to have none. She witnessed what the system does to families—how loved ones become leverage, how children become hostages, how spouses become informants. She cut every tie to anyone who might be used against her. She tells herself it's freedom. It's actually a prison.",
                    discoveryDifficulty: 5,
                    evidenceLocations: ["Reynolds' past in Red Harbor", "Patterns of her behavior"],
                    potentialConsequences: "Could be seen as suspicious isolation—why does she trust no one?",
                    whoKnows: [],
                    canBeUsedFor: ["character understanding"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "I prefer the equipment to the people. Equipment doesn't lie.",
                    context: "To a colleague asking about her work",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Forgettable by design. Medium height, medium build, medium features. The kind of person your eyes slide past in a crowd. Exactly as she intends.",
            psychologicalProfile: "Reynolds is the BPS's invisible woman—technically brilliant, utterly alone. She chose her isolation deliberately, watching what families meant in a system that uses love as a weapon. She respects Edwards because he understands the weight of the work. She avoids Strickland because she sees what he enjoys. She serves the state because it's all she has left."
        )
    }

    // MARK: - Walter Hoffman Biography

    private func createHoffmanBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "steinmetz",
            fullName: "Walter Hoffman",
            aliases: ["Comrade Hoffman", "The Bureaucrat"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Secondary School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Rigid discipline, strict work ethic instilled early"
                ),
                EducationEntry(
                    institution: "Workers' University",
                    years: "after the Revolution",
                    degree: "Certificate in Administrative Science",
                    notes: "Perfect attendance record"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "Party Clerk", location: "Fitzgerald City", significance: "First position in apparatus"),
                BiographyCareerEvent(era: "years later", position: "Secretary of CC Department", location: "The Capital", significance: "Controls the paperwork"),
                BiographyCareerEvent(era: "present day", position: "Secretary of Central Committee", location: "The Capital", significance: "Expected Second Secretary—lost to Patterson")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Ernst Hoffman",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Printer",
                    notes: "Ran a small printing shop before nationalization. Strict disciplinarian.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Gerda Hoffman (née Klein)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Bookkeeper",
                    notes: "Kept meticulous household accounts. Where Walter learned his love of records.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Margarete Hoffman (née Weber)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Party Archivist",
                    notes: "Political marriage arranged by the Party. Neither pretends affection. She has her work; he has his.",
                    isSecret: false
                ),
                children: [],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Obsessive record-keeping", "Bitter jealousy", "Hidden life"],
                virtues: ["Tireless organization", "Total reliability", "Knows where everything is"],
                fears: ["Exposure", "Patterson's success", "Being forgotten"],
                desires: ["Recognition he was denied", "The Second Secretary position", "Security"],
                habits: ["Straightens papers compulsively", "Never jokes", "Keeps detailed files on everyone"],
                beliefs: ["Order must be maintained", "Merit should be rewarded", "The system failed him"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Revolution",
                recruitedBy: "Local Party cell",
                civilWarRole: "Administrative support—kept supply records",
                purgeExperience: "Survived by being indispensable and invisible",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "hoffman_secret_life",
                    title: "The Hidden Encounters",
                    fullContent: "Hoffman has had discreet encounters with men in carefully chosen locations—always outside the Capital, always anonymous. In the PSR, homosexuality is officially 'bourgeois deviation.' Discovery would mean career destruction or worse. He lives in constant fear of exposure, which explains his obsessive secrecy and his loveless political marriage.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Provincial hotel registries", "Surveillance reports (if anyone is watching)", "Pattern analysis of his travels"],
                    potentialConsequences: "Career destruction, possible imprisonment, personal devastation",
                    whoKnows: [],
                    canBeUsedFor: ["blackmail", "leverage"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "Order must be maintained. Without order, we are nothing.",
                    context: "Standard response to any request",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Thin and precise in every movement. Midwestern accent he's never lost. Always perfectly groomed, never a hair out of place. Straightens things compulsively—papers, pencils, anything not aligned.",
            psychologicalProfile: "Hoffman is what happens when the system fails to reward its faithful servants. He did everything right—perfect records, perfect attendance, perfect reliability. He should have been Second Secretary. Patterson won instead. The bitterness has curdled into something darker. His private files are his insurance. His hidden life is his only freedom. His marriage is his cover. He serves the system that betrayed him because he knows nothing else."
        )
    }

    // MARK: - Victor Rawlings Biography

    private func createRawlingsBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "polzin",
            fullName: "Victor Rawlings",
            aliases: ["Comrade Rawlings", "The Gatekeeper"],
            ageCategory: "middle-aged",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Red Harbor Public Schools",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Son of civil servants, learned bureaucracy at home"
                ),
                EducationEntry(
                    institution: "Civil Service Training Institute",
                    years: "after the Revolution",
                    degree: "Administrative Certificate",
                    notes: "Learned that procedure is power"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "Junior Clerk", location: "Red Harbor", significance: "First position in state apparatus"),
                BiographyCareerEvent(era: "during the Purges", position: "Administrative Officer", location: "The Capital", significance: "Provided cover for decisions others wanted made"),
                BiographyCareerEvent(era: "present day", position: "Head of CC Department", location: "The Capital", significance: "Controls what reaches the leadership")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Harold Rawlings Sr.",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Municipal Clerk",
                    notes: "Served the old regime, adapted seamlessly to the new. Taught Victor that systems survive, individuals don't.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Dorothy Rawlings (née Miller)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Secretary",
                    notes: "Also worked in municipal government. The family business was bureaucracy.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Margaret Rawlings (née Thompson)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Women's Committee Administrator",
                    notes: "Works in the Party's Women's Committee. They share information and cover for each other. A functional partnership.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Harold Rawlings Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Student",
                        notes: "Attends Party Youth Academy. Being groomed for the apparatus.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Dorothy Rawlings",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Student",
                        notes: "Named after grandmother. Shows aptitude for administration.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Obstruction as art", "Information trading", "Calculated inoffensiveness"],
                virtues: ["Never forgets a favor", "Reliable for allies", "Protects his own"],
                fears: ["Exposure of his methods", "Being noticed", "Direct confrontation"],
                desires: ["Security for his family", "Continued relevance", "Comfortable retirement"],
                habits: ["Speaks in euphemisms", "Always has a procedure to cite", "Never commits in writing"],
                beliefs: ["Procedure is power", "Systems survive, individuals don't", "Neutrality is the safest position"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Civil service transition",
                civilWarRole: "None—administrative support",
                purgeExperience: "Provided administrative cover for decisions. Learned to leave no traces.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "rawlings_obstruction",
                    title: "The Buried Careers",
                    fullContent: "Rawlings has destroyed careers through pure bureaucracy—lost paperwork, delayed approvals, misrouted documents. No violence, no denunciations, just procedures. At least a dozen officials owe their downfall to his 'clerical errors.' Proving it would require reconstructing years of administrative decisions.",
                    discoveryDifficulty: 8,
                    evidenceLocations: ["Pattern analysis of his department's 'errors'", "Testimony of fallen officials", "The paperwork itself—if anyone kept copies"],
                    potentialConsequences: "Would expose the quiet machinery of bureaucratic murder",
                    whoKnows: [],
                    canBeUsedFor: ["leverage", "understanding the system"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The matter has been referred for appropriate consideration.",
                    context: "Standard response that means 'no'",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Perfectly average in every way. The kind of face you forget immediately. Wears slightly rumpled suits that suggest harmlessness. Nods sympathetically while planning your downfall.",
            psychologicalProfile: "Rawlings learned from his parents that bureaucracy is immortal. Regimes change, but paperwork survives. He serves the system because the system serves him—he has carved out a comfortable niche where he controls access to power without holding power himself. His alliance with Patterson is pure pragmatism. His family is his dynasty. He will never be purged because he is too useful and too invisible to notice."
        )
    }

    // MARK: - Clara Donovan Biography

    private func createDonovanBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "kirillova",
            fullName: "Clara Donovan",
            aliases: ["Comrade Donovan"],
            ageCategory: "young",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Harbor District Schools",
                    years: "during the Revolution",
                    degree: nil,
                    notes: "Working-class education during revolutionary chaos"
                ),
                EducationEntry(
                    institution: "Party Academy",
                    years: "after the Revolution",
                    degree: "Certificate in Political Science",
                    notes: "Scholarship student—impressed instructors with genuine competence"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "Junior Party Worker", location: "Red Harbor", significance: "Started from nothing"),
                BiographyCareerEvent(era: "years later", position: "Department Assistant", location: "The Capital", significance: "Caught Patterson's attention"),
                BiographyCareerEvent(era: "present day", position: "Deputy Head of CC Department", location: "The Capital", significance: "Patterson's protégé")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Patrick Donovan",
                    relation: "Father",
                    status: "Alive",
                    occupation: "Retired Dockworker",
                    notes: "Still lives in Red Harbor. Proud of his daughter but doesn't understand her world.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Mary Donovan (née O'Sullivan)",
                    relation: "Mother",
                    status: "Alive",
                    occupation: "Factory Worker (retired)",
                    notes: "Worked the textile mills until they closed. Revolutionary credentials are genuine.",
                    isSecret: false
                ),
                spouse: nil,
                children: [],
                siblings: [
                    FamilyMember(
                        name: "Michael Donovan",
                        relation: "Brother",
                        status: "Alive",
                        occupation: "Ship Fitter",
                        notes: "Still works the docks in Red Harbor. They write occasionally.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Ambition", "Naivety about her patron", "Overwork"],
                virtues: ["Genuine competence", "Hard work", "Honesty"],
                fears: ["Becoming like Patterson", "Betraying her family", "The cost of success"],
                desires: ["To do good work", "To make her parents proud", "To matter"],
                habits: ["Works long hours", "Speaks efficiently", "Actually reads the reports"],
                beliefs: ["Competence should be rewarded", "The system can be made to work", "Her parents' sacrifice meant something"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Natural progression through Party youth",
                civilWarRole: "Too young—grew up in its aftermath",
                purgeExperience: "Heard stories. Knows Patterson survived something terrible.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "donovan_awareness",
                    title: "The Protégé's Files",
                    fullContent: "Clara suspects Patterson is grooming her as a potential scapegoat—someone to take the blame if Patterson's past catches up. She has begun quietly documenting Patterson's orders, just in case. This insurance policy could save her or destroy her, depending on who finds it.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Clara's private files", "Her apartment in the Capital"],
                    potentialConsequences: "Could be seen as disloyalty—or as prudent self-preservation",
                    whoKnows: [],
                    canBeUsedFor: ["alliance", "leverage", "warning"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "Here is the report. Page seven is the critical section.",
                    context: "Standard briefing style—efficient, competent",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Young and sharp-eyed. Still has calluses on her hands from the docks—she hasn't lost touch with where she came from. Dresses professionally but not expensively. Moves quickly, speaks quickly, thinks quickly.",
            psychologicalProfile: "Donovan is what the Revolution was supposed to produce—a working-class woman risen through merit, genuinely competent, actually believes in doing good work. She is grateful to Patterson but increasingly suspicious of her patron's motives. She documents everything because she has seen what happens to people who trust completely. She visits her parents in Red Harbor when she can, which is not often enough. She is caught between two worlds—the docks where she began and the Capital where she might end."
        )
    }

    // MARK: - Albert Crawford Biography

    private func createCrawfordBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "crawford",
            fullName: "Albert Edward Crawford",
            aliases: ["Comrade Crawford", "The Manager"],
            ageCategory: "middle-aged",
            birthPlace: "Red Harbor, Zone 5",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Private Academy, Red Harbor",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Bourgeois education at an elite school—carefully expunged from records"
                ),
                EducationEntry(
                    institution: "University of London",
                    years: "before the Revolution",
                    degree: "Economics (incomplete)",
                    notes: "Studied abroad before the Revolution. This is hidden."
                ),
                EducationEntry(
                    institution: "Workers' Technical Institute",
                    years: "after the Revolution",
                    degree: "Industrial Management Certificate",
                    notes: "Legitimate credential acquired after the Revolution"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Junior Manager", location: "Crawford Trading Company", significance: "Family business—now nationalized"),
                BiographyCareerEvent(era: "after the Revolution", position: "Technical Specialist", location: "State Planning Commission", significance: "Kept on for competence"),
                BiographyCareerEvent(era: "present day", position: "First Deputy Chairman of Council of Ministers", location: "The Capital", significance: "One of the few who understands economics")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Edward Crawford Sr.",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Merchant (Pre-Revolution)",
                    notes: "Founded Crawford Trading Company. Died of heart attack in the Revolution—officially. Some whisper he was shot in his warehouse.",
                    isSecret: true
                ),
                mother: FamilyMember(
                    name: "Victoria Crawford (née Thornton)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Socialite (Pre-Revolution)",
                    notes: "Died in a refugee camp fleeing the Revolution. Albert never found her grave.",
                    isSecret: true
                ),
                spouse: FamilyMember(
                    name: "Helen Crawford (née Morrison)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Housewife (former professor)",
                    notes: "Former economics professor, purged from teaching for 'bourgeois methodology.' They married after she lost her position. She provides intellectual partnership.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Edward Crawford Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Student",
                        notes: "Attends Party Youth Academy. Believes fully in the Revolution. Doesn't know his grandfather was a capitalist.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Catherine Briggs (née Crawford)",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "Party Hostess",
                        notes: "Married Thomas Briggs Jr., connecting the Crawfords to revolutionary aristocracy. A survival strategy.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Pragmatism above principle", "Hidden contempt for ideologues", "Bourgeois tastes"],
                virtues: ["Actual competence", "Economic understanding", "Gets things done"],
                fears: ["Exposure of his origins", "His wife's continued vulnerability", "His son learning the truth"],
                desires: ["Functional economy", "Security for his family", "Quiet respect"],
                habits: ["Checks his watch frequently", "Speaks in practical terms", "Avoids ideology"],
                beliefs: ["Results matter, rhetoric doesn't", "The economy doesn't care about politics", "Survival requires adaptation"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Necessity—offered expertise to survive",
                civilWarRole: "None—hiding his background",
                purgeExperience: "Kept his head down, produced results, survived",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "crawford_origins",
                    title: "The Bourgeois Past",
                    fullContent: "Crawford's family were capitalists—factory owners, merchants, investors. His father founded a trading company that was nationalized. His mother died fleeing the Revolution. He destroyed most records, but some documentation survives in Zone 5 archives. If revealed, his 'class background' could be used against him despite decades of service.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Red Harbor municipal archives", "Pre-revolutionary business registries", "Crawford family property records"],
                    potentialConsequences: "Would expose him as a class enemy who infiltrated the apparatus",
                    whoKnows: [],
                    canBeUsedFor: ["blackmail", "exposure", "leverage"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "Yes, yes, I understand the political sensitivities. Now, shall we discuss how to actually solve the problem?",
                    context: "Standard meeting style—impatient with ideology",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Well-groomed in a way that suggests education and means. Checks his watch frequently. Speaks with the brisk confidence of a man who knows how things work. Expensive tastes carefully concealed behind standard-issue suits.",
            psychologicalProfile: "Crawford is the system's guilty secret—a bourgeois expert kept on because the Revolution needs people who can actually run an economy. He has adapted completely, married into respectability, produced a son who believes in socialism. But he knows what he is, and he knows they might remember someday. His competition with Kowalski is ideological as well as personal—Crawford has competence, Kowalski has political cover. Crawford's wife Helen provides intellectual partnership and shared vulnerability. His son must never know where the family came from."
        )
    }

    // MARK: - Gregory Mason Biography

    private func createMasonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "mason",
            fullName: "Gregory Thomas Mason",
            aliases: ["Comrade Mason"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Secondary School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Unremarkable student, remarkable survivor"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "Junior Clerk", location: "Fitzgerald City", significance: "First position—utterly unremarkable"),
                BiographyCareerEvent(era: "during the Purges", position: "Administrative Officer", location: "The Capital", significance: "Survived by being inoffensive"),
                BiographyCareerEvent(era: "present day", position: "Deputy Chairman of Council of Ministers", location: "The Capital", significance: "Rose through pure survival")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Thomas Mason",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Office Clerk",
                    notes: "Worked municipal offices his whole life. Taught Gregory to keep his head down.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Elizabeth Mason (née Wright)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Schoolteacher",
                    notes: "Gentle woman who died of influenza. Gregory rarely speaks of her.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Patricia Mason (née Bennett)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Housewife",
                    notes: "Married before the Purges. They rarely see each other—Gregory keeps family separate from politics.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Thomas Mason Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Factory Worker",
                        notes: "Works in Zone 2. Gregory visited once in five years.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Elizabeth Mason",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Teacher",
                        notes: "Named after grandmother. Works in provincial school.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Patricia Mason Jr.",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Student",
                        notes: "Youngest child. Still in school.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Cowardice", "Stamps (obsessive)", "Passivity"],
                virtues: ["Harmlessness", "Reliability", "Family devotion (distant)"],
                fears: ["Confrontation", "Decisions", "Standing out"],
                desires: ["Retirement", "Grandchildren", "Quiet"],
                habits: ["Sweats when pressed", "Collects stamps obsessively", "Avoids eye contact"],
                beliefs: ["The nail that sticks up gets hammered", "Survival is success", "Family must be protected"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Circumstance—the office continued operating",
                civilWarRole: "None",
                purgeExperience: "Watched colleagues fall. Never denounced, never defended. Silent survivor.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "mason_guilt",
                    title: "The Survivor's Silence",
                    fullContent: "Mason watched colleagues fall during every purge—some he could have defended with a word, some he could have warned with a gesture. He did nothing. He wasn't a denouncer, but his silence was enough. The faces of the fallen visit him at night. His stamp collection is how he doesn't think about them.",
                    discoveryDifficulty: 3,
                    evidenceLocations: ["His own conscience", "The memories of survivors"],
                    potentialConsequences: "More psychological than political—he already judges himself",
                    whoKnows: [],
                    canBeUsedFor: ["understanding", "manipulation through guilt"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "Perhaps the General Secretary has a preference?",
                    context: "Standard response to any decision",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Sweaty, anxious, always looking for the safe position. Rumpled suits, nervous hands. The face of a man who has spent his life being afraid.",
            psychologicalProfile: "Mason's greatest achievement is survival. He has outlasted purges, waves, campaigns, and movements by being utterly unremarkable. He never takes positions, never makes enemies, never stands out. His family is kept deliberately separate from his work—they are hostages to fortune he cannot afford to risk. His stamp collection is his only passion. He will retire someday and no one will remember he existed, which is exactly his goal."
        )
    }

    // MARK: - Irene Sullivan Biography

    private func createSullivanBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "sullivan_i",
            fullName: "Irene Margaret Sullivan",
            aliases: ["Comrade Sullivan", "Minister Sullivan"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Mill District Schools",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Working-class education—learned more on the factory floor"
                ),
                EducationEntry(
                    institution: "Workers' Night School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Evening classes while working the mills"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Textile Worker", location: "Fitzgerald City", significance: "Third generation in the mills"),
                BiographyCareerEvent(era: "during the Revolution", position: "Union Organizer", location: "Fitzgerald City", significance: "Led mill workers in the Revolution"),
                BiographyCareerEvent(era: "present day", position: "Minister of Light Industry", location: "The Capital", significance: "Still fights for realistic quotas")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Michael Sullivan",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Mill Worker",
                    notes: "Worked the looms for forty years. Died of lung disease from the cotton dust.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Rose Sullivan (née O'Brien)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Mill Worker",
                    notes: "Lawrence strike organizer. Died before the Revolution. Irene keeps her union card.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "James Sullivan",
                    relation: "Husband",
                    status: "Alive",
                    occupation: "Factory Manager",
                    notes: "They met on the factory floor. He runs a textile plant now. They understand each other.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Michael Sullivan Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Factory Engineer",
                        notes: "Works in heavy industry. The family tradition continues.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Rose Sullivan",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Student",
                        notes: "Named after grandmother. Studying at technical institute.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: [
                    FamilyMember(
                        name: "Margaret Sullivan (grandmother)",
                        relation: "Grandmother",
                        status: "Deceased",
                        occupation: "Seamstress",
                        notes: "Died in the Triangle Shirtwaist Fire. The family never forgot.",
                        isSecret: false
                    )
                ]
            ),
            personalTraits: PersonalTraits(
                vices: ["Stubbornness", "Impatience with politicians", "Occasional sardonic humor"],
                virtues: ["Genuine care for workers", "Practical competence", "Visits factories personally"],
                fears: ["Failing the workers", "Becoming like the bosses", "Her grandmother's fate repeating"],
                desires: ["Consumer goods people can actually use", "Realistic quotas", "Worker dignity"],
                habits: ["Visits factories regularly", "Defends her ministry fiercely", "Keeps her mother's union card"],
                beliefs: ["The Revolution was for the workers", "Quotas should be achievable", "Someone has to care about the details"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "before the Revolution",
                recruitedBy: "Family tradition—born into it",
                civilWarRole: "Union organizer in Fitzgerald City mills",
                purgeExperience: "Survived through genuine worker support and careful neutrality",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "sullivan_quotas",
                    title: "The Adjusted Reports",
                    fullContent: "Sullivan has quietly adjusted production reports to protect factory managers who couldn't meet impossible quotas. If discovered, this 'falsification' could be construed as sabotage—a capital offense. She does it because someone has to keep the workers alive while the planners play with numbers.",
                    discoveryDifficulty: 5,
                    evidenceLocations: ["Ministry records", "Factory-level reports", "The managers she protected"],
                    potentialConsequences: "Could be charged with sabotage for protecting workers from impossible demands",
                    whoKnows: ["thompson"],
                    canBeUsedFor: ["alliance", "blackmail", "understanding"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The quota is the quota. Now, where are the textiles coming from?",
                    context: "Standard meeting frustration",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Working-class woman who carries herself with earned authority. Hands that remember the looms. Practical clothes, sensible shoes. The face of someone who has spent her life getting things done.",
            psychologicalProfile: "Sullivan is what the Revolution was supposed to produce—a worker risen to lead workers, still connected to the factory floor. She fights daily against impossible quotas because she remembers her grandmother dying in a fire caused by locked doors and profit. Her husband understands her world. Her children carry the family tradition. She bends the rules when she has to because someone has to keep the workers alive while the ideologues argue about numbers."
        )
    }

    // MARK: - Peter Collins Biography

    private func createCollinsBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "collins",
            fullName: "Peter Joseph Collins",
            aliases: ["Comrade Collins", "Brother Peter"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "None formal",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Started in the mills at fourteen. Learned everything on the job."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Steel Mill Worker", location: "Fitzgerald City", significance: "Started at fourteen"),
                BiographyCareerEvent(era: "before the Revolution", position: "Foreman", location: "Fitzgerald City", significance: "Rose through skill and personality"),
                BiographyCareerEvent(era: "after the Revolution", position: "Factory Director", location: "Zone 2", significance: "One of the first worker-directors"),
                BiographyCareerEvent(era: "present day", position: "First Deputy Minister of Heavy Industry", location: "The Capital", significance: "Still knows the machines")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Joseph Collins",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Steelworker",
                    notes: "Died in a mill accident when Peter was twelve. Crushed by machinery.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Mary Collins (née Flynn)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Laundress",
                    notes: "Raised five children alone after husband's death. Died of exhaustion.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Ellen Collins (née Murphy)",
                    relation: "Wife",
                    status: "Deceased",
                    occupation: "Factory Worker",
                    notes: "Died in the flu epidemic during the Purges. They loved each other genuinely.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Joseph Collins Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Ministry Official",
                        notes: "Works in Heavy Industry Ministry. Peter is proud but worried for him.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Mary Collins",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "Retired Factory Worker",
                        notes: "Lives in Zone 2. They visit when Peter can manage.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Drinking (hidden)", "Nostalgia", "Rough language"],
                virtues: ["Genuine knowledge of industry", "Worker solidarity", "Honest about limitations"],
                fears: ["His son following his path", "Losing touch with the workers", "Drinking becoming visible"],
                desires: ["Functional factories", "His son's safety", "Honest retirement"],
                habits: ["Calls everyone 'brother'", "Still has calloused hands", "Hidden bottles in office"],
                beliefs: ["Workers built this country", "Machines don't care about politics", "The Revolution was worth it—once"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Revolution",
                recruitedBy: "Factory organizing committee",
                civilWarRole: "Factory defense—kept the mills running for the Revolution",
                purgeExperience: "Lost friends but survived through genuine worker support",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "collins_drinking",
                    title: "The Hidden Bottles",
                    fullContent: "Collins drinks more than anyone knows—hidden bottles in his office, vodka in his tea. He functions, but barely. A medical examination would reveal liver damage. He drinks to forget the gap between what he believed the Revolution would build and what it actually became. Ellen's death broke something in him that vodka can't fix.",
                    discoveryDifficulty: 4,
                    evidenceLocations: ["His office", "Sympathetic subordinates who cover for him", "Medical records if examined"],
                    potentialConsequences: "Could be removed for medical reasons if discovered formally",
                    whoKnows: [],
                    canBeUsedFor: ["leverage", "sympathy"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "I know machines, brother. I know what they can do.",
                    context: "Standard defense of his authority",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Hands still calloused from the mills. Bluff, confident manner of a man who rose from the floor. Slightly red-faced—the drinking shows to those who know. Dresses like a worker who was handed a suit.",
            psychologicalProfile: "Collins is what happens when the Revolution keeps its promises and breaks them at the same time. He rose from the factory floor to the ministry, just as the ideology promised. But Ellen died, the quotas became impossible, and the gap between revolutionary rhetoric and industrial reality grew too wide to bridge. He drinks to forget. He works to remember why he believed. His son carries his hopes now—and his fears."
        )
    }

    // MARK: - Dr. Carpenter Biography

    private func createCarpenterBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "carpenter",
            fullName: "Victoria Carpenter",
            aliases: ["Dr. Carpenter", "Comrade Carpenter"],
            ageCategory: "middle-aged",
            birthPlace: "The Capital",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Capital Technical School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Daughter of engineers—education was expected"
                ),
                EducationEntry(
                    institution: "University of the Capital",
                    years: "before the Revolution",
                    degree: "Doctorate in Economics",
                    notes: "One of the few women in the program"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Research Assistant", location: "University of the Capital", significance: "Academic career interrupted by Revolution"),
                BiographyCareerEvent(era: "after the Revolution", position: "Planning Analyst", location: "State Planning Commission", significance: "Technical expertise retained"),
                BiographyCareerEvent(era: "present day", position: "Deputy Chairman of State Planning", location: "The Capital", significance: "Actually understands the data Kowalski fabricates")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Robert Carpenter",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Chief Engineer, Municipal Works",
                    notes: "Built bridges and waterworks for the old regime. Died of natural causes before the Purges—fortunate timing.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Eleanor Carpenter (née Harrison)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Mathematics Teacher",
                    notes: "Taught Victoria that women could be scholars. Died during the Revolution.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Thomas Carpenter (né Wilson)",
                    relation: "Husband",
                    status: "Alive",
                    occupation: "Physicist",
                    notes: "Works at the State Physics Institute. They discuss work over dinner.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "Robert Carpenter Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Engineering Student",
                        notes: "Named after grandfather. Shows the family talent for technical work.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Impatience with stupidity", "Cold manner", "Visible contempt for Kowalski"],
                virtues: ["Genuine expertise", "Honesty about data", "Actually reads the reports"],
                fears: ["The falsified data will cause collapse", "Being blamed for Kowalski's failures", "Her son following technical path into danger"],
                desires: ["Accurate statistics", "Rational planning", "Professional respect"],
                habits: ["Corrects errors publicly", "Keeps backup calculations", "Silent contempt for political appointees"],
                beliefs: ["Numbers don't lie, people do", "Technical expertise should be valued", "Reality will assert itself eventually"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Retained for expertise",
                civilWarRole: "None—in university during war",
                purgeExperience: "Survived through technical indispensability",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "carpenter_knowledge",
                    title: "The Real Numbers",
                    fullContent: "Carpenter knows the production statistics are fabricated—she's done the real calculations. She knows Kowalski's reports are fiction. She has kept her own records, hidden carefully. If revealed, they would expose the planning system as a fantasy built on lies. She keeps them as insurance—and because someone should know the truth.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Her private office files", "Home safe", "Her husband (if he knows)"],
                    potentialConsequences: "Could expose the entire planning apparatus as fraud",
                    whoKnows: [],
                    canBeUsedFor: ["leverage", "truth-telling", "alliance"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The data does not support that conclusion. Let me show you the actual calculations.",
                    context: "Standard correction of Kowalski's fantasies",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Sharp-featured woman with the bearing of an academic. Glasses perched on her nose. The look of someone who is always calculating something.",
            psychologicalProfile: "Carpenter is what survives of the technical class—an expert who has made herself indispensable by being genuinely competent. She despises Kowalski's fabrications because she knows the real numbers. She keeps her own records because someone should know the truth. Her family carries the engineering tradition. She serves the system not from belief but from professionalism—the work is the work, regardless of who signs the orders."
        )
    }

    // MARK: - Laura Erickson Biography

    private func createEricksonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "erickson",
            fullName: "Laura Marie Erickson",
            aliases: ["Comrade Erickson"],
            ageCategory: "middle-aged",
            birthPlace: "Zone 3, Agricultural Region",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Rural District School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Farm education—learned practical agriculture"
                ),
                EducationEntry(
                    institution: "Workers' Agricultural Institute",
                    years: "after the Revolution",
                    degree: "Certificate in Agricultural Management",
                    notes: "Scholarship for promising rural students"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Farm Worker", location: "Zone 3", significance: "Born to the land"),
                BiographyCareerEvent(era: "after the Revolution", position: "Collective Farm Organizer", location: "Zone 3", significance: "Implemented collectivization"),
                BiographyCareerEvent(era: "present day", position: "Deputy Director of Agricultural Planning", location: "The Capital", significance: "Fights for realistic harvest quotas")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Erik Erickson",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Farmer",
                    notes: "Lost the family farm to collectivization. Died of 'heart failure'—actually starvation during the Zone 3 famine.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Ingrid Erickson (née Lindgren)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Farm Wife",
                    notes: "Died in the Zone 3 famine. Laura was in the Capital, organizing the collectivization that killed her.",
                    isSecret: false
                ),
                spouse: nil,
                children: [],
                siblings: [
                    FamilyMember(
                        name: "Karl Erickson",
                        relation: "Brother",
                        status: "Deceased",
                        occupation: "Farmer",
                        notes: "Died in the Zone 3 famine. His children were taken to state orphanages.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Guilt", "Overwork", "Inability to connect"],
                virtues: ["Understanding of agriculture", "Genuine knowledge", "Tireless advocacy for realistic quotas"],
                fears: ["Another famine", "The truth about her role", "Dying alone"],
                desires: ["Achievable harvests", "Peace with her past", "Her brother's children"],
                habits: ["Works constantly", "Eats sparingly", "Avoids personal relationships"],
                beliefs: ["The land doesn't lie", "Quotas must be realistic", "She can never make amends"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Revolution",
                recruitedBy: "Rural organizing committee",
                civilWarRole: "Collectivization organizer in Zone 3",
                purgeExperience: "Survived because she was in the Capital while her family starved in the zone she helped collectivize",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "erickson_famine",
                    title: "The Zone 3 Guilt",
                    fullContent: "Laura was in the Capital organizing collectivization quotas when the Zone 3 famine struck. Her parents starved. Her brother died. His children were taken to orphanages. She has never found them. The policies she helped implement killed her own family. She has never recovered. She will never marry, never have children, never allow herself happiness. Her work on realistic quotas is her penance.",
                    discoveryDifficulty: 4,
                    evidenceLocations: ["Zone 3 famine records", "Her own personnel file", "Anyone who knew the Erickson family"],
                    potentialConsequences: "Already known—the tragedy is her perpetual sentence",
                    whoKnows: ["kowalski"],
                    canBeUsedFor: ["understanding", "cruelty"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "The harvest doesn't care about quotas. The wheat grows or it doesn't.",
                    context: "Standard defense of realistic planning",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Thin, worn, older than her years. The body of someone who forgets to eat. Eyes that have seen too much. The permanent sadness of someone who can never make amends.",
            psychologicalProfile: "Erickson is living penance. She helped organize the collectivization that created the Zone 3 famine. Her family died while she sat in the Capital counting quotas. She has no family because she does not deserve one. She works on realistic harvest targets because she knows what happens when the numbers lie. Kowalski knows her brother died in the famine—he uses it to keep her in line. She serves because service is all she has left."
        )
    }

    // MARK: - Major Spencer Biography

    private func createSpencerBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "spencer",
            fullName: "Thomas Andrew Spencer",
            aliases: ["Major Spencer", "Comrade Spencer"],
            ageCategory: "young",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Fitzgerald City Schools",
                    years: "after the Revolution",
                    degree: nil,
                    notes: "Revolutionary-era education—ideology and practicality"
                ),
                EducationEntry(
                    institution: "Military-Political Academy",
                    years: "after the Revolution",
                    degree: "Commissar Certificate",
                    notes: "Top of his class in ideological instruction"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "after the Revolution", position: "Youth League Organizer", location: "Fitzgerald City", significance: "True believer from the start"),
                BiographyCareerEvent(era: "years later", position: "Junior Commissar", location: "Army Units", significance: "Ideological instruction"),
                BiographyCareerEvent(era: "present day", position: "Major, Political Directorate", location: "The Capital", significance: "Rising star under Carter's notice")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Andrew Spencer",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Railway Worker",
                    notes: "Died in the Revolution—genuine martyr. His sacrifice gave Thomas purpose.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Helen Spencer (née O'Brien)",
                    relation: "Mother",
                    status: "Alive",
                    occupation: "Party Teacher",
                    notes: "Teaches revolutionary history. Still believes completely. Thomas gets his faith from her.",
                    isSecret: false
                ),
                spouse: nil,
                children: [],
                siblings: [
                    FamilyMember(
                        name: "Catherine Spencer",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "Nurse",
                        notes: "Works in military hospital. The Spencer children serve.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Naivety", "Idealism bordering on blindness", "Quick temper"],
                virtues: ["Genuine courage", "True belief", "Loyalty to troops"],
                fears: ["Losing faith", "Becoming like the cynics", "Dishonoring his father"],
                desires: ["A revolution that matches the rhetoric", "To serve honorably", "His mother's pride"],
                habits: ["Quotes revolutionary texts", "Exercises intensely", "Writes letters home"],
                beliefs: ["The Revolution was good", "Service is honor", "His father died for something real"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "after the Revolution",
                recruitedBy: "Born into revolutionary family",
                civilWarRole: "Too young to serve",
                purgeExperience: "Heard stories but didn't experience directly",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "spencer_doubt",
                    title: "The Growing Questions",
                    fullContent: "Spencer still believes, but questions are starting. He's seen commissars who don't believe. He's heard stories about what really happened in the Purges. His father died a martyr—but for what exactly? He pushes the doubts down, but they're growing. If his faith breaks, he doesn't know what he'll become.",
                    discoveryDifficulty: 4,
                    evidenceLocations: ["His own behavior", "Private journal if he keeps one"],
                    potentialConsequences: "Crisis of faith could turn him reformer or cynic",
                    whoKnows: [],
                    canBeUsedFor: ["mentorship", "manipulation", "recruitment"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "My father died for the Revolution. I will live for it.",
                    context: "Standard response to cynicism",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Young, fit, eager. The face of someone who hasn't been broken yet. Clean uniform, straight posture, earnest eyes.",
            psychologicalProfile: "Spencer is the true believer the Revolution was supposed to produce—raised in the faith, shaped by his father's martyrdom, genuinely committed to the cause. Carter sees his younger self in Spencer and worries for him. Fletcher sees useful idealism. Spencer himself is starting to notice the gap between rhetoric and reality, but he's not ready to admit it. His mother's faith sustains him. His father's memory drives him. The system will either break him or change him."
        )
    }

    // MARK: - Colonel Bodine Biography

    private func createBodineBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "bodine",
            fullName: "Robert James Bodine",
            aliases: ["Colonel Bodine", "Bull Bodine"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Military Academy",
                    years: "during the Revolution",
                    degree: "Officer's Commission",
                    notes: "Trained during the Civil War—learned in combat"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Revolution", position: "Militia Officer", location: "Fitzgerald City", significance: "Street fighting during the battle"),
                BiographyCareerEvent(era: "after the Revolution", position: "Battalion Commander", location: "Various", significance: "Proved himself in small unit actions"),
                BiographyCareerEvent(era: "present day", position: "Deputy Head of Military Political Directorate", location: "The Capital", significance: "Fletcher's trusted subordinate")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "James Bodine",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Army Sergeant (Pre-Revolution)",
                    notes: "Career NCO in the old army. Switched sides during the Revolution.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Martha Bodine (née Reynolds)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Army Wife",
                    notes: "Followed the regiment. Died of influenza.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Sarah Bodine (née Mitchell)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Military Hospital Administrator",
                    notes: "Met during the Civil War. She ran the field hospital.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "James Bodine Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Army Captain",
                        notes: "Third generation soldier. Robert is proud and terrified.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Martha Bodine",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Military Nurse",
                        notes: "Follows her mother's path.",
                        isSecret: false
                    )
                ],
                siblings: [],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Simplicity", "Loyalty over judgment", "Soldier's habits"],
                virtues: ["Physical courage", "Troop loyalty", "Honest about limitations"],
                fears: ["His son dying in war", "Failing his troops", "Political complexity"],
                desires: ["Soldiers treated fairly", "His children's safety", "Clear orders"],
                habits: ["Speaks plainly", "Checks on his men", "Uncomfortable in meetings"],
                beliefs: ["Soldiers deserve respect", "Orders should be clear", "The simple virtues matter"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Revolution",
                recruitedBy: "Followed his father's lead",
                civilWarRole: "Street fighting commander in Battle of Fitzgerald City",
                purgeExperience: "Kept his head down, focused on his unit",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "bodine_loyalty",
                    title: "The Switched Allegiance",
                    fullContent: "Bodine's father was a career NCO in the old regime's army. He switched sides during the Revolution when it was clear who would win. Robert was old enough to understand—they survived by betrayal. The family never speaks of it. Robert's Revolutionary credentials rest on violence in Fitzgerald City, not on original belief.",
                    discoveryDifficulty: 5,
                    evidenceLocations: ["Old army records", "His father's personnel file", "Fitzgerald City veterans who remember"],
                    potentialConsequences: "Could undermine his Revolutionary authenticity",
                    whoKnows: [],
                    canBeUsedFor: ["leverage", "understanding"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "My job is simple: keep the soldiers believing. The rest is politics.",
                    context: "To a colleague asking about his work",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Bull-necked and powerful despite his age. Soldier's bearing, soldier's hands. The kind of man troops follow into fire.",
            psychologicalProfile: "Bodine is the simple soldier the political apparatus needs—loyal, brave, not given to questions. He doesn't understand politics and doesn't want to. His family is military going back generations—his father switched sides, his son now serves. He follows Fletcher because Fletcher gives clear orders. He worries for his son because he knows what war costs. He is valuable precisely because he doesn't think too much."
        )
    }

    // MARK: - Wesley Thompson Biography

    private func createThompsonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "thompson",
            fullName: "Wesley Thompson",
            aliases: ["Comrade Thompson", "Wes"],
            ageCategory: "middle-aged",
            birthPlace: "Fitzgerald City, Zone 2",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Factory Floor",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Started work at twelve. Education came later."
                ),
                EducationEntry(
                    institution: "Workers' Night School",
                    years: "before the Revolution",
                    degree: nil,
                    notes: "Evening classes—learned to read as an adult"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Machine Operator", location: "Fitzgerald City", significance: "Factory floor to Union"),
                BiographyCareerEvent(era: "during the Revolution", position: "Workers' Militia", location: "Fitzgerald City", significance: "Street fighting in the Battle"),
                BiographyCareerEvent(era: "present day", position: "Deputy Minister of Heavy Industry", location: "The Capital", significance: "Still represents the factory floor")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "George Thompson",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Factory Worker",
                    notes: "Died in industrial accident when Wesley was ten. No compensation, no investigation.",
                    isSecret: false
                ),
                mother: FamilyMember(
                    name: "Ada Thompson (née Williams)",
                    relation: "Mother",
                    status: "Deceased",
                    occupation: "Laundress",
                    notes: "Raised Wesley and three siblings alone. Died of exhaustion before she saw the Revolution.",
                    isSecret: false
                ),
                spouse: FamilyMember(
                    name: "Dorothy Thompson (née Jones)",
                    relation: "Wife",
                    status: "Alive",
                    occupation: "Factory Floor Supervisor",
                    notes: "Met on the factory floor. She still works—won't take a desk job.",
                    isSecret: false
                ),
                children: [
                    FamilyMember(
                        name: "George Thompson Jr.",
                        relation: "Son",
                        status: "Alive",
                        occupation: "Factory Engineer",
                        notes: "Named after grandfather. Has the education Wesley never got.",
                        isSecret: false
                    ),
                    FamilyMember(
                        name: "Ada Thompson",
                        relation: "Daughter",
                        status: "Alive",
                        occupation: "Teacher",
                        notes: "Named after grandmother. Teaches in factory district.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Harold Thompson",
                        relation: "Brother",
                        status: "Deceased",
                        occupation: "Soldier",
                        notes: "Killed in the Battle of Fitzgerald City. Buried in the mass grave.",
                        isSecret: false
                    )
                ],
                extendedFamily: []
            ),
            personalTraits: PersonalTraits(
                vices: ["Stubbornness", "Distrust of intellectuals", "Occasional temper"],
                virtues: ["Genuine worker solidarity", "Practical knowledge", "Loyalty to old comrades"],
                fears: ["Betraying worker interests", "His children forgetting where they came from", "Becoming what they fought"],
                desires: ["Workers respected", "Fair conditions", "His father's death meaning something"],
                habits: ["Still visits factories", "Keeps union card", "Drinks with old comrades"],
                beliefs: ["Workers built this country", "The Revolution was for them", "Someone has to remember"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "before the Revolution",
                recruitedBy: "Union organizers",
                civilWarRole: "Street fighting in Battle of Fitzgerald City—lost his brother",
                purgeExperience: "Survived through worker support and Carter's protection",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Factory Defense",
                        impact: "Led workers defending the ball bearing plant. Kept it running for the Revolution.",
                        witnesses: ["ozols", "fletcher", "bodine"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "thompson_covering",
                    title: "The Adjusted Reports",
                    fullContent: "Thompson has covered for Sullivan's quota adjustments—he knows she fudges the numbers to protect factory managers from impossible demands. He does the same in Heavy Industry. If exposed, both could face charges of sabotage. They do it because someone has to keep the workers alive.",
                    discoveryDifficulty: 5,
                    evidenceLocations: ["Ministry records", "Factory-level reports", "Managers who know"],
                    potentialConsequences: "Could be charged with sabotage alongside Sullivan",
                    whoKnows: ["sullivan_i"],
                    canBeUsedFor: ["alliance", "blackmail", "understanding"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "My father died in that factory. My brother died for the Revolution. Don't tell me about sacrifice.",
                    context: "To an ideologue questioning his commitment",
                    era: nil,
                    isPublic: false
                )
            ],
            physicalDescription: "Scarred hands from factory work. Solid build of a man who learned work young. Face weathered by decades of industrial labor and political struggle.",
            psychologicalProfile: "Thompson is the authentic worker voice the Revolution needs to claim legitimacy—and he knows it. He rose from the factory floor through the Battle of Fitzgerald City, lost his brother in the fighting, and earned his position in blood. He covers for Sullivan because they share the same mission: keeping workers alive while the planners play with quotas. Carter trusts him because they fought together. He visits factories because he refuses to forget where he came from. His children have the education he never got, but he worries they'll forget the struggle."
        )
    }
}
