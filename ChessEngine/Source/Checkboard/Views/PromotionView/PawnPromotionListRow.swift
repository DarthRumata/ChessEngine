//
//  PawnPromotionListRow.swift
//  ChessEngine
//
//  Created by Stas Kirichok on 01.02.2021.
//

import SwiftUI

struct PawnPromotionListRow: View {
    private let kind: PieceKind
    
    init(kind: PieceKind) {
        self.kind = kind
    }
    
    var body: some View {
        HStack {
            Image(uiImage: kind.image)
                .resizable()
                .frame(width: 50, height: 50)
            Text(kind.description)
        }
        .padding(.all)
    }
}

struct PawnPromotionListRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PawnPromotionListRow(kind: .queen)
                .previewLayout(.sizeThatFits)
        }
    }
}
