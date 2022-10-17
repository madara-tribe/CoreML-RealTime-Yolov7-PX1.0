import AVFoundation
import Vision
import SwiftUI

final class ObjectDetectionController: CALayerController {
    private var detectionOverlay: CALayer! = nil
    private var requests = [VNRequest]()
    
    public let textlayer = CATextLayer()
    public let predtimer = CATextLayer()
    
    var uiimage: UIImage?
    var detecting:Bool = false
    var stime:Date!
    
    func setupVision(){
        // Setup Vision parts
        do {
            let visionModel = try VNCoreMLModel(for: YOLOv3(configuration:MLModelConfiguration()).model)
            if (self.detecting == false) {
                self.detecting = true
                let objectRecognition = VNCoreMLRequest(model: visionModel, completionHandler: { (request, error) in
                    DispatchQueue.main.async(execute: {
                        // perform all the UI updates on the main queue
                        self.stime = Date()
                        if let results = request.results {
                            self.drawVisionRequestResults(results)
                        }
                        self.calcurateTime(stime:self.stime)
                    })
                    usleep(500*500) // ms
                    self.detecting = false
                    self.detectionOverlay.sublayers = nil
                })
                self.requests = [objectRecognition]
            }
        } catch {
            fatalError("cat not load model")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        setupVision()
        // start the capture
        startCaptureSession()
        PXTest()
    }
    
    func setupLayers() {
        detectionOverlay = CALayer() // container layer that has all the renderings of the observations
        detectionOverlay.name = "DetectionOverlay"
        detectionOverlay.bounds = CGRect(x: 0.0,
                                         y: 0.0,
                                         width: bufferSize.width,
                                         height: bufferSize.height)
        detectionOverlay.position = CGPoint(x: rootLayer.bounds.midX, y: rootLayer.bounds.midY)
        rootLayer.addSublayer(detectionOverlay)
    }
    
    func drawVisionRequestResults(_ results: [Any]) {
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        detectionOverlay.sublayers = nil // remove all the old recognized objects
        for observation in results where observation is VNRecognizedObjectObservation {
            guard let objectObservation = observation as? VNRecognizedObjectObservation else {
                continue
            }
            // Select only the label with the highest confidence.
            let topLabelObservation = objectObservation.labels[0]
            let objectBounds = VNImageRectForNormalizedRect(objectObservation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
            
            let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
            
            let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                            identifier: topLabelObservation.identifier,
                                                            confidence: topLabelObservation.confidence)
            shapeLayer.addSublayer(textLayer)
            detectionOverlay.addSublayer(shapeLayer)
        }
        self.updateLayerGeometry()
        CATransaction.commit()
    }
    
    func updateLayerGeometry() {
        let bounds = rootLayer.bounds
        var scale: CGFloat
        
        let xScale: CGFloat = bounds.size.width / bufferSize.height
        let yScale: CGFloat = bounds.size.height / bufferSize.width
        
        scale = fmax(xScale, yScale)
        if scale.isInfinite {
            scale = 1.0
        }
        CATransaction.begin()
        CATransaction.setValue(kCFBooleanTrue, forKey: kCATransactionDisableActions)
        // rotate the layer into screen orientation and scale and mirror
        detectionOverlay.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: scale, y: -scale))
        // center the layer
        detectionOverlay.position = CGPoint(x: bounds.midX, y: bounds.midY)
        
        CATransaction.commit()
        
    }
    func createTextSubLayerInBounds(_ bounds: CGRect, identifier: String, confidence: VNConfidence) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\n: %.3f", confidence*100) + "%")
        let largeFont = UIFont(name: "Helvetica", size: 15.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: bounds.size.height - 10, height: bounds.size.width - 10)
        textLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        textLayer.shadowOpacity = 0.7
        textLayer.shadowOffset = CGSize(width: 2, height: 2)
        textLayer.foregroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [0.0, 0.0, 0.0, 1.0])
        textLayer.contentsScale = 2.0 // retina rendering
        // rotate the layer into screen orientation and scale and mirror
        textLayer.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(.pi / 2.0)).scaledBy(x: 1.0, y: -1.0))
        return textLayer
    }
    
    func createRoundedRectLayerWithBounds(_ bounds: CGRect) -> CALayer {
        let shapeLayer = CALayer()
        shapeLayer.bounds = bounds
        shapeLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)
        shapeLayer.name = "Found Object"
        shapeLayer.backgroundColor = CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [1.0, 1.0, 0.2, 0.4])
        shapeLayer.cornerRadius = 7
        return shapeLayer
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        let exifOrientation = exifOrientationFromDeviceOrientation()
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: [:])
        do {
            try imageRequestHandler.perform(self.requests)
        } catch {
            print(error)
        }
    }
    func PXTest(){
        // Text PX
        textlayer.string = "PX2 Testing"
        textlayer.frame = CGRect.init(x:0, y:20, width: 250, height: 30)
        //textlayer.backgroundColor = UIColor.white.cgColor
        textlayer.foregroundColor = UIColor.red.cgColor
        textlayer.fontSize = 20
        rootLayer.addSublayer(textlayer)
        
        // predtime
        predtimer.frame = CGRect.init(x:0, y:50, width: 200, height: 30)
        predtimer.backgroundColor = UIColor.white.cgColor
        predtimer.foregroundColor = UIColor.black.cgColor
        predtimer.fontSize = 20
        rootLayer.addSublayer(predtimer)
    }
    
    func calcurateTime(stime:Date){
        let timeInterval = Date().timeIntervalSince(stime)
        //let predtime = String((timeInterval * 100) / 100) + "[ms]"
        predtimer.string = "Latency: " + String(ceil(timeInterval * 10000) / 10000) + "[ms]"
    }
}


// for ".sheet(isPresented: $isStart)" method in ContentsView
extension ObjectDetectionController : UIViewControllerRepresentable{
    public typealias UIViewControllerType = ObjectDetectionController
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<ObjectDetectionController>) -> ObjectDetectionController {
        return ObjectDetectionController()
    }
    
    public func updateUIViewController(_ uiViewController: ObjectDetectionController, context: UIViewControllerRepresentableContext<ObjectDetectionController>) {
    }
}
