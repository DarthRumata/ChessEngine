//
//  Move.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 01.02.2021.
//

import Foundation

class Move {
    let piece: PieceValue
    let targetPosition: CheckboardPosition
    
    init(piece: PieceValue, targetPosition: CheckboardPosition) {
        self.piece = piece
        self.targetPosition = targetPosition
    }
}

class AvailableMove: Move {
    enum MoveType {
        case normal
        case take(attackedPieceId: String)
        case takeEnPassant(attackedPawnId: String)
        case promotion(PieceKind?)
        case castling(rookId: String)
    }
    
    let type: MoveType
    
    init(piece: PieceValue, targetPosition: CheckboardPosition, type: MoveType) {
        self.type = type
        
        super.init(piece: piece, targetPosition: targetPosition)
    }
    
    func updatedWithPromotion(_ kind: PieceKind) -> AvailableMove {
        guard case .promotion = type else {
            return self
        }
        
        return AvailableMove(piece: piece, targetPosition: targetPosition, type: .promotion(kind))
    }
}

class AppliedMove: Move {
    enum MoveType {
        case normal
        case taken(PieceValue)
        case promotion(PieceValue)
        case castling(PieceValue)
    }
    
    let type: MoveType
    let situation: CheckboardSituation
    
    init(piece: PieceValue, targetPosition: CheckboardPosition, situation: CheckboardSituation, type: MoveType) {
        self.type = type
        self.situation = situation
        
        super.init(piece: piece, targetPosition: targetPosition)
    }
}
