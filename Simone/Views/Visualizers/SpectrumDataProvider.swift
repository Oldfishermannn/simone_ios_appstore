import SwiftUI

enum MorandiPalette {
    static let rose = Color(red: 196/255, green: 166/255, blue: 157/255)
    static let mauve = Color(red: 181/255, green: 160/255, blue: 181/255)
    static let sage = Color(red: 163/255, green: 171/255, blue: 143/255)
    static let blue = Color(red: 142/255, green: 154/255, blue: 175/255)
    static let sand = Color(red: 201/255, green: 191/255, blue: 170/255)

    static let all: [Color] = [rose, mauve, sage, blue, sand]

    static func color(at index: Int) -> Color {
        all[index % all.count]
    }
}
