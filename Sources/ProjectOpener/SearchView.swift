import AppKit
import SwiftUI

struct SearchView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            if model.rows.isEmpty {
                empty
            } else {
                results
            }
        }
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
            SearchField(text: $model.query)
                .frame(height: 26)
            if model.isScanning {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 52)
    }

    private var empty: some View {
        VStack(spacing: 4) {
            Text(model.isScanning ? "Scanning…" : "No projects found")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
    }

    private var results: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(spacing: 0) {
                    ForEach(Array(model.rows.enumerated()), id: \.element.id) { index, row in
                        switch row {
                        case .header(let title):
                            Text(title.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.tertiary)
                                .kerning(0.6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(height: row.height, alignment: .bottom)
                                .padding(.bottom, 2)
                                .id(row.id)

                        case .project(let project, let matches):
                            ProjectRow(
                                project: project,
                                matches: matches,
                                isSelected: index == model.selection,
                                isPinned: model.isPinned(project)
                            )
                            .id(row.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                model.selection = index
                                model.openSelected()
                            }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: model.selection) { _, new in
                guard model.rows.indices.contains(new) else { return }
                withAnimation(.easeOut(duration: 0.12)) {
                    proxy.scrollTo(model.rows[new].id, anchor: .center)
                }
            }
        }
    }
}

private struct ProjectRow: View {
    let project: Project
    let matches: [Int]
    let isSelected: Bool
    let isPinned: Bool

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: project.kind.symbol)
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? .white : .secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                highlightedName
                Text(project.relativePath)
                    .font(.system(size: 11))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.75) : Color.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }

            Spacer(minLength: 8)

            if isPinned {
                Image(systemName: "star.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white.opacity(0.9) : Color.secondary.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
        .padding(.horizontal, 8)
    }

    /// Bolds the characters the fuzzy matcher actually landed on.
    private var highlightedName: some View {
        let matchSet = Set(matches)
        var text = Text("")
        for (i, ch) in project.name.enumerated() {
            let piece = Text(String(ch))
                .font(.system(size: 13, weight: matchSet.contains(i) ? .bold : .regular))
                .foregroundColor(
                    matchSet.contains(i)
                        ? (isSelected ? .white : .accentColor)
                        : (isSelected ? .white : .primary)
                )
            text = text + piece
        }
        return text.lineLimit(1)
    }
}

/// Borderless `NSTextField` — gives reliable first-responder behaviour inside a
/// non-activating panel, which SwiftUI's `TextField` does not.
private struct SearchField: NSViewRepresentable {
    @Binding var text: String

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 18, weight: .regular)
        field.placeholderString = "Search projects…"
        field.delegate = context.coordinator
        field.cell?.usesSingleLineMode = true
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.identifier = NSUserInterfaceItemIdentifier("ProjectOpenerSearchField")
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text { nsView.stringValue = text }
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
