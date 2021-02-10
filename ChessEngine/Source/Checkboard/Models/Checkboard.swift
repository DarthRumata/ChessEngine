//
//  Checkboard.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import Foundation
import simd

struct CheckboardValue {
    let rowCount: Int
    let columnCount: Int
    let pieces: [CheckboardPosition: PieceValue]
}

struct CheckboardPosition: Hashable {
    let row: Int
    let column: Int
    
    func offsetBy(rowDelta: Int, columnDelta: Int) -> CheckboardPosition {
        return CheckboardPosition(row: row + rowDelta, column: column + columnDelta)
    }
    
    func offsetIn(direction: PieceMoveDirection, forDistance distance: Int = 1) -> CheckboardPosition {
        return CheckboardPosition(
            row: row + direction.rowDelta * distance,
            column: column + direction.columnDelta * distance
        )
    }
}

extension CheckboardPosition: CustomDebugStringConvertible {
    var debugDescription: String {
        return "(\(row), \(column))"
    }
}

struct PieceMoveDirection: Equatable {
    
    let columnDelta: Int
    let rowDelta: Int
    
    static let whitePawnAttack: [PieceMoveDirection] = [
        PieceMoveDirection(columnDelta: 1, rowDelta: 1),
        PieceMoveDirection(columnDelta: -1, rowDelta: 1)
    ]
    
    static let blackPawnAttack: [PieceMoveDirection] = [
        PieceMoveDirection(columnDelta: 1, rowDelta: -1),
        PieceMoveDirection(columnDelta: -1, rowDelta: -1)
    ]
    
    static let allRook: [PieceMoveDirection] = [
        PieceMoveDirection(columnDelta: 0, rowDelta: 1),
        PieceMoveDirection(columnDelta: 0, rowDelta: -1),
        PieceMoveDirection(columnDelta: 1, rowDelta: 0),
        PieceMoveDirection(columnDelta: -1, rowDelta: 0)
    ]
    
    static let allBishop: [PieceMoveDirection] = whitePawnAttack + blackPawnAttack
    
    static let allLinear: [PieceMoveDirection] = allRook + allBishop
    
    static let allKnight: [PieceMoveDirection] = [
        PieceMoveDirection(columnDelta: -2, rowDelta: 1),
        PieceMoveDirection(columnDelta: -2, rowDelta: -1),
        PieceMoveDirection(columnDelta: 2, rowDelta: 1),
        PieceMoveDirection(columnDelta: 2, rowDelta: -1),
        PieceMoveDirection(columnDelta: 1, rowDelta: 2),
        PieceMoveDirection(columnDelta: -1, rowDelta: 2),
        PieceMoveDirection(columnDelta: 1, rowDelta: -2),
        PieceMoveDirection(columnDelta: -1, rowDelta: -2)
    ]
    
}

enum CheckboardSituation: Equatable {
    static func == (lhs: CheckboardSituation, rhs: CheckboardSituation) -> Bool {
        switch (lhs, rhs) {
        case (.normal, .normal), (.check, .check), (.checkmate, .checkmate), (.stalemate, .stalemate):
            return true
        default:
            return false
        }
    }
    
    case normal
    case check(kingId: String, attakers: [Piece])
    case checkmate(kingId: String, forWhite: Bool)
    case stalemate
}

enum CheckboardError: Error {
    case internalInconsistency
}

class Checkboard {
    let rowCount = 8
    let columnCount = 8
    
    let pawnPromotionKinds: [PieceKind] = [.queen, .rook, .bishop, .knight]
    
    private(set) var pieces: [Piece] = []
    private var moveHistory = [AppliedMove]()
    private(set) var situation: CheckboardSituation = .normal
    
    func generate() {
        moveHistory.removeAll()
        pieces = generatePieces()
    }
    
    func piece(withId pieceId: String) -> Piece? {
        return pieces.first(where: { $0.id == pieceId })
    }
    
    func piece(at position: CheckboardPosition) -> Piece? {
        return pieces.first(where: { $0.position == position })
    }
    
