import MapKit
import ObjectiveC
import SwiftMacros

/// The Apple logo and Legal link through MapKit private API (iOS 27): MapKit lays them out from the leading layout
/// margin and has no public way to move them, so placing them elsewhere needs their width, which Legal's language sets.
/// Each ivar's type is checked first; on a mismatch the width is nil.
extension MKMapView {

    // MARK: Static Properties

    private static let logoName = #Obfuscate("_appleLogoImageView")
    private static let legalName = #Obfuscate("_attributionLabel")
    /// The logo and the gap before Legal (iOS 27, measured), for while MapKit takes the logo away (on the globe).
    private static let logoAndGap: CGFloat = 60
    /// The logo and Legal in English, for when MapKit's own width can't be read (iOS 27, measured).
    private static let englishWidth: CGFloat = 89
    /// MapKit sets the logo this far in from the leading margin (iOS 27, measured).
    private static let logoInset: CGFloat = 10
    /// MapKit drops its logo unless the margins leave about 30 pt more than the logo and Legal (iOS 27, measured), so the
    /// trailing margin reaches past the corner by this much and Legal still ends at it.
    private static let logoRoom: CGFloat = 32
    /// MapKit ends Legal's text this far above the bottom layout margin (iOS 27, measured), so it lines up with the cards.
    private static let legalAboveMargin: CGFloat = 10

    // MARK: Computed Properties

    /// How wide the logo and Legal are together, the logo's room kept while it's away, once MapKit has laid out Legal.
    private var attributionWidth: CGFloat? {
        guard let legal = attributionView(Self.legalName), legal.bounds.width > 0 else {
            return nil
        }
        guard let logo = attributionView(Self.logoName), logo.superview != nil, logo.bounds.width > 0 else {
            return legal.bounds.width + Self.logoAndGap
        }
        return logo.convert(logo.bounds, to: self).union(legal.convert(legal.bounds, to: self)).width
    }

    // MARK: Functions

    /// Sets the layout margins so the logo and Legal sit in the trailing corner, Legal's text ending `trailing` in from
    /// the trailing edge and `bottom` up from the bottom one.
    func placeAttributionInTrailingCorner(top: CGFloat, trailing: CGFloat, bottom: CGFloat) {
        if let width = attributionWidth {
            setAttributionMargins(width: width, top: top, trailing: trailing, bottom: bottom)
            return
        }
        // Before MapKit's first layout Legal has no width: lay out with English's, then once more with the one measured,
        // or a wider language's logo is dropped until something else lays the map out.
        setAttributionMargins(width: Self.englishWidth, top: top, trailing: trailing, bottom: bottom)
        layoutIfNeeded()
        if let width = attributionWidth {
            setAttributionMargins(width: width, top: top, trailing: trailing, bottom: bottom)
        }
    }

    private func setAttributionMargins(width: CGFloat, top: CGFloat, trailing: CGFloat, bottom: CGFloat) {
        let leading = bounds.width - trailing - width - Self.logoInset
        let past = trailing - Self.logoRoom
        let isLeftToRight = effectiveUserInterfaceLayoutDirection == .leftToRight
        layoutMargins = UIEdgeInsets(
            top: top,
            left: isLeftToRight ? leading : past,
            bottom: bottom - Self.legalAboveMargin,
            right: isLeftToRight ? past : leading,
        )
    }

    private func attributionView(_ name: String) -> UIView? {
        guard let ivar = class_getInstanceVariable(MKMapView.self, name),
              ivar_getTypeEncoding(ivar).map({ String(cString: $0) })?.hasPrefix("@") == true else {
            return nil
        }
        return object_getIvar(self, ivar) as? UIView
    }
}
