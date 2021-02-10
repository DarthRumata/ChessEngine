//
//  PieceView.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit
import SwiftUI
import Combine

private enum Constants {
    static let whiteColor = UIColor(red: 0.75, green: 0.75, blue: 0.65, alpha: 1)
    static let blackColor = UIColor(red: 0.2, green: 0.15, blue: 0.12, alpha: 1)
    static let pieceSizeRatio: CGFloat = 0.75
    static let selectedColor = UIColor(red: 0.9, green: 0.9, blue: 0, alpha: 1)
    static let underAttackColor = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 0.7)
    static let kingInCheckColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
}

struct PieceAttributes: OptionSet {
    let rawValue: Int
    
    static let selected = PieceAttributes(rawValue: 1 << 0)
    static let kingInCheck = PieceAttributes(rawValue: 1 << 1)
    static let underAttack = PieceAttributes(rawValue: 1 << 2)
}

class PieceView: UIImageView {
    
    private var originalImage: UIImage!
    private lazy var underAttackLayer: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.path = UIBezierPath(ovalIn: bounds).cgPath
        shape.strokeColor = Constants.underAttackColor.cgColor
        shape.fillColor = UIColor.clear.cgColor
        shape.lineWidth = 3
        layer.addSublayer(shape)
        
        return shape
    }()
    
    private(set) var pieceId: String!
    @Published private var attributes: PieceAttributes = []
    private var attributesSubscription: Cancellable?
    
    deinit {
        attributesSubscription?.cancel()
    }
    
    func configure(with piece: PieceValue) {
        self.pieceId = piece.id
        
        let color = piece.isWhite ? Constants.whiteColor : Constants.blackColor
        let image = piece.kind.image.withTintColor(color, renderingMode: .alwaysOriginal)
        
        let scaleTransform = CGAffineTransform(scaleX: Constants.pieceSizeRatio, y: Constants.pieceSizeRatio)
        self.image = image.resized(to: bounds.size.applying(scaleTransform))
        originalImage = self.image
        
        contentMode = .center
        
        attributesSubscription = $attributes.sink { [weak self] (attributes) in
            guard let strongSelf = self else {
                return
            }
            strongSelf.underAttackLayer.isHidden = !attributes.contains(.underAttack)
            if attributes.contains(.selected) {
                strongSelf.image = strongSelf.originalImage.stroked(with: Constants.selectedColor, thickness: 3)
            } else if attributes.contains(.kingInCheck) {
                strongSelf.image = strongSelf.originalImage.stroked(with: Constants.kingInCheckColor, thickness: 3)
            } else {
                strongSelf.image = strongSelf.originalImage
            }
        }
    }
    
    func addAttribute(_ attribute: PieceAttributes) {
        attributes.insert(attribute)
    }
    
    func removeAttribute(_ attribute: PieceAttributes) {
        attributes.remove(attribute)
    }
    
}

private extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { (context) in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
