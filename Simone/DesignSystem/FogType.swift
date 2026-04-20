import SwiftUI

/// v1.2.1 — Fog typography scale (placeholder; full scale lands in Package #2).
///
/// Six-step modular scale:
///   display-lg 44pt  · Unbounded Medium · tracking -0.02em  · immersive title
///   display-sm 28pt  · Unbounded Medium · tracking -0.015em · channel card name (+2pt from 26)
///   title      20pt  · Fraunces SemiBold · tracking 0        · section headers
///   body       15pt  · Fraunces Regular  · tracking +0.005em · long form
///   meta       13pt  · Archivo Regular   · tracking +0.03em  · time / counts
///   label-caps 11pt  · Archivo Medium    · tracking +0.14em  · LOCK / EVOLVE / BYOK
///
/// Package #1 only registers the file; Package #2 fills in the enum + modifiers.
enum FogType { }