    func availableMoves(for piece: PieceValue) -> [AvailableMove] {
        var availableMoves: [AvailableMove]
        switch piece.kind {
        case .pawn:
            availableMoves = availableMovesForPawn(piece)
            
        case .knight:
            let directions = moveDirections(for: piece)
            availableMoves = self.availableMoves(piece: piece, directions: directions, limit: 1)
            
        case .bishop, .rook, .queen:
            let directions = moveDirections(for: piece)
            availableMoves = self.availableMoves(piece: piece, directions: directions, limit: max(rowCount, columnCount))
            
        case .king:
            let directions = moveDirections(for: piece)
            let commonMoves = self.availableMoves(piece: piece, directions: directions, limit: 1)
            let castlingMoves = self.castlingMoves(for: piece)
            let allKingMoves = commonMoves + castlingMoves
            return allKingMoves.filter({ isPositionUnderAttack($0.targetPosition, forWhite: piece.isWhite) == false })
        }
        
        return availableMoves.filter({ !isThreatenKingMove(move: $0) })
    }
    
    func applyMove(_ move: AvailableMove) throws -> AppliedMove {
        guard let piece = self.piece(withId: move.piece.id) else {
            throw CheckboardError.internalInconsistency
        }
        piece.position = move.targetPosition
        piece.hasMoved = true
        var appliedMoveType: AppliedMove.MoveType
        switch move.type {
        case .normal:
            appliedMoveType = .normal
            
        case .take(let takenPieceId):
            guard let takenPieceIndex = pieces.firstIndex(where: { $0.id == takenPieceId }) else {
                throw CheckboardError.internalInconsistency
            }
            appliedMoveType = .taken(pieces[takenPieceIndex].immutableValue)
            pieces.remove(at: takenPieceIndex)
            
        case .takeEnPassant(let takenPieceId):
            guard let takenPiece = self.piece(withId: takenPieceId) else {
                throw CheckboardError.internalInconsistency
            }
            appliedMoveType = .taken(takenPiece.immutableValue)
            
        case .promotion(let kind):
            guard let kind = kind, let promotedPiece = self.piece(withId: piece.id) else {
                throw CheckboardError.internalInconsistency
            }
            promotedPiece.kind = kind
            appliedMoveType = .promotion(promotedPiece.immutableValue)
            
        case .castling(let castledRookId):
            guard let castledRook = self.piece(withId: castledRookId) else {
                throw CheckboardError.internalInconsistency
            }
            let isCastlingShort = castledRook.position.column > piece.position.column
            castledRook.position = CheckboardPosition(
                row: castledRook.position.row,
                column: isCastlingShort ? 5 : 3
            )
            appliedMoveType = .castling(castledRook.immutableValue)
        }
        situation = try calculateCheckboardSituationAfterMove(move)
        print(situation)
        let historyMove = AppliedMove(
            piece: move.piece,
            targetPosition: move.targetPosition,
            situation: situation,
            type: appliedMoveType
        )
        moveHistory.append(historyMove)
        
        return historyMove
    }
    
    // MARK: Generate pieces
    
    private func generatePieces() -> [Piece] {
        pieces.removeAll()
        
        var isWhite: Bool
        var pieceKind: PieceKind
        var isPawn: Bool
        
        for row in [0, 1, 6, 7] {
            isWhite = row <= 1
            isPawn = row == 1 || row == 6
            for column in 0..<columnCount {
                if isPawn {
                    pieceKind = .pawn
                } else {
                    switch column {
                    case 0, 7:
                        pieceKind = .rook
                    case 1, 6:
                        pieceKind = .knight
                    case 2, 5:
                        pieceKind = .bishop
                    case 3:
                        pieceKind = .queen
                    default:
                        pieceKind = .king
                    }
                }
                let position = CheckboardPosition(row: row, column: column)
                let piece = Piece(position: position, isWhite: isWhite, kind: pieceKind)
                pieces.append(piece)
            }
        }
        
        return pieces
    }
    
    // MARK: Available moves
    private func availableMoves(piece: PieceValue, directions: [PieceMoveDirection], limit: Int) -> [AvailableMove] {
        return directions.flatMap({ availableMoves(piece: piece, direction: $0, limit: limit) })
    }
    
