import SwiftUI
import CoreML
import Vision

protocol Resnet50ModelManagerDelegate: AnyObject {
    func didRecieve(_ observation: VNClassificationObservation)
}

class Resnet50ModelManager: NSObject {

    weak var delegate: Resnet50ModelManagerDelegate?

    // Request
    func CreateRequest()->VNCoreMLRequest{
        do {
            // Model instance
            let configuration = MLModelConfiguration()
            let model = try VNCoreMLModel(for: Resnet50(configuration:configuration).model)
            // create Request
            let request = VNCoreMLRequest(model:model, completionHandler:{request, error in
                // post proccesing
                self.ModelPrediction(request: request)
                
            })
            return request
        } catch {
            fatalError("cat not load model")
        }
    }
    // Model Prediction
    func ModelPrediction(request: VNRequest){
        // get results from prediction
        guard let results = request.results else{
            return
        }
        let classification = results as! [VNClassificationObservation]
        // get results label
        self.delegate?.didRecieve(classification[0])
    }
    func performRequet(image:UIImage){
        guard let ciImage = CIImage(image : image) else {
                fatalError("can not convert to CIImage")
            }
        // handler instance
        let handler = VNImageRequestHandler(ciImage: ciImage)
        // request
        let classificationRequest = CreateRequest()
        // do handler
        do {
            try handler.perform([classificationRequest])
        } catch {
            fatalError("failed to predict image")
        }
    }
}
