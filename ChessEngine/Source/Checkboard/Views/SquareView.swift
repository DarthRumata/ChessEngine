//
//  SquareView.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit

private let blackSquareColor = UIColor(red: 0.02, green: 0.5, blue: 0.15, alpha: 1)

class SquareView: UIView {

    private lazy var highlightLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        let frame = bounds.insetBy(dx: 15, dy: 15)
        layer.path = UIBezierPath(ovalIn: frame).cgPath
        layer.strokeColor = UIColor.darkGray.cgColor
        layer.fillColor = UIColor.darkGray.cgColor
        self.layer.addSublayer(layer)
        
        return layer
    }()
    
    func setPosition(_ position: CheckboardPosition) {
        backgroundColor = isWhiteSquare(at: position) ? .white : blackSquareColor
    }
    
    func setHighlighted(_ isHighlighted: Bool) {
        highlightLayer.isHidden = !isHighlighted
    }
    
    private func isWhiteSquare(at position: CheckboardPosition) -> Bool {
        return (!position.column.isEven && position.row.isEven) || (position.column.isEven && !position.row.isEven)
    }
    
}

private extension Int {
    var isEven: Bool {
        return self % 2 == 0
    }
}