    private func availableMoves(piece: PieceValue, direction: PieceMoveDirection, limit: Int) -> [AvailableMove] {
        var moves = [AvailableMove]()
        var currentPosition = piece.position
        var canMoveFurther = true
        var distance = 0
        var moveType: AvailableMove.MoveType = .normal
        
        repeat {
            distance += 1
            currentPosition = currentPosition.offsetBy(rowDelta: direction.columnDelta, columnDelta: direction.rowDelta)
            guard isPositionOnBoard(currentPosition) else {
                canMoveFurther = false
                continue
            }
            if let occuredPiece = self.piece(at: currentPosition) {
                canMoveFurther = false
                // opponent piece can be taken but further movement is bloked
                if occuredPiece.isWhite == piece.isWhite {
                    continue
                } else {
                    moveType = .take(attackedPieceId: occuredPiece.id)
                }
            }
            let move = AvailableMove(
                piece: piece,
                targetPosition: currentPosition,
                type: moveType
            )
            moves.append(move)
        } while canMoveFurther && distance < limit
        
        return moves
    }
    
    private func availableMovesForPawn(_ pawn: PieceValue) -> [AvailableMove] {
        var moves = [AvailableMove]()
        
        // normal move forward
        let stepDirection = pawn.isWhite ? 1 : -1
        let stepCount = pawn.hasMoved ? 1 : 2
        for step in 1...stepCount {
            let newPosition = pawn.position.offsetBy(rowDelta: step * stepDirection, columnDelta: 0)
            guard isPositionOnBoard(newPosition), piece(at: newPosition) == nil else {
                break
            }
            
            let shouldPromote = newPosition.row == (pawn.isWhite ? rowCount - 1 : 0)
            let move = AvailableMove(
                piece: pawn,
                targetPosition: newPosition,
                type: shouldPromote ? .promotion(nil) : .normal
            )
            moves.append(move)
        }
        
        // taking en passant
        if
            let lastMove = moveHistory.last,
            lastMove.piece.kind == .pawn,
            lastMove.targetPosition.row - lastMove.piece.position.row == 2
        {
            for attackColumn in [-1, 1] {
                let attackedPosition = pawn.position.offsetBy(rowDelta: 0, columnDelta: attackColumn)
                if lastMove.targetPosition == attackedPosition {
                    let afterCapturePosition = attackedPosition.offsetBy(rowDelta: pawn.isWhite ? 1 : -1, columnDelta: 0)
                    let move = AvailableMove(
                        piece: pawn,
                        targetPosition: afterCapturePosition,
                        type: .takeEnPassant(attackedPawnId: lastMove.piece.id)
                    )
                    moves.append(move)
                    break
                }
            }
        }
        
        // taking a piece
        for attackColumn in [-1, 1] {
            let attackedPosition = pawn.position.offsetBy(rowDelta: pawn.isWhite ? 1 : -1, columnDelta: attackColumn)
            if let attackedPiece = piece(at: attackedPosition), attackedPiece.isWhite != pawn.isWhite {
                let move = AvailableMove(
                    piece: pawn,
                    targetPosition: attackedPosition,
                    type: .take(attackedPieceId: attackedPiece.id)
                )
                moves.append(move)
            }
        }
        
        return moves
    }
    
    private func castlingMoves(for king: PieceValue) -> [AvailableMove] {
        if king.hasMoved {
            return []
        }
        
        var moves = [AvailableMove]()
        
        if let move = makeCastlingMoveIfPossible(king: king, isShortCastling: false) {
            moves.append(move)
        }
        
        if let move = makeCastlingMoveIfPossible(king: king, isShortCastling: true) {
            moves.append(move)
        }
        
        
        return moves
    }
    
