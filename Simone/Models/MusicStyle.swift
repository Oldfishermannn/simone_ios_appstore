import Foundation

struct MoodStyle: Identifiable, Equatable, Codable {
    let id: String
    let name: String
    let prompt: String
    var promptWeight: Float = 1.0

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
}
