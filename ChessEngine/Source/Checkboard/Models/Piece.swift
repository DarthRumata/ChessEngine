//
//  Piece.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit

struct PieceValue {
    let id: String
    let isWhite: Bool
    let kind: PieceKind
    let position: CheckboardPosition
    let hasMoved: Bool
}

enum PieceKind {
    case pawn, knight, bishop, rook, queen, king
}

class Piece {
    
    let id: String = ProcessInfo.processInfo.globallyUniqueString
    var position: CheckboardPosition
    let isWhite: Bool
    var kind: PieceKind
    var hasMoved: Bool = false
    
    init(position: CheckboardPosition, isWhite: Bool, kind: PieceKind) {
        self.position = position
        self.isWhite = isWhite
        self.kind = kind
    }
    
    var immutableValue: PieceValue {
        return PieceValue(id: id, isWhite: isWhite, kind: kind, position: position, hasMoved: hasMoved)
    }
    
}

extension PieceKind: Identifiable {
    
    var id: String {
        return description
    }
    
    var image: UIImage {
        switch self {
        case .pawn:
            return UIImage(imageLiteralResourceName: "chess-pawn")
        case .knight:
            return UIImage(imageLiteralResourceName: "chess-knight")
        case .bishop:
            return UIImage(imageLiteralResourceName: "chess-bishop")
        case .rook:
            return UIImage(imageLiteralResourceName: "chess-rook")
        case .queen:
            return UIImage(imageLiteralResourceName: "chess-queen")
        case .king:
            return UIImage(imageLiteralResourceName: "chess-king")
        }
    }
    
    var description: String {
        switch self {
        case .pawn:
            return "Pawn"
        case .knight:
            return "Knight"
        case .bishop:
            return "Bishop"
        case .rook:
            return "Rook"
        case .queen:
            return "Queen"
        case .king:
            return "King"
        }
    }
    
}
