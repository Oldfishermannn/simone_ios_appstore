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

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .moodStyle)
    }

    // MARK: - Preset Pool

    static let presets: [MoodStyle] = [
        MoodStyle(
            id: "lofi-chill",
            name: "Lo-fi Chill",
            prompt: "Lo-fi hip hop with dusty vinyl crackle, mellow piano chords, and lazy drum patterns"
        ),
        MoodStyle(
            id: "night-jazz",
            name: "Night Jazz",
            prompt: "Late-night jazz trio with smoky tenor saxophone, walking upright bass, and brushed snare"
        ),
        MoodStyle(
            id: "soft-piano",
            name: "Soft Piano",
            prompt: "Gentle solo piano with soft sustain pedal, flowing arpeggios, and intimate dynamics"
        ),
        MoodStyle(
            id: "sunset-bossa",
            name: "Sunset Bossa",
            prompt: "Warm bossa nova with nylon guitar fingerpicking, light shaker percussion, and soft flute melody"
        ),
        MoodStyle(
            id: "neon-drive",
            name: "Neon Drive",
            prompt: "Synthwave with pulsing analog bass, shimmering arpeggiated synths, and driving electronic drums"
        ),
        MoodStyle(
            id: "rainy-ambient",
            name: "Rainy Ambient",
            prompt: "Ambient soundscape with ethereal reverb-soaked pads, distant piano notes, and gentle rain texture"
        ),
        MoodStyle(
            id: "cafe-jazz",
            name: "Caf\u{00E9} Jazz",
            prompt: "Cozy café jazz with warm Rhodes piano, subtle acoustic guitar comping, and light bossa rhythm"
        ),
        MoodStyle(
            id: "dark-groove",
            name: "Dark Groove",
            prompt: "Dark electronic groove with deep sub bass, minimal techno percussion, and haunting pad layers"
        ),
        MoodStyle(
            id: "morning-light",
            name: "Morning Light",
            prompt: "Bright acoustic morning music with fingerstyle guitar, soft marimba, and airy flute harmonics"
        ),
        MoodStyle(
            id: "space-drift",
            name: "Space Drift",
            prompt: "Cosmic ambient with slowly evolving granular textures, deep space reverb, and shimmering bell tones"
        ),
        MoodStyle(
            id: "warm-acoustic",
            name: "Warm Acoustic",
            prompt: "Warm acoustic folk with strummed steel-string guitar, gentle cello, and soft hand percussion"
        ),
        MoodStyle(
            id: "deep-focus",
            name: "Deep Focus",
            prompt: "Minimal concentration music with steady ambient drone, sparse piano notes, and subtle binaural texture"
        ),
        MoodStyle(
            id: "moonlight-sonata",
            name: "Moonlight Sonata",
            prompt: "Classical-inspired piano with expressive dynamics, rich harmonic progressions, and romantic legato phrasing"
        ),
        MoodStyle(
            id: "street-funk",
            name: "Street Funk",
            prompt: "Tight funk groove with slap bass, choppy rhythm guitar, punchy horn stabs, and crisp drum breaks"
        ),
        MoodStyle(
            id: "ocean-drift",
            name: "Ocean Drift",
            prompt: "Oceanic ambient with deep swelling pads, gentle harp glissandos, and slow undulating rhythms"
        ),
        MoodStyle(
            id: "crystal-clear",
            name: "Crystal Clear",
            prompt: "Pristine electronic music with crystalline bell synths, clean digital arpeggios, and spacious reverb"
        ),
        MoodStyle(
            id: "velvet-lounge",
            name: "Velvet Lounge",
            prompt: "Smooth lounge music with silky vibraphone, warm upright bass, and intimate vocal-less jazz quartet feel"
        ),
        MoodStyle(
            id: "misty-forest",
            name: "Misty Forest",
            prompt: "Nature-inspired ambient with wooden flute melody, soft string drones, and organic rustling textures"
        ),
        MoodStyle(
            id: "golden-hour",
            name: "Golden Hour",
            prompt: "Dreamy indie with warm tape-saturated guitars, lush reverb swells, and gentle shuffling drums"
        ),
        MoodStyle(
            id: "midnight-pulse",
            name: "Midnight Pulse",
            prompt: "Deep house with rolling bassline, hypnotic hi-hat patterns, atmospheric vocal chops, and warm analog chords"
        ),
    ]

    // MARK: - Random Selection

    /// Pick `count` random styles from the preset pool, excluding styles with the given IDs.
    static func randomSelection(count: Int, excluding: [String] = []) -> [MoodStyle] {
        let available = presets.filter { !excluding.contains($0.id) }
        guard !available.isEmpty else { return [] }
        let picks = min(count, available.count)
        return Array(available.shuffled().prefix(picks))
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
