//
//  PieceView.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit
import SwiftUI

private enum Constants {
    static let whiteColor = UIColor(red: 0.75, green: 0.75, blue: 0.65, alpha: 1)
    static let blackColor = UIColor(red: 0.2, green: 0.15, blue: 0.12, alpha: 1)
    static let pieceSizeRatio: CGFloat = 0.75
    static let selectedColor = UIColor(red: 0.9, green: 0.9, blue: 0, alpha: 1)
    static let underAttackColor = UIColor(red: 0.4, green: 0.2, blue: 0.1, alpha: 0.7)
    static let kingInCheckColor = UIColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
}

class PieceView: UIImageView {
    
    private(set) var pieceId: String!
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
    
    func configure(with piece: PieceValue) {
        self.pieceId = piece.id
        
        let color = piece.isWhite ? Constants.whiteColor : Constants.blackColor
        let image = piece.kind.image.withTintColor(color, renderingMode: .alwaysOriginal)
        
        let scaleTransform = CGAffineTransform(scaleX: Constants.pieceSizeRatio, y: Constants.pieceSizeRatio)
        self.image = image.resized(to: bounds.size.applying(scaleTransform))
        originalImage = self.image
        
        contentMode = .center
    }
    
    func setHighlightedAsSelected(_ isHighlighted: Bool) {
        outlinePieceImage(with: Constants.selectedColor, isOutlined: isHighlighted)
    }
    
    func setHighlightedAsAttacked(_ isHighlighted: Bool) {
        underAttackLayer.isHidden = !isHighlighted
    }
    
    func setHighlightedAsKingInCheck(_ isHighlighted: Bool) {
        outlinePieceImage(with: Constants.kingInCheckColor, isOutlined: isHighlighted)
    }
    
    private func outlinePieceImage(with color: UIColor, isOutlined: Bool) {
        if isOutlined {
            originalImage = image
            image = image?.stroked(with: color, thickness: 3)
        } else {
            image = originalImage
        }
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