    private func makeCastlingMoveIfPossible(king: PieceValue, isShortCastling: Bool) -> AvailableMove? {
        var canCastle = true
        var castlingRook: Piece!
        let startColumn = isShortCastling ? king.position.column + 1 : 0
        let finishColumn = isShortCastling ? columnCount - 1 : king.position.column - 1
        let rookColumn = isShortCastling ? finishColumn : startColumn
        for column in startColumn...finishColumn {
            let position = CheckboardPosition(row: king.position.row, column: column)
            switch column {
            case rookColumn:
                guard let rook = piece(at: position), !rook.hasMoved else {
                    canCastle = false
                    break
                }
                castlingRook = rook
            default:
                if piece(at: position) != nil {
                    canCastle = false
                    break
                }
            }
        }
        
        guard canCastle else {
            return nil
        }
        
        let modifier = isShortCastling ? 1 : -1
        let castlingPosition = CheckboardPosition(row: king.position.row, column: king.position.column + modifier * 2)
        
        return AvailableMove(
            piece: king,
            targetPosition: castlingPosition,
            type: .castling(rookId: castlingRook.id)
        )
    }
    
    private func moveDirections(for piece: PieceValue) -> [PieceMoveDirection] {
        switch piece.kind {
        case .pawn:
            return []
        case .knight:
            return PieceMoveDirection.allKnight
        case .bishop:
            return PieceMoveDirection.allBishop
        case .rook:
            return PieceMoveDirection.allRook
        case .queen, .king:
            return PieceMoveDirection.allLinear
        }
    }
    
    private func isThreatenKingMove(move: AvailableMove) -> Bool {
        guard let king = pieces.first(where: { $0.kind == .king && $0.isWhite == move.piece.isWhite }) else {
            return false
        }
        
        guard let coverDirection = linearDirection(from: king.position, to: move.piece.position) else {
            return false
        }
        
        if let afterMoveDirection = linearDirection(from: king.position, to: move.targetPosition), afterMoveDirection == coverDirection {
            return false
        }
        let piece = self.piece(withId: move.piece.id)
        // Hack: temporary move piece to target position to allow calculation of future situation
        piece?.position = move.targetPosition
        defer {
            piece?.position = move.piece.position
        }
        return attackerOnPosition(king.position, forWhite: king.isWhite, from: coverDirection) != nil
    }
    
    //MARK: Check square whether under attack
    private func allAttackersOnPosition(_ position: CheckboardPosition, forWhite isWhitePosition: Bool) -> [Piece] {
        var attackers = [Piece]()
        let allPossbileDirection = PieceMoveDirection.allKnight + PieceMoveDirection.allLinear
        for direction in allPossbileDirection {
            if let attacker = attackerOnPosition(position, forWhite: isWhitePosition, from: direction) {
                attackers.append(attacker)
            }
        }
        
        return attackers
    }
    
