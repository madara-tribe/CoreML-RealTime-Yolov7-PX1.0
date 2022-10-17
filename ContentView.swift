import SwiftUI

struct ContentView: View {
    @State var isStart = false
    var body: some View {
        Button("PX2 Start"){
            isStart.toggle()
        }
        .fullScreenCover(isPresented: $isStart) {
            ObjectDetectionController()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
