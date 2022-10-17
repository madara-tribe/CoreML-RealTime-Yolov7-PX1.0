import SwiftUI

struct ContentView: View {
    @State var isStart = false
    var body: some View {
        VStack {
            Image("waiting")
            Button(action:{
                isStart = true
            }, label:{
                Text("PX2 Start")
                    .padding()
            })
            .sheet(isPresented: $isStart) {
                ViewController()
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
