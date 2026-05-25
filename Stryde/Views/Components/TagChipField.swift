import SwiftUI

struct TagChipField: View {
    @Binding var tags: [String]
    var existingTags: [String] = []
    @State private var input = ""

    private var suggestions: [String] {
        guard !input.isEmpty else { return [] }
        let lower = input.lowercased()
        return existingTags.filter {
            $0.lowercased().contains(lower) && !tags.contains($0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !tags.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(tags, id: \.self) { tag in
                        TagChip(text: tag) {
                            withAnimation(.spring(response: 0.3)) {
                                tags.removeAll { $0 == tag }
                            }
                        }
                    }
                }
            }

            HStack {
                Image(systemName: "tag")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                TextField("Add tag…", text: $input)
                    .onSubmit { addTag() }
                    .submitLabel(.done)
                if !input.isEmpty {
                    Button(action: addTag) {
                        Image(systemName: "return")
                            .foregroundStyle(Color.strydePrimary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    tags.append(suggestion)
                                }
                                input = ""
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.caption2.bold())
                                    Text(suggestion)
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.strydePrimary.opacity(0.08))
                                .foregroundStyle(Color.strydePrimary)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.strydePrimary.opacity(0.3), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func addTag() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !tags.contains(trimmed) else { input = ""; return }
        withAnimation(.spring(response: 0.3)) { tags.append(trimmed) }
        input = ""
    }
}

struct TagChip: View {
    let text: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption.bold())
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.strydePrimary.opacity(0.15))
        .foregroundStyle(Color.strydePrimary)
        .clipShape(Capsule())
    }
}
