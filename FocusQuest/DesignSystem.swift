import SwiftUI

enum FocusQuestTheme {
    static let accent = Color.indigo
    static let secondaryAccent = Color.purple
    static let cornerRadius: CGFloat = 22

    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [Color.indigo.opacity(0.10), Color(.systemGroupedBackground), Color.purple.opacity(0.05)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct FocusQuestCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                .regularMaterial,
                in: RoundedRectangle(cornerRadius: FocusQuestTheme.cornerRadius, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: FocusQuestTheme.cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.07), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(0.05), radius: 12, y: 5)
    }
}

extension View {
    func focusQuestCard() -> some View { modifier(FocusQuestCard()) }

    func focusQuestScreen() -> some View {
        background(FocusQuestTheme.screenBackground.ignoresSafeArea())
    }
}

struct FocusQuestIconTile: View {
    let symbol: String
    var color: Color = .indigo

    var body: some View {
        Image(systemName: symbol)
            .font(.title3.weight(.semibold))
            .foregroundStyle(color)
            .frame(width: 44, height: 44)
            .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
