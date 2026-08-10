import SwiftUI

struct FileListView: View {
    let item: SidebarItem
    let files: [FileItem]

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let background = Color(red: 0.11, green: 0.11, blue: 0.13)

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy 'at' h:mm a"
        return f
    }()

    var body: some View {
        Group {
            if sizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .background(background)
        .navigationTitle(item.title + " — Local")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private var iPhoneLayout: some View {
        List(files) { file in
            FileRowCompact(file: file, formatter: FileListView.dateFormatter)
                .listRowBackground(background)
                .listRowSeparatorTint(.white.opacity(0.1))
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(background)
    }

    private var iPadLayout: some View {
        VStack(spacing: 0) {
            iPadColumnHeader
            Divider()
                .overlay(Color.white.opacity(0.12))
            List(files) { file in
                FileRowTable(file: file, formatter: FileListView.dateFormatter)
                    .listRowBackground(background)
                    .listRowSeparatorTint(.white.opacity(0.1))
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(background)
        }
    }

    private var iPadColumnHeader: some View {
        HStack(spacing: 0) {
            HStack(spacing: 5) {
                Text("Name")
                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(.systemGray))
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Date Modified")
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemGray))
                .frame(width: 220, alignment: .leading)

            Text("Size")
                .font(.system(size: 13))
                .foregroundStyle(Color(.systemGray))
                .frame(width: 100, alignment: .leading)

            HStack(spacing: 4) {
                Text("Kind")
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 10))
            }
            .font(.system(size: 13))
            .foregroundStyle(Color(.systemGray))
            .frame(width: 120, alignment: .leading)

            Spacer().frame(width: 36)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(background)
    }
}