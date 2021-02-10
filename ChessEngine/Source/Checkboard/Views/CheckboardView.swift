//
//  CheckboardView.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit
import Combine

class CheckboardView: UIView {
    
    private var squareViews = [CheckboardPosition: SquareView]()
    private var pieceViews = [PieceView]()
    private var selectedPieceView: PieceView?
    private var selectedPieceInitialFrame: CGRect?
    private var kingInCheckId: String?
    
    private var cancelBag = Set<AnyCancellable>()
    private var onSelectPiece: AnySubscriber<String, Never>?
    private var onMoveSelectedPiece: AnySubscriber<AvailableMove, Never>?
    private var currentlyAvailableMoves: [AvailableMove]?
    
    var kingInCheckView: PieceView? {
        return pieceViews.first(where: { $0.pieceId == kingInCheckId })
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        addGestureRecognizer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        
        addGestureRecognizer()
    }
    
    deinit {
        cancelBag.forEach({ $0.cancel() })
    }
    
    func configure(checkboardInfoPublisher: AnyPublisher<CheckboardValue, Never>, availableMovesPublisher: AnyPublisher<[AvailableMove], Never>, moveResultPublisher: AnyPublisher<AppliedMove, Never>, onSelectPiece: AnySubscriber<String, Never>, onMoveSelectedPiece: AnySubscriber<AvailableMove, Never>) {
        let checkboardInfoSubscription = checkboardInfoPublisher.sink { [weak self] (viewInfo) in
            self?.fillBoard(with: viewInfo)
        }
        cancelBag.insert(checkboardInfoSubscription)
        let availableMovesSubscription = availableMovesPublisher.sink { [weak self] (moves) in
            self?.currentlyAvailableMoves = moves
            self?.highlightMoves(moves)
        }
        cancelBag.insert(availableMovesSubscription)
        let moveResultSubscription = moveResultPublisher.sink { [weak self] (move) in
            guard let strongSelf = self else {
                return
            }
            
            strongSelf.kingInCheckView?.removeAttributes(.kingInCheck)

            let type = move.type
            switch type {
            case .normal:
                break
                
            case .taken(let takenPiece):
                if let takenPieceViewIndex = strongSelf.pieceViews.firstIndex(where: { $0.pieceId == takenPiece.id }) {
                    let takenPieceView = strongSelf.pieceViews[takenPieceViewIndex]
                    takenPieceView.removeFromSuperview()
                    strongSelf.pieceViews.remove(at: takenPieceViewIndex)
                }
                
            case .promotion(let piece):
                if let promotedPieceView = strongSelf.pieceViews.first(where: { $0.pieceId == piece.id }) {
                    promotedPieceView.configure(with: piece)
                }
                
            case .castling(let castledRook):
                if
                    let castledRookView = strongSelf.pieceViews.first(where: { $0.pieceId == castledRook.id }),
                    let targetPositionFrame = strongSelf.squareViews[castledRook.position]?.frame
                {
                    castledRookView.frame = targetPositionFrame
                    castledRookView.superview?.bringSubviewToFront(castledRookView)
                }
                
            }
            self?.resetSelection()
            
            switch move.situation {
            case .check(let kingId, _, _):
                strongSelf.kingInCheckId = kingId
                strongSelf.kingInCheckView?.addAttributes(.kingInCheck)
            case .checkmate(let kingId, _):
                strongSelf.kingInCheckId = kingId
                strongSelf.kingInCheckView?.addAttributes([.kingDefeated, .kingInCheck])
            default:
                break
            }
        }
        cancelBag.insert(moveResultSubscription)
        self.onSelectPiece = onSelectPiece
        self.onMoveSelectedPiece = onMoveSelectedPiece
    }
    
