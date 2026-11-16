import SwiftUI

/// Shows an image from backend storage, with a placeholder until it arrives.
struct RemoteImage<Placeholder: View>: View {
    private let ref: MediaRef?
    private let contentMode: ContentMode
    private let placeholder: Placeholder

    @State private var image: UIImage?

    init(_ ref: MediaRef?, contentMode: ContentMode = .fill, @ViewBuilder placeholder: () -> Placeholder) {
        self.ref = ref
        self.contentMode = contentMode
        self.placeholder = placeholder()
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                placeholder
            }
        }
        .task(id: ref) {
            guard let ref else {
                image = nil
                return
            }
            if let hit = ImageStore.shared.cached(ref) {
                image = hit
                return
            }
            image = nil
            image = try? await ImageStore.shared.image(for: ref)
        }
    }
}

struct AvatarView: View {
    let path: String?
    let name: String
    var size: CGFloat = 44

    private static let palette: [Color] = [.indigo, .teal, .orange, .pink, .blue, .purple, .mint, .brown]

    // `hashValue` changes between launches; this keeps a person's colour stable.
    private var tint: Color {
        let sum = name.unicodeScalars.reduce(0) { ($0 + Int($1.value)) % 9973 }
        return AvatarView.palette[sum % AvatarView.palette.count]
    }

    var body: some View {
        RemoteImage(path.map { MediaRef.avatar($0) }) {
            ZStack {
                tint.opacity(0.85)
                Text(String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

struct GroupAvatarView: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Color.accentColor.opacity(0.18)
            Image(systemName: "person.3.fill")
                .font(.system(size: size * 0.36))
                .foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// Rounded, filled text input used on the sign-in and profile forms.
struct InputFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    func inputField() -> some View {
        modifier(InputFieldStyle())
    }

    /// Presents an error message held in optional state as an alert.
    func errorAlert(_ title: String, message: Binding<String?>) -> some View {
        alert(
            title,
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "")
        }
    }
}

enum ChatTime {
    private static let calendar = Calendar.current

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = format
        return formatter
    }

    private static let time = formatter("HH:mm")
    private static let monthDay = formatter("M月d日")
    private static let fullDay = formatter("yyyy年M月d日")

    /// Compact form for the conversation list.
    static func short(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return time.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDay.string(from: date)
        }
        return fullDay.string(from: date)
    }

    /// Longer form for separators inside a chat.
    static func full(_ date: Date) -> String {
        let clock = time.string(from: date)
        if calendar.isDateInToday(date) {
            return clock
        }
        if calendar.isDateInYesterday(date) {
            return "昨天 " + clock
        }
        if calendar.isDate(date, equalTo: Date(), toGranularity: .year) {
            return monthDay.string(from: date) + " " + clock
        }
        return fullDay.string(from: date) + " " + clock
    }
}
