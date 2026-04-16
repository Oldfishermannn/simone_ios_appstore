import Foundation
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    static let moodStyle = UTType(exportedAs: "com.simone.moodstyle")
}

struct MoodStyle: Identifiable, Equatable, Codable, Transferable {
    let id: String
    let name: String
    let prompt: String
    var promptWeight: Float = 1.0
    var category: StyleCategory = .lofi

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .moodStyle)
    }

    // MARK: - Preset Pool (10 categories × 6-8 styles)

    static let presets: [MoodStyle] = [
        // Lo-fi
        MoodStyle(id: "lofi-chill", name: "Lo-fi Chill", prompt: "Lo-fi hip hop with dusty vinyl crackle, mellow piano chords, and lazy drum patterns", category: .lofi),
        MoodStyle(id: "lofi-jazz", name: "Lo-fi Jazz", prompt: "Lo-fi jazz with warm Rhodes chords, vinyl hiss, tape-saturated bass, and brushed drums", category: .lofi),
        MoodStyle(id: "lofi-rain", name: "Lo-fi Rain", prompt: "Lo-fi beats with gentle rain ambience, soft piano melodies, and slow shuffling drums", category: .lofi),
        MoodStyle(id: "lofi-study", name: "Study Beats", prompt: "Calm lo-fi study music with soft piano loops, ambient pad textures, gentle vinyl hiss, and minimal percussion", category: .lofi),
        MoodStyle(id: "lofi-sunset", name: "Lo-fi Sunset", prompt: "Warm lo-fi with golden hour vibes, mellow guitar chords, soft Rhodes, and tape-warped beats", category: .lofi),
        MoodStyle(id: "lofi-anime", name: "Lo-fi Anime", prompt: "Japanese lo-fi with nostalgic piano melody, light chimes, warm bass, and cozy bedroom beats", category: .lofi),

        // Jazz
        MoodStyle(id: "night-jazz", name: "Night Jazz", prompt: "Late-night jazz trio with smoky tenor saxophone, walking upright bass, and brushed snare", category: .jazz),
        MoodStyle(id: "cafe-jazz", name: "Caf\u{00E9} Jazz", prompt: "Cozy caf\u{00E9} jazz with warm Rhodes piano, subtle acoustic guitar comping, and light bossa rhythm", category: .jazz),
        MoodStyle(id: "smooth-jazz", name: "Smooth Jazz", prompt: "Smooth jazz with silky soprano saxophone, warm electric piano chords, and gentle funk groove", category: .jazz),
        MoodStyle(id: "bossa-nova", name: "Bossa Nova", prompt: "Warm bossa nova with nylon guitar fingerpicking, light shaker percussion, and soft flute melody", category: .jazz),
        MoodStyle(id: "cool-jazz", name: "Cool Jazz", prompt: "Cool jazz with muted trumpet, soft vibraphone chords, gentle walking bass, and restrained brushwork", category: .jazz),
        MoodStyle(id: "modal-jazz", name: "Modal Jazz", prompt: "Modal jazz with open piano voicings, floating soprano sax melody, sparse bass, and contemplative drums", category: .jazz),
        MoodStyle(id: "jazz-waltz", name: "Jazz Waltz", prompt: "Elegant jazz waltz with flowing piano trio, gentle 3/4 swing, warm upright bass, and light cymbal ride", category: .jazz),

        // Blues
        MoodStyle(id: "slow-blues", name: "Slow Blues", prompt: "Slow blues with soulful electric guitar bends, warm organ chords, and shuffling brush drums", category: .blues),
        MoodStyle(id: "delta-blues", name: "Delta Blues", prompt: "Raw delta blues with acoustic slide guitar, stomping foot percussion, and gravelly harmonica", category: .blues),
        MoodStyle(id: "chicago-blues", name: "Chicago Blues", prompt: "Electric Chicago blues with overdriven guitar, walking bass, punchy horns, and driving shuffle beat", category: .blues),
        MoodStyle(id: "texas-blues", name: "Texas Blues", prompt: "Texas blues with bright Stratocaster tone, warm shuffle groove, bold horn section, and swinging feel", category: .blues),
        MoodStyle(id: "jazz-blues", name: "Jazz Blues", prompt: "Jazz-infused blues with sophisticated chord changes, warm guitar tone, walking bass, and swing rhythm", category: .blues),
        MoodStyle(id: "acoustic-blues", name: "Acoustic Blues", prompt: "Intimate acoustic blues with fingerpicked guitar, gentle harmonica fills, foot tapping, and raw emotion", category: .blues),

        // R&B
        MoodStyle(id: "smooth-rnb", name: "Smooth R&B", prompt: "Smooth R&B with silky synth pads, warm bass, gentle finger snaps, and lush vocal harmonies feel", category: .rnb),
        MoodStyle(id: "neo-soul", name: "Neo Soul", prompt: "Neo soul with warm Fender Rhodes, subtle wah guitar, deep bass groove, and organic drum patterns", category: .rnb),
        MoodStyle(id: "slow-jam", name: "Slow Jam", prompt: "Slow jam R&B with intimate piano chords, smooth bass, soft string pads, and gentle percussion", category: .rnb),
        MoodStyle(id: "motown", name: "Motown", prompt: "Classic Motown feel with punchy bass, bright piano comping, warm horn stabs, and driving tambourine", category: .rnb),
        MoodStyle(id: "gospel-soul", name: "Gospel Soul", prompt: "Gospel-influenced soul with rich organ chords, soaring piano runs, deep bass, and expressive drums", category: .rnb),
        MoodStyle(id: "late-night-rnb", name: "Late Night R&B", prompt: "Late night R&B with airy synths, soft 808 bass, distant reverbed keys, and minimal crisp snare", category: .rnb),

        // Rock
        MoodStyle(id: "soft-rock", name: "Soft Rock", prompt: "Soft rock with clean electric guitar arpeggios, warm acoustic strumming, and steady drum groove", category: .rock),
        MoodStyle(id: "indie-rock", name: "Indie Rock", prompt: "Indie rock with jangly guitars, driving bass, energetic drums, and shimmering reverb textures", category: .rock),
        MoodStyle(id: "post-rock", name: "Post Rock", prompt: "Post rock with layered ambient guitars, crescendo dynamics, delay-heavy textures, and epic builds", category: .rock),
        MoodStyle(id: "shoegaze", name: "Shoegaze", prompt: "Shoegaze with heavily distorted dreamy guitars, dense reverb layers, buried melodies, and hypnotic rhythms", category: .rock),
        MoodStyle(id: "surf-rock", name: "Surf Rock", prompt: "Surf rock with twangy reverb guitar, driving drums, warm bass, and bright energetic California vibe", category: .rock),
        MoodStyle(id: "classic-rock", name: "Classic Rock", prompt: "Classic rock with powerful guitar riffs, solid bass groove, driving drums, and warm analog tone", category: .rock),

        // Pop
        MoodStyle(id: "dream-pop", name: "Dream Pop", prompt: "Dream pop with hazy reverbed guitars, ethereal synth layers, soft vocals feel, and gentle beats", category: .pop),
        MoodStyle(id: "synth-pop", name: "Synth Pop", prompt: "Synth pop with bright analog synthesizers, catchy arpeggios, punchy drum machine, and warm pads", category: .pop),
        MoodStyle(id: "chill-pop", name: "Chill Pop", prompt: "Chill pop with warm acoustic guitar, light electronic production, airy melodies, and soft beats", category: .pop),
        MoodStyle(id: "indie-pop", name: "Indie Pop", prompt: "Indie pop with bouncy guitar strums, playful glockenspiel, light bass, and upbeat handclap rhythm", category: .pop),
        MoodStyle(id: "bedroom-pop", name: "Bedroom Pop", prompt: "Bedroom pop with lo-fi guitar, soft vocal harmonies feel, warm synth pads, and intimate drum machine", category: .pop),
        MoodStyle(id: "electro-pop", name: "Electro Pop", prompt: "Electro pop with bright plucky synths, four-on-the-floor kick, side-chain bass, and sparkling arpeggios", category: .pop),

        // Electronic
        MoodStyle(id: "synthwave", name: "Synthwave", prompt: "Synthwave with pulsing analog bass, shimmering arpeggiated synths, and driving electronic drums", category: .electronic),
        MoodStyle(id: "deep-house", name: "Deep House", prompt: "Deep house with rolling bassline, hypnotic hi-hat patterns, atmospheric vocal chops, and warm analog chords", category: .electronic),
        MoodStyle(id: "downtempo", name: "Downtempo", prompt: "Downtempo electronic with mellow beats, warm pad layers, subtle glitch textures, and deep bass", category: .electronic),
        MoodStyle(id: "chillwave", name: "Chillwave", prompt: "Chillwave with washed-out synth melodies, hazy tape effects, gentle beats, and nostalgic summer mood", category: .electronic),
        MoodStyle(id: "idm", name: "IDM", prompt: "Intelligent electronic music with intricate beat patterns, crystalline synth textures, and evolving atmospheres", category: .electronic),
        MoodStyle(id: "techno-minimal", name: "Minimal Techno", prompt: "Minimal techno with hypnotic kick drum, sparse hi-hats, subtle acid bassline, and slowly evolving filter sweeps", category: .electronic),
        MoodStyle(id: "trip-hop", name: "Trip Hop", prompt: "Trip hop with heavy downtempo beats, dark bass, scratchy vinyl samples, and moody atmospheric pads", category: .electronic),

        // Classical
        MoodStyle(id: "solo-piano", name: "Solo Piano", prompt: "Gentle solo piano with soft sustain pedal, flowing arpeggios, and intimate dynamics", category: .classical),
        MoodStyle(id: "string-quartet", name: "String Quartet", prompt: "Classical string quartet with rich cello melody, violin harmonies, and elegant chamber music dynamics", category: .classical),
        MoodStyle(id: "orchestral", name: "Orchestral", prompt: "Orchestral music with sweeping strings, warm woodwinds, French horn melody, and cinematic grandeur", category: .classical),
        MoodStyle(id: "baroque", name: "Baroque", prompt: "Baroque music with harpsichord arpeggios, elegant violin melody, cello continuo, and ornamental trills", category: .classical),
        MoodStyle(id: "romantic-piano", name: "Romantic Piano", prompt: "Romantic era piano with dramatic dynamics, rich chord voicings, flowing rubato, and passionate expression", category: .classical),
        MoodStyle(id: "minimalist", name: "Minimalist", prompt: "Minimalist classical with repeating piano patterns, slowly shifting harmonies, gentle strings, and meditative pulse", category: .classical),

        // Ambient
        MoodStyle(id: "space-drift", name: "Space Drift", prompt: "Cosmic ambient with slowly evolving granular textures, deep space reverb, and shimmering bell tones", category: .ambient),
        MoodStyle(id: "rain", name: "Rain", prompt: "Ambient soundscape with ethereal reverb-soaked pads, distant piano notes, and gentle rain texture", category: .ambient),
        MoodStyle(id: "forest", name: "Forest", prompt: "Nature-inspired ambient with wooden flute melody, soft string drones, and organic rustling textures", category: .ambient),
        MoodStyle(id: "ocean", name: "Ocean", prompt: "Oceanic ambient with deep swelling pads, gentle harp glissandos, and slow undulating rhythms", category: .ambient),
        MoodStyle(id: "arctic", name: "Arctic", prompt: "Frozen ambient with crystalline bell tones, icy reverb tails, distant wind textures, and glacial pad movement", category: .ambient),
        MoodStyle(id: "midnight", name: "Midnight", prompt: "Dark ambient with deep sub drones, sparse piano notes in vast reverb, distant metallic shimmer, and silence", category: .ambient),
        MoodStyle(id: "dawn", name: "Dawn", prompt: "Warm ambient with soft golden pads, gentle birdsong textures, slow rising strings, and peaceful flute", category: .ambient),

        // Folk
        MoodStyle(id: "acoustic-folk", name: "Acoustic Folk", prompt: "Warm acoustic folk with strummed steel-string guitar, gentle cello, and soft hand percussion", category: .folk),
        MoodStyle(id: "fingerstyle", name: "Fingerstyle", prompt: "Fingerstyle acoustic guitar with intricate picking patterns, warm resonance, and natural harmonics", category: .folk),
        MoodStyle(id: "campfire", name: "Campfire", prompt: "Campfire folk with gentle strumming, harmonica melody, soft clapping rhythm, and warm woody tone", category: .folk),
        MoodStyle(id: "celtic", name: "Celtic", prompt: "Celtic folk with tin whistle melody, gentle fiddle harmonies, bodhran rhythm, and flowing harp arpeggios", category: .folk),
        MoodStyle(id: "americana", name: "Americana", prompt: "Americana with warm pedal steel guitar, strummed acoustic, gentle mandolin, and steady brushed drums", category: .folk),
        MoodStyle(id: "indie-folk", name: "Indie Folk", prompt: "Indie folk with fingerpicked guitar, soft banjo accents, warm cello, and gentle tambourine rhythm", category: .folk),
    ]

    // MARK: - Random Selection

    /// Pick `count` random styles from the preset pool, excluding styles with the given IDs.
    static func randomSelection(count: Int, excluding: [String] = []) -> [MoodStyle] {
        let available = presets.filter { !excluding.contains($0.id) }
        guard !available.isEmpty else { return [] }
        let picks = min(count, available.count)
        return Array(available.shuffled().prefix(picks))
    }

    /// All presets in a given category.
    static func presets(for category: StyleCategory) -> [MoodStyle] {
        presets.filter { $0.category == category }
    }

    // MARK: - Generate New Styles

    /// Generate completely new styles by combining genre, mood, instruments, and texture.
    static func generateNewStyles(count: Int) -> [MoodStyle] {
        let genres = [
            "jazz", "ambient", "lo-fi hip hop", "bossa nova", "synthwave", "classical",
            "folk", "blues", "soul", "R&B", "trip-hop", "downtempo", "dream pop",
            "post-rock", "new age", "chillwave", "electronica", "baroque pop",
            "chamber music", "minimalism", "neo-soul", "acid jazz", "afrobeat",
            "world fusion", "flamenco", "Celtic", "reggae", "dub", "IDM",
            "shoegaze", "math rock", "progressive", "fusion jazz", "swing"
        ]

        let moods = [
            "warm", "melancholic", "dreamy", "energetic", "intimate", "ethereal",
            "dark", "uplifting", "nostalgic", "mysterious", "serene", "brooding",
            "playful", "contemplative", "romantic", "hypnotic", "bittersweet",
            "euphoric", "meditative", "cinematic", "wistful", "luminous",
            "haunting", "tender", "fierce", "delicate", "smoky", "crisp"
        ]

        let instruments = [
            "piano", "acoustic guitar", "electric guitar", "saxophone", "trumpet",
            "cello", "violin", "vibraphone", "Rhodes", "flute", "clarinet",
            "upright bass", "harp", "marimba", "kalimba", "synthesizer",
            "harmonica", "mandolin", "banjo", "organ", "accordion",
            "sitar", "oud", "koto", "steel drums", "tabla", "hang drum",
            "theremin", "pedal steel guitar", "oboe", "bassoon"
        ]

        let textures = [
            "lush reverb", "vinyl crackle", "tape saturation", "granular textures",
            "ambient pads", "arpeggiated patterns", "subtle distortion", "shimmer delay",
            "soft percussion", "deep sub bass", "airy harmonics", "rhythmic pulses",
            "layered drones", "staccato plucks", "legato swells", "filtered sweeps",
            "bitcrushed glitches", "organic rustling", "bell-like tones", "chorus effects"
        ]

        var results: [MoodStyle] = []
        for _ in 0..<count {
            let genre = genres.randomElement()!
            let mood = moods.randomElement()!
            let inst1 = instruments.randomElement()!
            var inst2 = instruments.randomElement()!
            while inst2 == inst1 { inst2 = instruments.randomElement()! }
            let texture = textures.randomElement()!

            let id = "gen-\(UUID().uuidString.prefix(8).lowercased())"
            let name = "\(mood.capitalized) \(genre.capitalized)"
            let prompt = "\(mood.capitalized) \(genre) with expressive \(inst1), \(inst2) accents, and \(texture)"

            results.append(MoodStyle(id: id, name: name, prompt: prompt))
        }
        return results
    }
}
