//
//  ViewController.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 27.01.2021.
//

import UIKit
import Combine

class CheckboardViewController: UIViewController {
    
    @IBOutlet private weak var checkboardView: CheckboardView!
    @IBOutlet private weak var newGameButton: UIButton!
    private var promotionViewController: UIViewController?
    
    private let viewModel = CheckboardViewModel()
    
    private var cancelBag = Set<AnyCancellable>()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        checkboardView.configure(
            checkboardInfoPublisher: viewModel.checkboardInfoPublisher,
            availableMovesPublisher: viewModel.availableMovesPublisher,
            moveResultPublisher: viewModel.moveResultPublisher,
            onSelectPiece: viewModel.onSelectPiece,
            onMoveSelectedPiece: viewModel.onMoveSelectedPiece
        )
        newGameButton.addTarget(self, action: #selector(handleNewGameAction), for: .touchUpInside)
        
        let showPromotionViewSubscription = viewModel.shouldSelectPromotionPublisher.sink { [weak self] (promotions) in
            self?.showPromotionSelectorView(with: promotions)
        }
        cancelBag.insert(showPromotionViewSubscription)
    }
    
    deinit {
        cancelBag.forEach({ $0.cancel() })
    }
    
    @objc private func handleNewGameAction() {
        viewModel.startNewGame()
    }
    
    private func showPromotionSelectorView(with promotions: [PieceKind]) {
        let selectPromotionHandler = AnySubscriber<PieceKind, Never>.init(receiveValue: { [weak self] kind in
            self?.hidePromotionSelectorView()
            _ = self?.viewModel.onSelectPromotion.receive(kind)
            return .unlimited
        })
        let promotionView = PawnPromotionSelectorView(availableKinds: promotions, onSelectPromotion: selectPromotionHandler)
        let promotionController = PawnPromotionSelectorViewController(rootView: promotionView)
        addChild(promotionController)
        view.addSubview(promotionController.view)
        promotionController.view.frame = self.view.bounds.inset(by: UIEdgeInsets(top: 50, left: 50, bottom: 100, right: 50))
        promotionController.view.isHidden = true
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            promotionController.view.isHidden = false
        } completion: { _ in
            promotionController.didMove(toParent: self)
        }
        promotionViewController = promotionController
    }
    
    private func hidePromotionSelectorView() {
        promotionViewController?.willMove(toParent: nil)
        guard let controller = promotionViewController else {
            return
        }
        UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
            controller.view.isHidden = true
        } completion: { _ in
            controller.removeFromParent()
            controller.view.removeFromSuperview()
            self.promotionViewController = nil
        }
    }

}

