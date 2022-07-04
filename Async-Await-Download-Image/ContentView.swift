//
//  ContentView.swift
//  Async-Await-Download-Image
//
//  Created by Simran Preet Narang on 2022-07-03.
//

import SwiftUI
import Combine

struct ContentView: View {
  
  @StateObject var viewModel = ViewModel()
  
  var body: some View {
    ZStack {
      if let image = viewModel.image {
        Image(uiImage: image)
          .resizable()
          .scaledToFit()
          .frame(width: 300, height: 300)
      }
    }
    .task {
      await viewModel.fetchImageAsync()
    }
  }
}


extension ContentView {
  class ViewModel: ObservableObject {
    
    @Published var image: UIImage? = nil
    let loader = ImageDownloader()
    
    private var cancellable = Set<AnyCancellable>()
    
    func fetchImage() {
      loader.downloadEscaping { [weak self] image, error in
        if let image = image {
          
          DispatchQueue.main.async {
            self?.image = image
          }
        } else {
          
          print("❌", error?.localizedDescription)
        }
      }
    }
    
    func fetchImageCombine() {
      loader.downloadWithCombine()
        .receive(on: DispatchQueue.main)
        .sink(receiveCompletion: { _ in
          
        }, receiveValue: { [weak self] image in
          self?.image = image
        })
        .store(in: &cancellable)
    }
    
    @MainActor
    func fetchImageAsync() async {
      do {
        self.image = try await loader.downloadImageAsync()
      } catch {
        print("❌", error.localizedDescription)
      }
    }
    
  }
}


class ImageDownloader {
  
  let url = URL(string: "https://cdn.pixabay.com/photo/2022/06/21/21/56/konigssee-7276585_960_720.jpg")!
  
  func downloadWithCombine() -> AnyPublisher<UIImage?, Error> {
    
    URLSession.shared.dataTaskPublisher(for: url)
      .map { [weak self] (data: Data, response: URLResponse) in
        return self?.handleResponse(data: data, response: response)
      }
      .mapError({ urlError in
        urlError
      })
      .eraseToAnyPublisher()
  }
  
  func downloadEscaping(completionHandler: @escaping (_ image: UIImage?, _ error: Error?) -> Void) {
    URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
      
      
      completionHandler(self?.handleResponse(data: data, response: response), error)
      
    }.resume()
  }
  
  func downloadImageAsync() async throws -> UIImage? {
    let (data, response) = try await URLSession.shared.data(from: url)
    return self.handleResponse(data: data, response: response)
  }
  
  func handleResponse(data: Data?, response: URLResponse?) -> UIImage? {
    guard let data = data,
          let image = UIImage(data: data),
          let response = response as? HTTPURLResponse,
          response.statusCode == 200 else {
      return nil
    }
    
    return image
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
