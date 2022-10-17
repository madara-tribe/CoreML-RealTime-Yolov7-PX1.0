import AVFoundation
import Vision
import SwiftUI

final class ViewController: CALayerController {
    private var detectionOverlay: CALayer! = nil
    
    var uiimage: UIImage?
    var detecting:Bool = false
    var stime:Date!
    
    private let YOLOModel = YOLOModelManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        YOLOModel.delegate = self
        // setup Vision parts
        setupLayers()
        updateLayerGeometry()
        // ML process method
        
        // start the capture
        startCaptureSession()
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
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)\nConfidence:  %.2f", confidence))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
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
        uiimage = UIImageFromSampleBuffer(sampleBuffer)
        self.stime = Date()
        //uiimage = UIResize(image:uiimage!, width:224.0)
        YOLOModel.performRequet(image:uiimage!)
        //self.predtime.text = String(Double(uiimage!.size.height))
    }
    
    
}

extension ViewController: YOLOModelManagerDelegate {
    func didRecieve(_ results: [VNRecognizedObjectObservation]) {
        self.detectionOverlay.sublayers = nil
        for observation in results where observation is VNRecognizedObjectObservation {
            if (self.detecting == false) {
                self.detecting = true
                let topLabelObservation = observation.labels[0]
                let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(bufferSize.width), Int(bufferSize.height))
                DispatchQueue.main.async(execute: {
                    let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                    let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                                    identifier: topLabelObservation.identifier,
                                                                    confidence: topLabelObservation.confidence)
                    //let textLayer = self.createTextSubLayerInBounds(identifier:"Latency: " + calcurateTime(stime:self.stime))
                    shapeLayer.addSublayer(textLayer)
                    self.detectionOverlay.addSublayer(shapeLayer)
                    // \(ceil(observation.confidence*1000)/10)%"                    
                })
                usleep(500*1000) // ms
                self.detecting = false
            }
        }
    }
}

// for ".sheet(isPresented: $isStart)" method in ContentsView
extension ViewController : UIViewControllerRepresentable{
    public typealias UIViewControllerType = ViewController
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<ViewController>) -> ViewController {
        return ViewController()
    }
    
    public func updateUIViewController(_ uiViewController: ViewController, context: UIViewControllerRepresentableContext<ViewController>) {
    }
}
