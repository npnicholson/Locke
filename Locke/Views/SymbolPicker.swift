//
//  SymbolPicker.swift
//  SymbolPicker
//
//  Created by Yubo Qin on 2/14/22.
//

import Foundation
import SwiftUI
import SFSafeSymbols

/// A simple and cross-platform SFSymbol picker for SwiftUI.
public struct SymbolPicker: View {

    // MARK: - Static consts
    private static var symbols: [String] {
        let SymbolArray: [SFSymbol] = [
            SFSymbol.folderFill,
            SFSymbol.folderFillBadgePlus,
            SFSymbol.folderFillBadgeMinus,
            SFSymbol.folderFillBadgeGearshape,
            SFSymbol.folderFillBadgeQuestionmark,
            SFSymbol.folderFillBadgePersonCrop,
            SFSymbol.plusRectangleOnFolderFill,
            SFSymbol.squareGrid3x1FolderFillBadgePlus,
            SFSymbol.externaldriveFill,
            SFSymbol.externaldriveFillBadgePlus,
            SFSymbol.externaldriveFillBadgeMinus,
            SFSymbol.externaldriveFillBadgeIcloud,
            SFSymbol.externaldriveFillBadgePersonCrop,
            SFSymbol.docFill,
            SFSymbol.docFillBadgePlus,
            SFSymbol.photoFill,
            SFSymbol.photoFillOnRectangleFill,
            SFSymbol.photoStack,
            SFSymbol.filemenuAndCursorarrow,
            SFSymbol.squareAndArrowDownOnSquareFill,
            SFSymbol.squareAndArrowUpOnSquareFill,
            SFSymbol.scribble,
            SFSymbol.gear,
            SFSymbol.textBadgePlus,
            SFSymbol.noteTextBadgePlus,
            SFSymbol.lockFill,
            SFSymbol.lockOpenFill,
            SFSymbol.lockDocFill,
            SFSymbol.lockSlashFill,
            SFSymbol.lockShieldFill,
            SFSymbol.lockSquareStackFill,
            SFSymbol.network,
            SFSymbol.trashFill,
            SFSymbol.paperplaneFill,
            SFSymbol.trayFill,
            SFSymbol.trayFullFill,
            SFSymbol.booksVerticalFill,
            SFSymbol.bookClosedFill,
            SFSymbol.magazineFill,
            SFSymbol.newspaperFill,
            SFSymbol.bookmarkFill
            
            
        ]
        return SymbolArray.map { $0.rawValue }
    }

    private static var gridDimension: CGFloat = 48
    private static var symbolSize: CGFloat = 24
    private static var symbolCornerRadius: CGFloat = 8
    private static var unselectedItemBackgroundColor: Color = .clear
    private static var selectedItemBackgroundColor: Color = .accentColor
    private static var backgroundColor: Color = .clear

    // MARK: - Properties

    @Binding public var symbol: String
    @State private var searchText = ""
    @Environment(\.presentationMode) private var presentationMode

    // MARK: - Public Init

    /// Initializes `SymbolPicker` with a string binding that captures the raw value of
    /// user-selected SFSymbol.
    /// - Parameter symbol: String binding to store user selection.
    public init(symbol: Binding<String>) {
        _symbol = symbol
    }

    // MARK: - View Components

    @ViewBuilder
    private var searchableSymbolGrid: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Type to Search", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 18.0))
                    .disableAutocorrection(true)

                Button {
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .resizable()
                        .frame(width: 16.0, height: 16.0)
                }
                .buttonStyle(.borderless)
            }
            .padding()

            Divider()

            symbolGrid
        }
    }

    private var symbolGrid: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: Self.gridDimension, maximum: Self.gridDimension))]) {
                ForEach(Self.symbols.filter { searchText.isEmpty ? true : $0.localizedCaseInsensitiveContains(searchText) }, id: \.self) { thisSymbol in
                    Button {
                        symbol = thisSymbol
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        if thisSymbol == symbol {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                .background(Self.selectedItemBackgroundColor)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: thisSymbol)
                                .font(.system(size: Self.symbolSize))
                                .frame(maxWidth: .infinity, minHeight: Self.gridDimension)
                                .background(Self.unselectedItemBackgroundColor)
                                .cornerRadius(Self.symbolCornerRadius)
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
        }
    }

    public var body: some View {
        searchableSymbolGrid
            .frame(width: 540, height: 320, alignment: .center)
            .background(.regularMaterial)
    }

}

private func LocalizedString(_ key: String) -> String {
    NSLocalizedString(key, bundle: .main, comment: "")
}

struct SymbolPicker_Previews: PreviewProvider {
    @State static var symbol: String = "square.and.arrow.up"

    static var previews: some View {
        Group {
            SymbolPicker(symbol: Self.$symbol)
            SymbolPicker(symbol: Self.$symbol)
                .preferredColorScheme(.dark)
        }
    }
}
