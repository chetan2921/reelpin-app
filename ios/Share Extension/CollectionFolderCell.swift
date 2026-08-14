import UIKit

/// Grid cell showing the folder artwork the app rendered from the real
/// CollectionFolderTile, so the picker matches the SAVED tab exactly instead of
/// approximating it natively.
final class CollectionFolderCell: UICollectionViewCell {
    static let reuseId = "CollectionFolderCell"

    private let artwork = UIImageView()
    private let fallback = UILabel()
    private let check = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)

        artwork.contentMode = .scaleAspectFit
        artwork.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(artwork)

        // Shown only if a tile failed to render: a missing image must never
        // hide a collection the user is trying to file into.
        fallback.font = UIFont(name: "SpaceMono-Bold", size: 11)
            ?? .monospacedSystemFont(ofSize: 11, weight: .bold)
        fallback.textColor = .black
        fallback.numberOfLines = 2
        fallback.textAlignment = .center
        fallback.backgroundColor = UIColor(red: 0x7D / 255, green: 0xB5 / 255, blue: 1, alpha: 1)
        fallback.layer.borderWidth = 2
        fallback.layer.borderColor = UIColor.black.cgColor
        fallback.isHidden = true
        fallback.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(fallback)

        check.text = "✓"
        check.font = UIFont(name: "SpaceMono-Bold", size: 15)
            ?? .monospacedSystemFont(ofSize: 15, weight: .bold)
        // Inverts with the device theme, matching the app: black box with a
        // white tick in light mode, white box with a black tick in dark.
        check.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0.10, alpha: 1) : .white
        }
        check.textAlignment = .center
        check.backgroundColor = UIColor { traits in
            traits.userInterfaceStyle == .dark ? .white : .black
        }
        check.isHidden = true
        check.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(check)

        NSLayoutConstraint.activate([
            artwork.topAnchor.constraint(equalTo: contentView.topAnchor),
            artwork.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            artwork.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            artwork.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            fallback.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            fallback.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            fallback.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            fallback.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),

            check.widthAnchor.constraint(equalToConstant: 26),
            check.heightAnchor.constraint(equalToConstant: 26),
            check.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            check.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is unused") }

    func configure(name: String, image: UIImage?, isChecked: Bool) {
        artwork.image = image
        artwork.isHidden = image == nil
        fallback.isHidden = image != nil
        fallback.text = name.uppercased()
        check.isHidden = !isChecked
    }
}
