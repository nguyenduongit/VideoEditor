import Supabase
import SwiftUI
import os

struct ContentView: View {
  @State var todos: [Todo] = []

  var body: some View {
    NavigationStack {
      List(todos) { todo in
        Text(todo.name)
      }
      .navigationTitle("Todos")
      .task {
        do {
          guard let supabase else { return }
          todos = try await supabase.from("todos").select().execute().value
        } catch {
          Logger(subsystem: "VideoEditor", category: "ContentView")
            .error("Tải todos thất bại: \(error.localizedDescription, privacy: .public)")
        }
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
#endif
