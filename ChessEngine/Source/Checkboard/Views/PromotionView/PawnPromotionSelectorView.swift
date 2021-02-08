//
//  PawnPromotionSelectorView.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 01.02.2021.
//

import SwiftUI
import Combine

struct PawnPromotionSelectorView: View {
    private let availableKinds: [PieceKind]
    private let onSelectPromotion: AnySubscriber<PieceKind, Never>
    
    init(availableKinds: [PieceKind], onSelectPromotion: AnySubscriber<PieceKind, Never>) {
        self.availableKinds = availableKinds
        self.onSelectPromotion = onSelectPromotion
    }
    
    var body: some View {
        VStack(content: {
            Text(/*@START_MENU_TOKEN@*/"Choose promotion for pawn:"/*@END_MENU_TOKEN@*/)
                .font(/*@START_MENU_TOKEN@*/.headline/*@END_MENU_TOKEN@*/)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
            List(availableKinds) { kind in
                PawnPromotionListRow(kind: kind).onTapGesture {
                    _ = self.onSelectPromotion.receive(kind)
                }
            }
        })
    }
}

struct PawnPromotionSelectorView_Previews: PreviewProvider {
    static var previews: some View {
        PawnPromotionSelectorView(availableKinds: [.queen, .knight], onSelectPromotion: AnySubscriber())
    }
}
