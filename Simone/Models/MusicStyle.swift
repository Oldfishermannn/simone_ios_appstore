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

    // MARK: - Preset Pool (10 categories × ≥10 styles, 103 total)

    static let presets: [MoodStyle] = [
        // MARK: Lo-fi (10) — v1.3.0 rework (CEO 2026-04-23). Strip abstract
        // moods ("golden hour vibes", "dim neon atmosphere"), swap vocal-feel
        // trick for airy pads (Lo-fi bed is too thin to hold vocal phonemes
        // — was generating speech fragments), front-load rain with "throughout".
        MoodStyle(id: "lofi-chill", name: "Lo-fi Chill", prompt: "Lo-fi hip hop with dusty vinyl crackle, mellow piano chords, and lazy drum patterns", category: .lofi),
        MoodStyle(id: "lofi-jazz", name: "Lo-fi Jazz", prompt: "Lo-fi jazz with warm Rhodes chords, vinyl hiss, tape-saturated bass, and brushed drums", category: .lofi),
        MoodStyle(id: "lofi-rain", name: "Lo-fi Rain", prompt: "Prominent rain sounds pattering throughout in the foreground, continuous raindrops, lo-fi beats with mellow piano quietly underneath, tape-warped bass, and slow shuffling drums", category: .lofi),
        MoodStyle(id: "lofi-study", name: "Study Beats", prompt: "Calm lo-fi study music with soft piano loops, ambient pad textures, gentle vinyl hiss, and minimal percussion", category: .lofi),
        MoodStyle(id: "lofi-sunset", name: "Lo-fi Sunset", prompt: "Warm lo-fi with mellow electric guitar, soft Rhodes chords, warm analog bass, and tape-warped lazy drums", category: .lofi),
        MoodStyle(id: "lofi-anime", name: "Lo-fi Anime", prompt: "Japanese lo-fi with nostalgic piano melody, light glockenspiel chimes, warm bass, and cozy bedroom beats", category: .lofi),
        MoodStyle(id: "bedroom-pop", name: "Bedroom Pop", prompt: "Bedroom pop with lo-fi clean guitar, airy synth pads, warm analog bass, and intimate drum machine", category: .lofi),
        MoodStyle(id: "chill-pop", name: "Chill Pop", prompt: "Chill pop with warm acoustic guitar, soft Rhodes keys, gentle electric piano melody, and laid-back drum machine", category: .lofi),
        MoodStyle(id: "lofi-tokyo-night", name: "Tokyo Night", prompt: "Late night Tokyo lo-fi with mellow electric piano, tape-hissed bass, distant city hum, and quiet drum machine", category: .lofi),
        MoodStyle(id: "lofi-morning-coffee", name: "Morning Coffee", prompt: "Morning lo-fi with warm acoustic guitar loops, soft Rhodes chords, cassette warmth, and slow lazy beats", category: .lofi),

        // MARK: Jazz (10) — v1.3.0 rework (CEO 2026-04-23). Café Jazz dropped
        // "bossa rhythm" (collided with Bossa Nova entry) — now Rhodes+guitar+brushes.
        MoodStyle(id: "night-jazz", name: "Night Jazz", prompt: "Late-night jazz trio with smoky tenor saxophone, walking upright bass, and brushed snare", category: .jazz),
        MoodStyle(id: "cafe-jazz", name: "Caf\u{00E9} Jazz", prompt: "Cozy caf\u{00E9} jazz with warm Rhodes piano, soft acoustic guitar comping, gentle brushed drums, and subtle upright bass", category: .jazz),
        MoodStyle(id: "smooth-jazz", name: "Smooth Jazz", prompt: "Smooth jazz with silky soprano saxophone, warm electric piano chords, and gentle funk groove", category: .jazz),
        MoodStyle(id: "bossa-nova", name: "Bossa Nova", prompt: "Warm bossa nova with nylon guitar fingerpicking, light shaker percussion, and soft flute melody", category: .jazz),
        MoodStyle(id: "cool-jazz", name: "Cool Jazz", prompt: "Cool jazz with muted trumpet, soft vibraphone chords, gentle walking bass, and restrained brushwork", category: .jazz),
        MoodStyle(id: "modal-jazz", name: "Modal Jazz", prompt: "Modal jazz with open piano voicings, floating soprano sax melody, sparse bass, and contemplative drums", category: .jazz),
        MoodStyle(id: "jazz-waltz", name: "Jazz Waltz", prompt: "Elegant jazz waltz with flowing piano trio, gentle 3/4 swing, warm upright bass, and light cymbal ride", category: .jazz),
        MoodStyle(id: "swing-jazz", name: "Swing", prompt: "Classic swing jazz with punchy big band horns, steady walking bass, snappy ride cymbal, and lively piano comping", category: .jazz),
        MoodStyle(id: "jazz-ballad", name: "Jazz Ballad", prompt: "Slow jazz ballad with tender tenor saxophone, spacious piano voicings, warm upright bass, and soft brushes", category: .jazz),
        MoodStyle(id: "hard-bop", name: "Hard Bop", prompt: "Hard bop quintet with urgent trumpet and sax unison lines, driving walking bass, and punchy ride-heavy drums", category: .jazz),

        // MARK: R&B (10) — v1.3.0 rework (CEO 2026-04-23). Smooth R&B stripped
        // of sax to de-collide with Quiet Storm; airy vocal pad kept per C-plan
        // (R&B bed has drums+bass to anchor vocal-feel texture, unlike Lo-fi).
        MoodStyle(id: "smooth-rnb", name: "Smooth R&B", prompt: "Smooth R&B with silky synth pads, warm bass, crisp finger snaps, and soft airy vocal pad", category: .rnb),
        MoodStyle(id: "neo-soul", name: "Neo Soul", prompt: "Neo soul with warm Fender Rhodes, subtle wah guitar, deep bass groove, and organic drum patterns", category: .rnb),
        MoodStyle(id: "slow-jam", name: "Slow Jam", prompt: "Slow jam R&B with intimate piano chords, smooth bass, soft string pads, and gentle percussion", category: .rnb),
        MoodStyle(id: "motown", name: "Motown", prompt: "Classic Motown feel with punchy bass, bright piano comping, warm horn stabs, and driving tambourine", category: .rnb),
        MoodStyle(id: "gospel-soul", name: "Gospel Soul", prompt: "Gospel-influenced soul with rich organ chords, soaring piano runs, deep bass, and expressive drums", category: .rnb),
        MoodStyle(id: "quiet-storm", name: "Quiet Storm", prompt: "Quiet storm R&B with lush Rhodes chords, slow bass groove, silky sax fills, and mellow drum machine", category: .rnb),
        MoodStyle(id: "90s-rnb", name: "90s R&B", prompt: "90s R&B with warm synth pads, smooth bass lines, snapping rim-shot drums, and subtle guitar licks", category: .rnb),
        MoodStyle(id: "funky-soul", name: "Funky Soul", prompt: "Funky soul with punchy wah guitar, driving bass groove, crisp drums, and warm horn stabs", category: .rnb),
        MoodStyle(id: "contemporary-rnb", name: "Contemporary R&B", prompt: "Contemporary R&B with glossy Rhodes keys, 808 sub bass, crisp snaps, and airy vocal pad textures", category: .rnb),
        MoodStyle(id: "rnb-groove", name: "R&B Groove", prompt: "Mid-tempo R&B groove with thumping bass, tight drum pocket, warm guitar chords, and string pad washes", category: .rnb),

        // MARK: Rock (10) — v1.3.0 CEO rebalance 2026-04-23. 6 blues was
        // drowning the channel's rock identity; kept 2 flagship blues (electric
        // Slow + acoustic Delta) and added Garage + Alt to round out rock range.
        // Dropped: chicago-blues, texas-blues, jazz-blues, acoustic-blues.
        MoodStyle(id: "soft-rock", name: "Soft Rock", prompt: "Soft rock with clean electric guitar arpeggios, warm acoustic strumming, and steady drum groove", category: .rock),
        MoodStyle(id: "indie-rock", name: "Indie Rock", prompt: "Indie rock with jangly guitars, driving bass, energetic drums, and shimmering reverb textures", category: .rock),
        MoodStyle(id: "post-rock", name: "Post Rock", prompt: "Post rock with layered ambient guitars, crescendo dynamics, delay-heavy textures, and epic builds", category: .rock),
        MoodStyle(id: "shoegaze", name: "Shoegaze", prompt: "Shoegaze with heavily distorted dreamy guitars, dense reverb layers, buried melodies, and hypnotic rhythms", category: .rock),
        MoodStyle(id: "surf-rock", name: "Surf Rock", prompt: "Surf rock with twangy reverb guitar, driving punchy drums, warm bass, and bright energetic tone", category: .rock),
        MoodStyle(id: "classic-rock", name: "Classic Rock", prompt: "Classic rock with powerful guitar riffs, solid bass groove, driving drums, and warm analog tone", category: .rock),
        MoodStyle(id: "garage-rock", name: "Garage Rock", prompt: "Garage rock with fuzzed-out electric guitar, raw driving drums, overdriven bass, and gritty tambourine", category: .rock),
        MoodStyle(id: "alt-rock", name: "Alt Rock", prompt: "90s alt rock with crunchy distorted guitars, punchy bass groove, driving drums, and melodic clean guitar leads", category: .rock),
        MoodStyle(id: "slow-blues", name: "Slow Blues", prompt: "Slow blues with soulful electric guitar bends, warm organ chords, and shuffling brush drums", category: .rock),
        MoodStyle(id: "delta-blues", name: "Delta Blues", prompt: "Raw delta blues with acoustic slide guitar, stomping foot percussion, and gravelly harmonica", category: .rock),

        // MARK: Electronic (10) — v1.3.0 rework (CEO 2026-04-23). Deep House
        // lost "vocal chops" (C-plan, chops are Lyria's weak spot). Chillwave/IDM
        // stripped abstract moods. Synth Pop pulled to 80s sequencer,
        // Electro Pop to modern pop sheen to stop the collision.
        MoodStyle(id: "synthwave", name: "Synthwave", prompt: "Synthwave with pulsing analog bass, shimmering arpeggiated synths, and driving electronic drums", category: .electronic),
        MoodStyle(id: "deep-house", name: "Deep House", prompt: "Deep house with rolling bassline, hypnotic hi-hat patterns, warm analog chords, and atmospheric pad textures", category: .electronic),
        MoodStyle(id: "downtempo", name: "Downtempo", prompt: "Downtempo electronic with mellow beats, warm pad layers, subtle glitch textures, and deep bass", category: .electronic),
        MoodStyle(id: "chillwave", name: "Chillwave", prompt: "Chillwave with washed-out synth melodies, hazy tape effects, gentle mellow beats, and soft analog pads", category: .electronic),
        MoodStyle(id: "idm", name: "IDM", prompt: "Intelligent electronic music with intricate broken beat patterns, crystalline synth textures, granular glitches, and deep sub bass", category: .electronic),
        MoodStyle(id: "techno-minimal", name: "Minimal Techno", prompt: "Minimal techno with hypnotic kick drum, sparse hi-hats, subtle acid bassline, and slowly evolving filter sweeps", category: .electronic),
        MoodStyle(id: "synth-pop", name: "Synth Pop", prompt: "80s synth pop with bright sequenced analog synths, punchy drum machine, mellow arpeggios, and warm bass line", category: .electronic),
        MoodStyle(id: "electro-pop", name: "Electro Pop", prompt: "Modern electro pop with glossy plucky synths, four-on-the-floor kick, side-chain pumping bass, and sparkling high arpeggios", category: .electronic),
        MoodStyle(id: "drum-and-bass", name: "Drum & Bass", prompt: "Rolling drum and bass with fast breakbeat drums, deep sub bass, atmospheric pads, and clean synth stabs", category: .electronic),
        MoodStyle(id: "acid-techno", name: "Acid Techno", prompt: "Acid techno with squelchy 303 bassline, pulsing four-on-the-floor kick, crisp hi-hats, and evolving filter modulation", category: .electronic),

        // MARK: Ambient (10) — v1.3.0: rain-weighted rework + 3 non-rain quiet
        // additions (CEO 2026-04-23). 4 rain scenes + 3 classic ambient + 3 new
        // quiet (Night Window matches visualizer, Snowfall/Slow Breath for
        // meditative range). Rain prompts front-load the rain keyword with
        // "throughout" to keep Lyria's rain texture audible; avoid poetic
        // abstractions ("rainfall texture", "wet hush") and negations
        // ("no thunder") — Lyria parses direct nouns better than moods.
        MoodStyle(id: "ambient-eno", name: "Ambient", prompt: "Eno-style ambient with slowly evolving pad layers, deep reverb tails, soft drones, and spacious silence between notes", category: .ambient),
        MoodStyle(id: "ambient-drone", name: "Drone", prompt: "Deep meditative drone with overlapping sustained tones, subtle harmonic shifts, and organic texture movement", category: .ambient),
        MoodStyle(id: "neoclassical", name: "Neoclassical", prompt: "Neoclassical ambient with sparse piano, bowed cello, warm tape saturation, and intimate room reverb", category: .ambient),
        MoodStyle(id: "ambient-rain", name: "Rain Room", prompt: "Prominent heavy rainfall sounds outside a window throughout in the foreground, continuous loud raindrops on rooftop, slow sparse minor-key piano quietly underneath, dark hushed ambient pad drone in the background, somber still and contemplative", category: .ambient),
        MoodStyle(id: "ambient-window-rain", name: "Rain on Window", prompt: "Prominent raindrops tapping loudly on glass throughout in the foreground, continuous close intimate rain sounds hitting window, slow sparse minor-key piano quietly underneath, dark hushed warm pad drone in the background, soft tape warmth, somber still and contemplative", category: .ambient),
        MoodStyle(id: "ambient-drizzle", name: "Drizzle", prompt: "Prominent continuous light drizzle rainfall sounds throughout in the foreground, soft constant raindrop patter, slow minor-key cello drone quietly underneath, dark sparse piano, hushed and somber", category: .ambient),
        MoodStyle(id: "ambient-after-rain", name: "After Rain", prompt: "Prominent lingering rain drips and slow wet drops on leaves throughout in the foreground, continuous gentle post-storm drizzle, slow quiet minor-key pad swells underneath, a single distant piano note, somber still and contemplative", category: .ambient),
        MoodStyle(id: "ambient-night-window", name: "Night Window", prompt: "Distant city hum through a night window throughout, slow ambient pads, muffled sub bass, sparse piano notes, and quiet tape warmth", category: .ambient),
        MoodStyle(id: "ambient-snowfall", name: "Snowfall", prompt: "Hushed quiet throughout, dark ambient pad drone, slow minor-key bowed strings, sparse delicate bell tones, somber and still", category: .ambient),
        MoodStyle(id: "ambient-slow-breath", name: "Slow Breath", prompt: "Slow meditative breathing pulse throughout, deep minor-key sustained drone, dark warm cello, sparse piano, hushed and contemplative", category: .ambient),

        // MARK: Midnight (10)
        MoodStyle(id: "trip-hop", name: "Trip Hop", prompt: "Trip hop with heavy downtempo beats, dark bass, scratchy vinyl samples, and moody atmospheric pads", category: .midnight),
        MoodStyle(id: "late-night-rnb", name: "Late Night R&B", prompt: "Late night R&B with airy synths, soft 808 bass, distant reverbed keys, and minimal crisp snare", category: .midnight),
        MoodStyle(id: "space-drift", name: "Space Drift", prompt: "Cosmic ambient with slowly evolving granular textures, deep space reverb, and shimmering bell tones", category: .midnight),
        MoodStyle(id: "ocean", name: "Ocean", prompt: "Oceanic ambient with deep swelling pads, gentle harp glissandos, and slow undulating rhythms", category: .midnight),
        MoodStyle(id: "midnight", name: "Midnight", prompt: "Dark ambient with deep sub drones, sparse piano notes in vast reverb, distant metallic shimmer, and silence", category: .midnight),
        MoodStyle(id: "noir-city", name: "Noir City", prompt: "Noir city jazz-ambient with distant muted trumpet, deep upright bass, reverb-soaked piano, and faint rain texture", category: .midnight),
        MoodStyle(id: "neon-rain", name: "Neon Rain", prompt: "Neon-lit midnight with deep sub bass, smoky saxophone, reverb-washed electric piano, and wet pavement ambience", category: .midnight),
        MoodStyle(id: "smoke-lounge", name: "Smoke Lounge", prompt: "Smoky after-hours lounge with muted trumpet, brushed drums, warm upright bass, and dim reverb piano", category: .midnight),
        MoodStyle(id: "after-hours", name: "After Hours", prompt: "After-hours downtempo with slow bass groove, distant Rhodes, breathy saxophone, and soft tape hiss", category: .midnight),
        MoodStyle(id: "urban-solitude", name: "Urban Solitude", prompt: "Urban midnight solitude with sparse piano chords, distant city ambience, slow sub bass, and faint reverb guitar", category: .midnight),

        // MARK: Cafe (11)
        MoodStyle(id: "solo-piano", name: "Solo Piano", prompt: "Gentle solo piano with soft sustain pedal, flowing arpeggios, and intimate dynamics", category: .cafe),
        MoodStyle(id: "romantic-piano", name: "Romantic Piano", prompt: "Romantic era piano with dramatic dynamics, rich chord voicings, flowing rubato, and passionate expression", category: .cafe),
        MoodStyle(id: "baroque", name: "Baroque", prompt: "Baroque music with harpsichord arpeggios, elegant violin melody, cello continuo, and ornamental trills", category: .cafe),
        MoodStyle(id: "acoustic-folk", name: "Acoustic Folk", prompt: "Warm acoustic folk with strummed steel-string guitar, gentle cello, and soft hand percussion", category: .cafe),
        MoodStyle(id: "fingerstyle", name: "Fingerstyle", prompt: "Fingerstyle acoustic guitar with intricate picking patterns, warm resonance, and natural harmonics", category: .cafe),
        MoodStyle(id: "americana", name: "Americana", prompt: "Americana with warm pedal steel guitar, strummed acoustic, gentle mandolin, and steady brushed drums", category: .cafe),
        MoodStyle(id: "indie-folk", name: "Indie Folk", prompt: "Indie folk with fingerpicked guitar, soft banjo accents, warm cello, and gentle tambourine rhythm", category: .cafe),
        MoodStyle(id: "parisian-cafe", name: "Parisian Caf\u{00E9}", prompt: "Parisian caf\u{00E9} with accordion melody, nylon guitar rhythm, light brushed drums, and warm upright bass", category: .cafe),
        MoodStyle(id: "bookstore-afternoon", name: "Bookstore Afternoon", prompt: "Quiet bookstore afternoon with solo piano, warm cello, soft flute, and gentle acoustic guitar fingerpicking", category: .cafe),
        MoodStyle(id: "sunday-brunch", name: "Sunday Brunch", prompt: "Sunday brunch with nylon guitar, light brushed drums, warm upright bass, and cheerful soprano sax", category: .cafe),
        MoodStyle(id: "indie-pop", name: "Indie Pop", prompt: "Indie pop with bouncy guitar strums, playful glockenspiel, light bass, and upbeat handclap rhythm", category: .cafe),

        // MARK: Rainy (10)
        MoodStyle(id: "rain", name: "Rain", prompt: "Ambient soundscape with ethereal reverb-soaked pads, distant piano notes, and gentle rain texture", category: .rainy),
        MoodStyle(id: "rainy-window", name: "Rainy Window", prompt: "Quiet rainy window with soft Rhodes chords, distant thunder, gentle piano melody, and steady rain pattering", category: .rainy),
        MoodStyle(id: "monsoon", name: "Monsoon", prompt: "Monsoon meditation with deep ambient pads, heavy rain layers, distant thunder, and slow cello drones", category: .rainy),
        MoodStyle(id: "drizzle-piano", name: "Drizzle Piano", prompt: "Gentle drizzle with intimate solo piano, soft sustain, light rain ambience, and minimal reverb", category: .rainy),
        MoodStyle(id: "thunder-distant", name: "Distant Thunder", prompt: "Distant thunder with slow ambient pads, muffled low piano, soft rain, and occasional low rumble", category: .rainy),
        MoodStyle(id: "petrichor", name: "Petrichor", prompt: "Post-rain earthiness with warm Rhodes, soft strings, gentle pattering texture, and breathy flute", category: .rainy),
        MoodStyle(id: "rainy-commute", name: "Rainy Commute", prompt: "Rainy commute with mellow lo-fi beats, reverbed Rhodes, rain texture, and muted bass", category: .rainy),
        MoodStyle(id: "after-the-storm", name: "After the Storm", prompt: "After the storm with airy pads, soft piano, receding rain, and gentle strings emerging", category: .rainy),
        MoodStyle(id: "rainy-lounge", name: "Rainy Lounge", prompt: "Rainy lounge jazz with warm Rhodes, brushed drums, soft saxophone, and faint window rain", category: .rainy),
        MoodStyle(id: "grey-morning", name: "Grey Morning", prompt: "Grey morning with slow piano, warm cello, soft ambient pads, and gentle drizzle texture", category: .rainy),

        // MARK: Library (10)
        MoodStyle(id: "string-quartet", name: "String Quartet", prompt: "Classical string quartet with rich cello melody, violin harmonies, and elegant chamber music dynamics", category: .library),
        MoodStyle(id: "orchestral", name: "Orchestral", prompt: "Orchestral music with sweeping strings, warm woodwinds, French horn melody, and cinematic grandeur", category: .library),
        MoodStyle(id: "minimalist", name: "Minimalist", prompt: "Minimalist classical with repeating piano patterns, slowly shifting harmonies, gentle strings, and meditative pulse", category: .library),
        MoodStyle(id: "campfire", name: "Campfire", prompt: "Campfire folk with gentle strumming, harmonica melody, soft clapping rhythm, and warm woody tone", category: .library),
        MoodStyle(id: "celtic", name: "Celtic", prompt: "Celtic folk with tin whistle melody, gentle fiddle harmonies, bodhran rhythm, and flowing harp arpeggios", category: .library),
        MoodStyle(id: "forest", name: "Forest", prompt: "Nature-inspired ambient with wooden flute melody, soft string drones, and organic rustling textures", category: .library),
        MoodStyle(id: "dawn", name: "Dawn", prompt: "Warm ambient with soft golden pads, gentle birdsong textures, slow rising strings, and peaceful flute", category: .library),
        MoodStyle(id: "reading-nook", name: "Reading Nook", prompt: "Quiet reading nook with solo piano, soft cello, minimal string textures, and warm room tone", category: .library),
        MoodStyle(id: "study-hall", name: "Study Hall", prompt: "Focused study hall with repeating piano figures, soft string pads, sparse woodwinds, and steady calm pulse", category: .library),
        MoodStyle(id: "old-manuscripts", name: "Old Manuscripts", prompt: "Old manuscripts with harpsichord, warm cello, gentle recorder, and delicate chamber ensemble", category: .library),

        // MARK: Dreamscape (10)
        MoodStyle(id: "dream-pop", name: "Dream Pop", prompt: "Dream pop with hazy reverbed guitars, ethereal synth layers, soft vocals feel, and gentle beats", category: .dreamscape),
        MoodStyle(id: "arctic", name: "Arctic", prompt: "Frozen ambient with crystalline bell tones, icy reverb tails, distant wind textures, and glacial pad movement", category: .dreamscape),
        MoodStyle(id: "starry-night", name: "Starry Night", prompt: "Starry night with shimmering synth pads, soft bell tones, slow string swells, and distant chimes", category: .dreamscape),
        MoodStyle(id: "lucid-dream", name: "Lucid Dream", prompt: "Lucid dream with floating granular textures, reverb guitar swells, soft bell harmonics, and slow breathing pulse", category: .dreamscape),
        MoodStyle(id: "nebula-journey", name: "Nebula Journey", prompt: "Nebula journey with deep space pads, shimmering harp glissandos, soft piano, and slow evolving drones", category: .dreamscape),
        MoodStyle(id: "cosmic-lullaby", name: "Cosmic Lullaby", prompt: "Cosmic lullaby with gentle celesta, warm synth pads, slow strings, and soft twinkling bells", category: .dreamscape),
        MoodStyle(id: "weightless", name: "Weightless", prompt: "Weightless ambient with slow pad swells, delicate piano notes, distant chimes, and meditative stillness", category: .dreamscape),
        MoodStyle(id: "aurora", name: "Aurora", prompt: "Aurora with shimmering bell synths, slow string pads, soft harp arpeggios, and ethereal wind textures", category: .dreamscape),
        MoodStyle(id: "ethereal-drift", name: "Ethereal Drift", prompt: "Ethereal drift with granular pads, reverb piano, soft breathy flute, and slow bell resonance", category: .dreamscape),
        MoodStyle(id: "crystal-cave", name: "Crystal Cave", prompt: "Crystal cave with glassy bell tones, soft reverb piano, slow strings, and gentle water droplet textures", category: .dreamscape),
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
