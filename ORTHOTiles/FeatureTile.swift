// ORTHOTiles/FeatureTile.swift
import OpenSwiftUI
import ORTHODesignSystem

public enum ORTHOTileVariant { case vertical, horizontal, horizontalImageFirst }
public enum ORTHOTileMediaMode { case pinned, bleed, contained }

public struct ORTHOFeatureTile<Media: View>: View {
    let variant: ORTHOTileVariant
    let mediaMode: ORTHOTileMediaMode
    let highlight: String
    let bodyText: String
    let media: Media
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @Environment(\.sizeCategory) private var sizeCategory
    public init(variant: ORTHOTileVariant = .vertical, mediaMode: ORTHOTileMediaMode = .contained, highlight: String, bodyText: String, @ViewBuilder media: () -> Media) {
        self.variant = variant; self.mediaMode = mediaMode; self.highlight = highlight; self.bodyText = bodyText; self.media = media()
    }
    public var body: some View {
        Group {
            if variant == .vertical { verticalLayout }
            else if variant == .horizontalImageFirst { horizontalLayout(imageFirst: true) }
            else { horizontalLayout(imageFirst: false) }
        }
        .background(ORTHOColor.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.tile, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.tile).stroke(ORTHOColor.separator, lineWidth: 1))
        .shadow(color: ORTHOShadow.subtle, radius: isHovered ? 12 : 6, y: isHovered ? 6 : 2)
        .scaleEffect(isHovered ? 1.01 : 1)
        .animation(ORTHOMotion.standard, value: isHovered)
        .onHover { isHovered = $0 }
        .focused($isFocused)
        .overlay(RoundedRectangle(cornerRadius: ORTHORadius.tile).stroke(isFocused ? ORTHOColor.accentPrimary : Color.clear, lineWidth: 2))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(highlight), \(bodyText)")
        .accessibilityAddTraits(.isButton)
        // Observed selectors mapping retained for web parity:
        // .card .tile .tile-rounded .tile-horizontal-layout .image-first .bleed-bottom .pin-middle-center .inner-container-modal-copy-highlight
    }

    private var copyBlock: some View {
        VStack(alignment: .leading, spacing: ORTHOSpacing.xs) {
            Text(highlight).font(ORTHOTypography.title3.weight(.semibold)).foregroundStyle(ORTHOColor.labelPrimary).lineLimit(3)
            Text(bodyText).font(ORTHOTypography.body).foregroundStyle(ORTHOColor.labelSecondary).lineLimit(4)
        }
        .padding(ORTHOSpacing.lg)
        .accessibilityElement(children: .combine)
    }

    private var mediaContainer: some View {
        Group {
            switch mediaMode {
            case .bleed:
                media.scaledToFill().clipped()
                    .clipShape(RoundedRectangle(cornerRadius: ORTHORadius.tile))
                    .overlay(alignment: .bottom) { if variant == .vertical { Rectangle().fill(Color.clear).frame(height: 0) } }
            case .pinned:
                media.scaledToFit().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center).background(ORTHOColor.backgroundSecondary)
                    // pin-middle-center
            case .contained:
                media.scaledToFit().padding(ORTHOSpacing.md)
            }
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 0) {
            copyBlock
            mediaContainer.frame(maxWidth: .infinity).background(ORTHOColor.backgroundSecondary)
        }
    }

    private func horizontalLayout(imageFirst: Bool) -> some View {
        GeometryReader { geo in
            let isSmall = geo.size.width < 734
            let stack = isSmall ? AnyLayout(VStackLayout(spacing: 0)) : AnyLayout(HStackLayout(spacing: 0))
            stack {
                if imageFirst {
                    mediaContainer.frame(width: isSmall ? nil : geo.size.width * 0.48).background(ORTHOColor.backgroundSecondary)
                    copyBlock.frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    copyBlock.frame(maxWidth: .infinity, alignment: .leading)
                    mediaContainer.frame(width: isSmall ? nil : geo.size.width * 0.48).background(ORTHOColor.backgroundSecondary)
                }
            }
        }
        .frame(minHeight: 220)
    }
}