    private func fillBoard(with info: CheckboardValue) {
        pieceViews.forEach({ $0.removeFromSuperview() })
        squareViews.values.forEach({ $0.removeFromSuperview() })
        pieceViews.removeAll()
        squareViews.removeAll()
        
        layoutIfNeeded()
        
        let squareSize = CGSize(
            width: bounds.width / CGFloat(info.columnCount),
            height: bounds.height / CGFloat(info.rowCount)
        )
        for row in 0..<info.rowCount {
            for column in 0..<info.columnCount {
                let position = CheckboardPosition(row: row, column: column)
                let squareView = createSquare(at: position, with: squareSize)
                addSubview(squareView)
                squareViews[position] = squareView
                
                if let piece = info.pieces[position] {
                    let pieceView = PieceView(frame: squareView.frame)
                    pieceView.configure(with: piece)
                    addSubview(pieceView)
                    pieceViews.append(pieceView)
                }
            }
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        guard let touch = touches.first, selectedPieceView == nil else {
            return
        }
        
        let touchLocation = touch.location(in: self)
        if let selectedPiece = pieceViews.first(where: { $0.frame.contains(touchLocation) }) {
            bringSubviewToFront(selectedPiece)
            selectedPieceView = selectedPiece
            selectedPieceInitialFrame = selectedPieceView?.frame
            _ = onSelectPiece?.receive(selectedPiece.pieceId)
            selectedPiece.addAttributes(.selected)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        guard selectedPieceView != nil else {
            return
        }
        
        resetSelection()
    }
    
    private func addGestureRecognizer() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePanGesture(recognizer:)))
        addGestureRecognizer(panRecognizer)
    }
    
    @objc private func handlePanGesture(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .changed:
            guard let selectedPieceView = selectedPieceView, let selectedPieceInitialFrame = selectedPieceInitialFrame else {
                return
            }
            let translation = recognizer.translation(in: self)
            let transform = CGAffineTransform(translationX: translation.x, y: translation.y)
            let newFrame = selectedPieceInitialFrame.applying(transform)
            selectedPieceView.frame = newFrame
        case .ended:
            guard let selectedPieceView = selectedPieceView else {
                return
            }
            let pieceCenterPoint = CGPoint(x: selectedPieceView.frame.midX, y: selectedPieceView.frame.midY)
            if let targetSquareContainer = squareViews.first(where: { $0.value.frame.contains(pieceCenterPoint) }) {
                let targetPosition = targetSquareContainer.key
                let targetSquare = targetSquareContainer.value
                if let moves = currentlyAvailableMoves, let targetMove = moves.first(where: { $0.targetPosition == targetPosition }) {
                    _ = onMoveSelectedPiece?.receive(targetMove)
                    selectedPieceView.center = targetSquare.center
                } else {
                    returnPieceToInitialPositionAndResetSelection()
                }
            } else {
                returnPieceToInitialPositionAndResetSelection()
            }
            
        case .cancelled:
            returnPieceToInitialPositionAndResetSelection()
            
        default:
            break
        }
    }
    
    private func returnPieceToInitialPositionAndResetSelection() {
        if let selectedPieceInitialFrame = selectedPieceInitialFrame {
            selectedPieceView?.frame = selectedPieceInitialFrame
            resetSelection()
        }
    }
    
    private func resetSelection() {
        selectedPieceView?.removeAttributes(.selected)
        selectedPieceInitialFrame = nil
        selectedPieceView = nil
        unhighlightMoves()
    }
    
    private func highlightMoves(_ moves: [AvailableMove]) {
        for move in moves {
            switch move.type {
            case .normal, .takeEnPassant, .castling, .promotion:
                if let squareView = squareViews[move.targetPosition] {
                    squareView.setHighlighted(true)
                }
            case .take(let pieceId):
                if
                    let selectedPieceView = selectedPieceView,
                    let pieceView = pieceViews.first(where: { $0.pieceId == pieceId })
                {
                    insertSubview(pieceView, belowSubview: selectedPieceView)
                    pieceView.addAttributes(.underAttack)
                }
            }
        }
    }
    
    private func unhighlightMoves() {
        currentlyAvailableMoves = nil
        squareViews.values.forEach({ $0.setHighlighted(false) })
        pieceViews.forEach({ $0.removeAttributes(.underAttack) })
    }
    
    private func createSquare(at position: CheckboardPosition, with size: CGSize) -> SquareView {
        let x = CGFloat(position.column) * size.width
        let y = bounds.height - CGFloat(position.row + 1) * size.height
        let frame = CGRect(origin: CGPoint(x: x, y: y), size: size)
        let view = SquareView(frame: frame)
        view.setPosition(position)
        
        return view
    }
    
}