    private func isPositionUnderAttack(_ position: CheckboardPosition, forWhite isWhitePosition: Bool) -> Bool {
        let allPossbileDirection = PieceMoveDirection.allKnight + PieceMoveDirection.allLinear
        for direction in allPossbileDirection {
            if attackerOnPosition(position, forWhite: isWhitePosition, from: direction) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func attackerOnPosition(_ position: CheckboardPosition, forWhite isWhitePosition: Bool, from direction: PieceMoveDirection) -> Piece? {
        let isKnightDirection = PieceMoveDirection.allKnight.contains(direction)
        var distance = 1
        while true {
            let offsetPosition = position.offsetIn(direction: direction, forDistance: distance)
            guard isPositionOnBoard(offsetPosition) else {
                return nil
            }
            guard let suspectedPiece = piece(at: offsetPosition) else {
                if isKnightDirection {
                    return nil
                } else {
                    distance += 1
                    continue
                }
            }
            guard suspectedPiece.isWhite != isWhitePosition else {
                return nil
            }
            
            var isAttacker: Bool
            switch suspectedPiece.kind {
            case .pawn:
                let pawnAttackDirections = isWhitePosition ? PieceMoveDirection.whitePawnAttack : PieceMoveDirection.blackPawnAttack
                let isPawnAttackDirection = pawnAttackDirections.contains(direction)
                isAttacker = distance == 1 && isPawnAttackDirection
                
            case .knight:
                isAttacker = distance == 1 && isKnightDirection
                
            case .bishop:
                let isBishopDirection = PieceMoveDirection.allBishop.contains(direction)
                isAttacker = isBishopDirection
                
            case .rook:
                let isRookDirection = PieceMoveDirection.allRook.contains(direction)
                isAttacker = isRookDirection
                
            case .queen:
                let isQueenDirection = PieceMoveDirection.allLinear.contains(direction)
                isAttacker = isQueenDirection
                
            case .king:
                let isKingDirection = PieceMoveDirection.allLinear.contains(direction)
                isAttacker = distance == 1 && isKingDirection
            }
            
            return isAttacker ? suspectedPiece : nil
        }
    }
    
    // MARK: Define checkboard situation
    private func calculateCheckboardSituationAfterMove(_ move: AvailableMove) throws -> CheckboardSituation {
        guard let enemyKing = pieces.first(where: { $0.isWhite != move.piece.isWhite && $0.kind == .king }) else {
            throw CheckboardError.internalInconsistency
        }
        
        let attackers = allAttackersOnPosition(enemyKing.position, forWhite: enemyKing.isWhite)
        let allEnemyMoves = allMoves(forWhite: enemyKing.isWhite)
        let canMoveKing = allEnemyMoves.contains(where: { $0.piece.kind == .king })
        
        guard !attackers.isEmpty else {
            return allEnemyMoves.isEmpty ? .stalemate : .normal
        }
        
        if attackers.count > 1 {
            return canMoveKing
                ? .check(kingId: enemyKing.id, attakers: attackers)
                : .checkmate(kingId: enemyKing.id, forWhite: enemyKing.isWhite)
        } else {
            let canTakeSingleAttacker = allEnemyMoves.contains(where: { $0.targetPosition == attackers[0].position })
            let isPossibleToCoverKing = attackers[0].kind != .knight && attackers[0].kind != .pawn
            var canCoverKing = false
            if isPossibleToCoverKing {
                let coverPositions = emptyPositions(after: enemyKing.position, towards: attackers[0].position)
                canCoverKing = allEnemyMoves.contains(where: { $0.piece.kind != .king && coverPositions.contains($0.targetPosition) })
            }
            return (canTakeSingleAttacker || canCoverKing || canMoveKing)
                ? .check(kingId: enemyKing.id, attakers: attackers)
                : .checkmate(kingId: enemyKing.id, forWhite: enemyKing.isWhite)
        }
    }
    
    private func allMoves(forWhite isWhite: Bool) -> [AvailableMove] {
        return pieces.reduce(into: []) { (allMoves, piece) in
            guard piece.isWhite == isWhite else {
                return
            }
            let moves = availableMoves(for: piece.immutableValue)
            allMoves.append(contentsOf: moves)
        }
    }
    
    // MARK: Position helpers
    private func isPositionOnBoard(_ position: CheckboardPosition) -> Bool {
        return position.column >= 0 && position.column < columnCount && position.row >= 0 && position.row < rowCount
    }
    
    private func isPositionOnEdge(_ position: CheckboardPosition) -> Bool {
        return position.column == 0
            || position.column == columnCount - 1
            || position.row == 0
            || position.row == rowCount - 1
    }
    
    private func emptyPositions(after closePosition: CheckboardPosition, towards distantPosition: CheckboardPosition) -> [CheckboardPosition] {
        guard closePosition != distantPosition else {
            return []
        }
        if let direction = linearDirection(from: closePosition, to: distantPosition) {
            var distance = 1
            var positions = [CheckboardPosition]()
            while true {
                let newPosition = closePosition.offsetIn(direction: direction, forDistance: distance)
                guard distantPosition != newPosition else {
                    return positions
                }
                
                positions.append(newPosition)
                distance += 1
            }
        }
        
        return []
    }
    
    private func linearDirection(from firstPosition: CheckboardPosition, to secondPosition: CheckboardPosition) -> PieceMoveDirection? {
        let directionVector = SIMD2(secondPosition.column, secondPosition.row) &- SIMD2(firstPosition.column, firstPosition.row)
        if directionVector.x == 0 || directionVector.y == 0 || abs(directionVector.x) == abs(directionVector.y) {
            let length = max(abs(directionVector.x), abs(directionVector.y))
            let normalizedVector = SIMD2(directionVector.x / length, directionVector.y / length)
            return PieceMoveDirection(columnDelta: normalizedVector.x, rowDelta: normalizedVector.y)
        }
        
        return nil
    }
    
}
