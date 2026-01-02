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
        biographies["mitchell"] = createMitchellBiography()
        biographies["wallace"] = createWallaceBiography()
        biographies["carter"] = createCarterBiography()
        biographies["patterson"] = createPattersonBiography()
        biographies["kowalski"] = createKowalskiBiography()
        biographies["henderson"] = createHendersonBiography()
        biographies["edwards"] = createEdwardsBiography()
        biographies["fletcher"] = createFletcherBiography()
    }

    // MARK: - Harold Mitchell Biography

    private func createMitchellBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "mitchell",
            fullName: "Harold James Mitchell",
            aliases: ["Comrade Secretary", "The Gray Man"],
            ageCategory: "middle-aged",
            birthPlace: "Philadelphia, Pennsylvania",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Philadelphia Public Schools",
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
                BiographyCareerEvent(era: "before the Revolution", position: "Factory Worker", location: "Philadelphia", significance: "First exposure to labor organizing"),
                BiographyCareerEvent(era: "during the Depression", position: "Union Shop Steward", location: "Philadelphia", significance: "Began organizing activities"),
                BiographyCareerEvent(era: "during the Depression", position: "Youth League Organizer", location: "Northeast Region", significance: "Rose to prominence under Fitzgerald's patronage"),
                BiographyCareerEvent(era: "during the Revolution", position: "Revolutionary Militia Commander", location: "Philadelphia", significance: "Led workers' militia during March on Washington"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissar of Labor", location: "Washington, DC", significance: "First government position after Revolution"),
                BiographyCareerEvent(era: "during the Purges", position: "Commissar of Heavy Industry", location: "Washington, DC", significance: "Oversaw wartime production"),
                BiographyCareerEvent(era: "years later", position: "General Secretary", location: "Washington, DC", significance: "Succeeded Fitzgerald under mysterious circumstances")
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
                    notes: "Irish immigrant. Died during the Civil War, caught in crossfire in Philadelphia.",
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
                        notes: "Killed at the Battle of Chicago. A genuine martyr.",
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
                civilWarRole: "Philadelphia Workers' Militia Commander; secured the city during the March on Washington",
                purgeExperience: "Signed death warrants for 47 people, including wife's cousins. Protected by Fitzgerald until Fitzgerald died.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The March on Washington",
                        impact: "Led the Philadelphia column. Fitzgerald trusted him with the rear guard.",
                        witnesses: ["carter", "wallace", "henderson"]
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
                    fullContent: "Eleanor Mitchell did not die of 'illness' during the Purges. She hanged herself in their apartment after discovering that Harold had personally signed the death warrants for her cousins, the Kowalski family members accused in the Midwest Conspiracy. She left a note that Wallace confiscated. The note is in Wallace's private files. Harold found her body. He has never forgiven himself, but he has never stopped signing warrants either.",
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
            birthPlace: "New York City (Lower East Side)",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Public School 97, Manhattan",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Immigrant education. Learned English as second language."
                ),
                EducationEntry(
                    institution: "City College of New York",
                    years: "pre-Revolution",
                    degree: "Incomplete (left for the war)",
                    notes: "Studied law. Too poor to continue after father's death."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Factory Worker", location: "New York", significance: "Radicalized by working conditions"),
                BiographyCareerEvent(era: "during the Depression", position: "Communist Party Organizer", location: "New York", significance: "Joined the underground movement"),
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Intelligence", location: "Nationwide", significance: "Built the first revolutionary spy networks"),
                BiographyCareerEvent(era: "during the Revolution", position: "Security Chief, Revolutionary Forces", location: "Mobile", significance: "Ran counter-intelligence during Civil War"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Director, Bureau of Public Safety", location: "Washington, DC", significance: "Second to Blackwood"),
                BiographyCareerEvent(era: "during the Purges", position: "Director, Bureau of Public Safety", location: "Washington, DC", significance: "Succeeded Blackwood (whom he destroyed)")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Aaron Wallace (né Walinsky)",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Tailor",
                    notes: "Jewish immigrant from Poland. Died of influenza. Changed family name to Wallace for assimilation.",
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
                        notes: "Killed in the Intervention War, fighting Canadian forces in the Pacific Northwest. His death broke something in Wallace.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "Ruth Abramson (née Wallace)",
                        relation: "Sister",
                        status: "Alive",
                        occupation: "School Administrator",
                        notes: "Lives in the Great Lakes Zone. They exchange letters on holidays. She is the only family he has left.",
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
                recruitedBy: "Earl Browder (CPUSA)",
                civilWarRole: "Built and ran the revolutionary intelligence apparatus. Identified and neutralized federal infiltrators. Saved the Revolution through information warfare.",
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
                        witnesses: ["mitchell", "edwards"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Steele Interrogation",
                        impact: "Personally oversaw the interrogation of General Steele. Never broke him. Signed the death warrant anyway.",
                        witnesses: ["edwards", "carter"]
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
                    fullContent: "Wallace's son David was assigned to a suicide mission in the Pacific Northwest—an assault on a fortified Canadian position that command knew was hopeless. Wallace could have intervened. He had the power. He chose not to, because pulling his son from danger would have looked like favoritism. David died, and Wallace has never forgiven himself. He keeps his son's last letter in his desk drawer.",
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
            id: "carter",
            fullName: "Raymond Elijah Carter",
            aliases: ["The General", "Old Ray", "The Lion of Chicago"],
            ageCategory: "middle-aged",
            birthPlace: "Macon, Georgia",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Segregated Public Schools, Macon",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Education ended at 14. Jim Crow South limited opportunities."
                ),
                EducationEntry(
                    institution: "Army Correspondence Courses",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Self-educated in military history and tactics while fighting"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "before the Revolution", position: "Sharecropper", location: "Georgia", significance: "Worked the fields until he was 18"),
                BiographyCareerEvent(era: "during the Depression", position: "Railroad Worker", location: "Chicago", significance: "Migrated north. Joined the Brotherhood."),
                BiographyCareerEvent(era: "during the Depression", position: "Labor Organizer", location: "Chicago", significance: "Organized Black workers despite threats"),
                BiographyCareerEvent(era: "during the Revolution", position: "Militia Commander", location: "Chicago", significance: "Led workers' militia in the Battle of Chicago"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "General, People's Army", location: "Various", significance: "Commander of the 3rd Revolutionary Corps"),
                BiographyCareerEvent(era: "after the Purges", position: "Deputy Commander, Armed Forces", location: "Washington, DC", significance: "Second-highest military position"),
                BiographyCareerEvent(era: "present day", position: "Deputy General Secretary", location: "Washington, DC", significance: "Moved into civilian leadership")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Elijah Carter",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Sharecropper",
                    notes: "Lynched by a white mob for 'disrespecting' a landlord. Raymond was sixteen.",
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
                        notes: "Named after Raymond's mother. Works in the Great Lakes Zone. Rarely visits.",
                        isSecret: false
                    )
                ],
                siblings: [
                    FamilyMember(
                        name: "James Carter",
                        relation: "Brother",
                        status: "Deceased",
                        occupation: "Worker",
                        notes: "Killed at Chicago. Raymond held him as he died.",
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
                beliefs: ["The Revolution liberated Black Americans", "Violence is sometimes necessary", "He has killed enough"]
            ),
            revolutionaryHistory: RevolutionaryHistory(
                joinedMovement: "during the Depression",
                recruitedBy: "Chicago IWW organizers",
                civilWarRole: "Commander, Black Workers' Militia. Led the defense of South Side Chicago for 90 days. Won the battle that broke the federal forces in the Midwest.",
                purgeExperience: "Testified at the Trial of the Thirty-Six—against General Steele, his former commander. He has never forgiven himself.",
                keyMoments: [
                    HistoricalMoment(
                        era: "before the Revolution",
                        event: "Father's Lynching",
                        impact: "Made Raymond a revolutionary. He swore the system would pay.",
                        witnesses: []
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Battle of Chicago",
                        impact: "90 days of street-to-street fighting. Lost his brother. Won the Midwest. Became a legend.",
                        witnesses: ["fletcher", "thompson", "bodine"]
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Retreat at Pittsburgh",
                        impact: "Ordered retreating soldiers shot to prevent a rout. Saved the battle. Killed his own men.",
                        witnesses: ["fletcher"]
                    ),
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Steele Trial",
                        impact: "Testified against Steele—his commander, his mentor. The guilt has never faded.",
                        witnesses: ["wallace", "fletcher", "mitchell"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "carter_shooting_retreat",
                    title: "The Pittsburgh Decimation",
                    fullContent: "During the Battle of Pittsburgh, Carter's forces were retreating in disorder. Federal troops were pursuing. To stop the rout, Carter ordered his officers to shoot any man who ran. Seventeen soldiers died by their own side's bullets. The line held. The battle was won. Carter has never admitted this in public. The soldiers who witnessed it are mostly dead. Fletcher knows. They never speak of it.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Fletcher's memory", "Survivors from the Pittsburgh campaign", "Carter's unpublished memoirs (if they exist)"],
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
                    quote: "The Revolution gave my people dignity. That's worth dying for. Whether it was worth killing for—I'm less sure.",
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
            physicalDescription: "Tall and powerfully built despite his fifty-plus years. Dark skin weathered by campaigns and sun. Gray at the temples now, giving him a distinguished air. Scars on his hands and one on his cheek from Chicago street fighting. Moves like a soldier still—purposeful, economical. Dress uniform immaculate; informal dress slightly rumpled. Eyes that have seen death and given it.",
            psychologicalProfile: "Carter is a soldier who became a politician because the Revolution needed him. He is most comfortable with troops, least comfortable in the Standing Committee. He genuinely believes the Revolution liberated Black Americans from Jim Crow tyranny, and that belief justifies much—but not everything. The Pittsburgh shootings haunt him. The Steele testimony destroys his sleep. He leads because he must, not because he wants to. He respects Mitchell as a necessary man. He fears Wallace because Wallace knows too much. He hopes his son will find a way to serve without becoming what he became. He is tired of war, tired of politics, tired of pretending the system is what they promised it would be. But he cannot stop serving—the Revolution made him, and he owes it everything."
        )
    }

    // MARK: - Eleanor Patterson Biography

    private func createPattersonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "patterson",
            fullName: "Eleanor Frances Patterson",
            aliases: ["Comrade Patterson", "The Iron Lady", "Ellie (childhood only)"],
            ageCategory: "middle-aged",
            birthPlace: "Boston, Massachusetts",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Boston Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Irish Catholic school. Excelled academically."
                ),
                EducationEntry(
                    institution: "Workers' Academy",
                    years: "pre-Revolution",
                    degree: "Certificate in Revolutionary Theory",
                    notes: "Top of her class. Attracted Fitzgerald's attention."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Youth League Organizer", location: "Boston", significance: "Recruited by Father Brennan (later denounced)"),
                BiographyCareerEvent(era: "during the Depression", position: "Party Secretary, Boston District", location: "Boston", significance: "Rose rapidly through Youth League"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissar of Education", location: "Washington, DC", significance: "First government position"),
                BiographyCareerEvent(era: "during the Purges", position: "Commissar of Education", location: "Washington, DC", significance: "Oversaw ideological curriculum"),
                BiographyCareerEvent(era: "years later", position: "Second Secretary", location: "Washington, DC", significance: "Number two in Party hierarchy")
            ],
            familyTree: FamilyTree(
                father: FamilyMember(
                    name: "Thomas Patterson",
                    relation: "Father",
                    status: "Deceased",
                    occupation: "Longshoreman",
                    notes: "Killed in the March on Washington. A genuine martyr.",
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
                        notes: "Lives in the Northeast Zone. They exchange Christmas cards. Nothing more.",
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
                civilWarRole: "Youth League organizer in Boston. Kept the young people motivated during the siege.",
                purgeExperience: "Denounced her mentor, Father Brennan, to survive. His children were sent to orphanages. She has never seen them again.",
                keyMoments: [
                    HistoricalMoment(
                        era: "during the Purges",
                        event: "The Brennan Denunciation",
                        impact: "Testified that Father Brennan was a Vatican spy. He wasn't. His execution saved her career.",
                        witnesses: ["wallace"]
                    ),
                    HistoricalMoment(
                        era: "during the Revolution",
                        event: "The Boston Siege",
                        impact: "Organized youth support during Red Betty Warren's strike. Learned how to inspire crowds.",
                        witnesses: []
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "patterson_brennan",
                    title: "The Brennan Lie",
                    fullContent: "Father Michael Brennan was a Catholic priest who secretly joined the revolutionary movement. He recruited young Eleanor Patterson, taught her to read Marx, gave her purpose. During the Religious Roundup during the Purges, Eleanor was pressured to denounce him as a Vatican agent. She did. She testified to conversations that never happened, meetings that never occurred. Brennan was executed. His three children—Margaret, Michael Jr., and Thomas—were sent to state orphanages. Eleanor never learned what happened to them. She has spent ten years trying not to find out. She collects poetry because Brennan taught her to love it. She never reads religious poetry—it hurts too much.",
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
            birthPlace: "Pittsburgh, Pennsylvania",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Pittsburgh Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Polish immigrant community school. Showed mathematical talent."
                ),
                EducationEntry(
                    institution: "University of Chicago",
                    years: "pre-Revolution",
                    degree: "Bachelor of Science, Economics",
                    notes: "Pre-purge university. Genuinely talented at mathematics."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Junior Economist", location: "Pittsburgh", significance: "First post-graduation job"),
                BiographyCareerEvent(era: "during the Revolution", position: "Statistical Analyst, Revolutionary Forces", location: "Mobile", significance: "Produced numbers that helped the cause"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Deputy Commissioner of Statistics", location: "Washington, DC", significance: "Rose through planning apparatus"),
                BiographyCareerEvent(era: "after the Purges", position: "Commissioner of Economic Statistics", location: "Washington, DC", significance: "Controlled the numbers"),
                BiographyCareerEvent(era: "present day", position: "Chairman, State Planning Commission", location: "Washington, DC", significance: "Apex of economic power")
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
                    notes: "Lives in a state apartment in Pittsburgh. Stefan sends money. Rarely visits.",
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
                        notes: "At the Party Academy in Washington. Stefan loves her genuinely—perhaps the only person he does.",
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
                        event: "The Kansas Famine Statistics",
                        impact: "Produced numbers showing no famine in Kansas. People were dying; his reports showed bumper harvests. He knew.",
                        witnesses: ["erickson", "carpenter"]
                    )
                ]
            ),
            darkSecrets: [
                DarkSecret(
                    id: "kowalski_famine",
                    title: "The Kansas Numbers",
                    fullContent: "During the Kansas Famine during the Purges, Kowalski's office produced agricultural statistics showing record grain production in the Plains Zone. In reality, collectivization quotas were killing people. Thousands died while his reports showed success. He knew. He produced the numbers anyway because the alternative was being accused of 'spreading defeatism.' Laura Erickson's brother was one of those who died. If she ever sees the original data Kowalski suppressed, she will know he helped kill her family.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Original data files (if they still exist)", "Erickson's private research", "Surviving witnesses from the Plains Zone"],
                    potentialConsequences: "Would expose Kowalski as complicit in mass death. Would make him an enemy of Erickson and anyone who lost family in Kansas.",
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

    // MARK: - Henderson Biography (abbreviated for space)

    private func createHendersonBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "henderson",
            fullName: "William Joseph Henderson",
            aliases: ["Comrade Henderson", "The Idealist", "True Bill"],
            ageCategory: "middle-aged",
            birthPlace: "Minneapolis, Minnesota",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Minneapolis Public Schools",
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
                BiographyCareerEvent(era: "during the Depression", position: "Union Organizer", location: "Minneapolis", significance: "Organized grain workers"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "Commissar of Labor Relations", location: "Washington, DC", significance: "Champion of workers' rights"),
                BiographyCareerEvent(era: "present day", position: "Commissar of Agriculture", location: "Washington, DC", significance: "Fights for realistic quotas")
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
                recruitedBy: "IWW organizers",
                civilWarRole: "Organized supply lines and worker support in the upper Midwest",
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

    // MARK: - Edwards Biography (abbreviated)

    private func createEdwardsBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "edwards",
            fullName: "Edward Thomas Williams (now Edwards)",
            aliases: ["Colonel Edwards", "The Ghost", "Williams (dead name)"],
            ageCategory: "middle-aged",
            birthPlace: "Baltimore, Maryland",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Baltimore Streets",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Mostly self-taught. Learned to survive."
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Courier", location: "Baltimore", significance: "Ran messages between cells"),
                BiographyCareerEvent(era: "during the Revolution", position: "Field Agent", location: "Behind Federal Lines", significance: "Sabotage and assassination"),
                BiographyCareerEvent(era: "at the Revolution's end", position: "BPS Officer", location: "Washington, DC", significance: "Wallace's protégé"),
                BiographyCareerEvent(era: "present day", position: "First Deputy Director", location: "Washington, DC", significance: "Wallace's likely successor")
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
                        notes: "Lives in the Great Lakes Zone under a different name. Edwards has not contacted her in 15 years.",
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
                recruitedBy: "Baltimore underground",
                civilWarRole: "Field operative behind federal lines. Sabotage, assassination, intelligence.",
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
                    fullContent: "Edwards has a sister, Sarah, living under an assumed name in the Great Lakes Zone. He has not contacted her in 15 years to protect her from his work. If enemies discovered her location, she could be used as leverage—or eliminated as a message. He would do almost anything to keep her safe.",
                    discoveryDifficulty: 8,
                    evidenceLocations: ["Pre-revolution Baltimore records", "Edwards' personal effects (hidden photograph)", "Great Lakes Zone identity registries"],
                    potentialConsequences: "Could be used to blackmail Edwards or force his compliance. If exposed, his sister's life would be in danger.",
                    whoKnows: ["wallace"],
                    canBeUsedFor: ["blackmail", "leverage", "alliance"]
                ),
                DarkSecret(
                    id: "edwards_cell_executions",
                    title: "The Cell Executions",
                    fullContent: "During the Revolution, Edwards executed three members of his own cell on Wallace's orders. One was almost certainly innocent—the real informer was discovered later, already dead. Edwards changed his name afterward. He still sees the innocent man's face in his dreams.",
                    discoveryDifficulty: 7,
                    evidenceLocations: ["Wallace's personal records", "Baltimore underground archives (if they survived)", "Edwards' pre-revolution identity documents"],
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

    // MARK: - Fletcher Biography (abbreviated)

    private func createFletcherBiography() -> CharacterBiography {
        return CharacterBiography(
            id: "fletcher",
            fullName: "James Arthur Fletcher",
            aliases: ["General Fletcher", "The Commissar"],
            ageCategory: "middle-aged",
            birthPlace: "Columbus, Ohio",
            isDeceased: false,
            education: [
                EducationEntry(
                    institution: "Columbus Public Schools",
                    years: "pre-Revolution",
                    degree: nil,
                    notes: "Middle-class education—not working-class as he claims"
                )
            ],
            careerTimeline: [
                BiographyCareerEvent(era: "during the Depression", position: "Revolutionary Organizer", location: "Ohio", significance: "Joined the movement"),
                BiographyCareerEvent(era: "during the Revolution", position: "Political Commissar", location: "Chicago", significance: "Attached to Steele's forces"),
                BiographyCareerEvent(era: "during the Purges", position: "Deputy Head, Political Directorate", location: "Washington, DC", significance: "Rose after Steele's fall"),
                BiographyCareerEvent(era: "present day", position: "Head, Political Directorate", location: "Washington, DC", significance: "Controls army ideology")
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
                civilWarRole: "Political commissar at Chicago. Held the line when others wavered.",
                purgeExperience: "Testified against Steele. His mentor. His friend. His guilt.",
                keyMoments: []
            ),
            darkSecrets: [
                DarkSecret(
                    id: "fletcher_false_origins",
                    title: "The Middle-Class Commissar",
                    fullContent: "Fletcher claims working-class origins—a railroad worker's son who knew hardship. The truth is his father was a railroad supervisor, his mother a schoolteacher. The family had a piano. He learned revolutionary theory from books, not from hunger. His entire political identity is built on a fabricated biography.",
                    discoveryDifficulty: 6,
                    evidenceLocations: ["Columbus public records", "Ohio school archives", "Railroad company employment records", "Fletcher family property deeds"],
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
                    whoKnows: ["wallace", "mitchell"],
                    canBeUsedFor: ["leverage", "alliance", "exposure"]
                )
            ],
            quotations: [
                CharacterQuote(
                    quote: "At Chicago, the commissars held the line. That's what political officers do. We hold the line.",
                    context: "Address to young officers",
                    era: "in recent years",
                    isPublic: true
                )
            ],
            physicalDescription: "A commanding presence in his fifties. Military bearing despite being a political officer. Gray hair, strong features, the body of a man who kept fit through discipline. Commands attention in any room. Speaks with absolute certainty.",
            psychologicalProfile: "Fletcher is a man who has built his entire identity on a foundation of lies. He claims working-class origins he doesn't have. He betrayed his mentor to survive. He tells himself stories to justify what he did. He is genuinely capable—a leader men follow—but he knows, deep down, that his career is built on betrayal and deception. He passes this legacy to his son, hoping the next generation will be cleaner than he was."
        )
    }
}
