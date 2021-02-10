//
//  CheckboardViewModel.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import Combine

class CheckboardViewModel {
    private let checkboard: Checkboard
    private var moveInProgress: AvailableMove?
    
    var checkboardInfoPublisher: AnyPublisher<CheckboardValue, Never> {
        return checkboardInfoSubject.eraseToAnyPublisher()
    }
    var availableMovesPublisher: AnyPublisher<[AvailableMove], Never> {
        return availableMovesSubject.eraseToAnyPublisher()
    }
    var moveResultPublisher: AnyPublisher<AppliedMove, Never> {
        return moveResultSubject.eraseToAnyPublisher()
    }
    var shouldSelectPromotionPublisher: AnyPublisher<[PieceKind], Never> {
        return shouldSelectPromotionSubject.eraseToAnyPublisher()
    }
    
    private(set) lazy var onSelectPiece = AnySubscriber<String, Never>(receiveValue: { [weak self] pieceId in
        guard let strongSelf = self else {
            return .unlimited
        }
        switch strongSelf.checkboard.situation {
        case .stalemate, .checkmate:
            return .unlimited
        default:
            break
        }
        if let piece = strongSelf.checkboard.pieceValue(withId: pieceId), strongSelf.checkboard.canMovePiece(piece) {
            let moves = strongSelf.checkboard.availableMoves(for: piece)
            strongSelf.availableMovesSubject.send(moves)
        }
        return .unlimited
    })
    private(set) lazy var onMoveSelectedPiece = AnySubscriber<AvailableMove, Never>(receiveValue: { [weak self] move in
        guard let strongSelf = self else {
            return .none
        }
        
        strongSelf.moveInProgress = move
        
        if case .promotion = move.type {
            strongSelf.shouldSelectPromotionSubject.send(strongSelf.checkboard.pawnPromotionKinds)
            return .none
        }
        
        strongSelf.applyCurrentMove()
        
        return .unlimited
    })
    private(set) lazy var onSelectPromotion = AnySubscriber<PieceKind, Never>(receiveValue: { [weak self] kind in
        guard let strongSelf = self, var currentMove = strongSelf.moveInProgress else {
            return .none
        }
        let updatedMove = currentMove.updatedWithPromotion(kind)
        strongSelf.moveInProgress = updatedMove
        strongSelf.applyCurrentMove()
       
        return .unlimited
    })
    
    private let checkboardInfoSubject = PassthroughSubject<CheckboardValue, Never>()
    private let availableMovesSubject = PassthroughSubject<[AvailableMove], Never>()
    private let moveResultSubject = PassthroughSubject<AppliedMove, Never>()
    private let shouldSelectPromotionSubject = PassthroughSubject<[PieceKind], Never>()
    
    init() {
        checkboard = Checkboard()
    }
    
    func startNewGame() {
        checkboard.generate()
        let info = CheckboardValue(
            rowCount: checkboard.rowCount,
            columnCount: checkboard.columnCount,
            pieces: checkboard.pieces.reduce(into: [:], { (result, piece) in
                result[piece.position] = piece.immutableValue
            })
        )
        checkboardInfoSubject.send(info)
    }
    
    private func applyCurrentMove() {
        guard let currentMove = moveInProgress else {
            return
        }
        do {
            let result = try checkboard.applyMove(currentMove)
            self.moveInProgress = nil
            moveResultSubject.send(result)
        } catch let error {
            print(error)
        }
    }
}
