import AppKit
import SwiftUI

struct CommandPaletteView: View {
    @Bindable var model: CommandPaletteModel
    let onPerform: (PaletteItem) -> Void
    let onClose: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: model.mode == .commands ? "command" : "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField(model.placeholder, text: $model.query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit(performSelected)
                    .onKeyPress(.downArrow) {
                        model.moveSelection(by: 1)
                        return .handled
                    }
                    .onKeyPress(.upArrow) {
                        model.moveSelection(by: -1)
                        return .handled
                    }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            let results = model.results
            if results.isEmpty {
                Text(L10n.Palette.noResults)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, item in
                                PaletteRow(item: item, isSelected: index == model.selectedIndex)
                                    .id(item.id)
                                    .onTapGesture {
                                        model.selectedIndex = index
                                        performSelected()
                                    }
                            }
                        }
                        .padding(6)
                    }
                    .frame(maxHeight: 340)
                    .onChange(of: model.selectedIndex) {
                        if let item = model.selectedItem {
                            proxy.scrollTo(item.id)
                        }
                    }
                }
            }
        }
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
        .onAppear { isFocused = true }
        .onExitCommand(perform: onClose)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.Accessibility.commandPalette)
    }

    private func performSelected() {
        guard let item = model.selectedItem else {
            NSSound.beep()
            return
        }
        onPerform(item)
    }
}

private struct PaletteRow: View {
    let item: PaletteItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbolName)
                .frame(width: 18)
                .foregroundStyle(isSelected ? Color.white : Color.secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .lineLimit(1)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .lineLimit(1)
                        .truncationMode(.head)
                        .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
                }
            }
            Spacer(minLength: 8)
            if let shortcut = item.shortcut {
                Text(shortcut)
                    .font(.callout.monospaced())
                    .foregroundStyle(isSelected ? Color.white.opacity(0.85) : Color.secondary)
            }
        }
        .foregroundStyle(isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor : Color.clear, in: .rect(cornerRadius: 8))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

final class CommandPalettePanel: NSPanel {
    let model: CommandPaletteModel
    private weak var hostWindow: NSWindow?

    init(model: CommandPaletteModel) {
        self.model = model
        super.init(contentRect: NSRect(x: 0, y: 0, width: 560, height: 420), styleMask: [.borderless, .fullSizeContentView], backing: .buffered, defer: true)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isReleasedWhenClosed = false
        hidesOnDeactivate = true
        let view = CommandPaletteView(
            model: model,
            onPerform: { [weak self] item in self?.perform(item) },
            onClose: { [weak self] in self?.dismiss() }
        )
        let hostingView = NSHostingView(rootView: view)
        hostingView.sizingOptions = [.intrinsicContentSize]
        contentView = hostingView
    }

    override var canBecomeKey: Bool {
        true
    }

    /// Shows the palette in the upper third of `window`.
    func present(over window: NSWindow) {
        hostWindow = window
        layoutIfNeeded()
        let size = contentView?.fittingSize ?? NSSize(width: 560, height: 400)
        let frame = window.frame
        let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.maxY - frame.height / 5 - size.height)
        setFrame(NSRect(origin: origin, size: size), display: true)
        window.addChildWindow(self, ordered: .above)
        makeKey()
    }

    override func resignKey() {
        super.resignKey()
        if isVisible {
            dismiss()
        }
    }

    func dismiss() {
        hostWindow?.removeChildWindow(self)
        orderOut(nil)
        hostWindow?.makeKey()
    }

    private func perform(_ item: PaletteItem) {
        dismiss()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                item.perform()
            }
        }
    }
}
