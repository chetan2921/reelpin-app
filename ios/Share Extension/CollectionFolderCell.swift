import UIKit

/// Native port of the app's collection folder tile: hard-edged folder with a
/// tab, an offset shadow slab, and the name in uppercase monospace.
///
/// Drawn rather than assembled from views so the brutalist look — 2pt black
/// borders, no rounding, a solid shadow slab rather than a blur — survives
/// intact, keeping the share picker identical to the SAVED grid.
final class CollectionFolderView: UIView {
    var title: String = "" { didSet { setNeedsDisplay() } }
    var accent: UIColor = CollectionFolderView.accents[0] { didSet { setNeedsDisplay() } }
    var isChecked: Bool = false { didSet { setNeedsDisplay() } }

    /// Mirrors CollectionFolderTile._accents so both grids cycle identically.
    static let accents: [UIColor] = [
        UIColor(red: 0x7D / 255, green: 0xB5 / 255, blue: 1.0, alpha: 1),
        UIColor(red: 1.0, green: 0xD6 / 255, blue: 0.0, alpha: 1),
        UIColor(red: 1.0, green: 0x6B / 255, blue: 0x6B / 255, alpha: 1),
        UIColor(red: 0.0, green: 1.0, blue: 1.0, alpha: 1),
        UIColor(red: 0x39 / 255, green: 1.0, blue: 0x14 / 255, alpha: 1),
    ]

    static func accent(for index: Int) -> UIColor {
        accents[index % accents.count]
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        let border: CGFloat = 2
        let shadow: CGFloat = 5
        let tabHeight: CGFloat = 14

        let bodyTop = tabHeight
        let bodyRight = rect.width - shadow
        let bodyBottom = rect.height - shadow

        // Shadow slab, offset down-right like the Flutter tile.
        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: shadow, y: bodyTop + shadow,
                            width: rect.width - shadow, height: rect.height - bodyTop - shadow))

        context.setStrokeColor(UIColor.black.cgColor)
        context.setLineWidth(border)

        // Folder tab, top-left.
        let tab = CGRect(x: 0, y: 0, width: bodyRight * 0.46, height: tabHeight + 3)
        context.setFillColor(accent.cgColor)
        context.fill(tab)
        context.stroke(tab.insetBy(dx: border / 2, dy: border / 2))

        // Body.
        let body = CGRect(x: 0, y: bodyTop, width: bodyRight, height: bodyBottom - bodyTop)
        context.setFillColor(accent.cgColor)
        context.fill(body)
        context.stroke(body.insetBy(dx: border / 2, dy: border / 2))

        drawTitle(in: CGRect(x: 8, y: bodyTop + 10, width: bodyRight - 16, height: bodyBottom - bodyTop - 18))

        if isChecked {
            drawCheck(context: context, right: bodyRight, bottom: bodyBottom)
        }
    }

    private func drawTitle(in rect: CGRect) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.monospacedSystemFont(ofSize: 11, weight: .bold),
            .foregroundColor: UIColor.black,
            .paragraphStyle: paragraph,
        ]
        // Two lines is plenty: a picker needs recognition, not the full name.
        (title.uppercased() as NSString).draw(with: rect,
                                              options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
                                              attributes: attributes,
                                              context: nil)
    }

    private func drawCheck(context: CGContext, right: CGFloat, bottom: CGFloat) {
        let size: CGFloat = 22
        let pad: CGFloat = 6
        let box = CGRect(x: right - size - pad, y: bottom - size - pad, width: size, height: size)
        context.setFillColor(UIColor.black.cgColor)
        context.fill(box)

        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2.5)
        context.setLineCap(.round)
        context.move(to: CGPoint(x: box.minX + size * 0.24, y: box.midY))
        context.addLine(to: CGPoint(x: box.midX - size * 0.03, y: box.maxY - size * 0.28))
        context.addLine(to: CGPoint(x: box.maxX - size * 0.22, y: box.minY + size * 0.30))
        context.strokePath()
    }
}

/// Grid cell wrapping the folder artwork.
final class CollectionFolderCell: UICollectionViewCell {
    static let reuseId = "CollectionFolderCell"

    private let folder = CollectionFolderView(frame: .zero)

    override init(frame: CGRect) {
        super.init(frame: frame)
        folder.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(folder)
        NSLayoutConstraint.activate([
            folder.topAnchor.constraint(equalTo: contentView.topAnchor),
            folder.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            folder.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            folder.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func configure(name: String, index: Int, isChecked: Bool) {
        folder.title = name
        folder.accent = CollectionFolderView.accent(for: index)
        folder.isChecked = isChecked
    }
}
