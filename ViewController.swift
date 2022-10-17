import AVFoundation
import Vision
import SwiftUI

final class ViewController: CALayerController {
    private var detectionOverlay: CALayer! = nil
    public let textlayer = CATextLayer()
    public let predtimer = CATextLayer()
    
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
        // start the capture
        startCaptureSession()
        PXTest()
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
        uiimage = UIImageFromSampleBuffer(sampleBuffer)
        self.stime = Date()
        YOLOModel.performRequet(image:uiimage!)
    }
    
    func UIImageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
            let imageRect = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer))
            let context = CIContext()
            if let image = context.createCGImage(ciImage, from: imageRect) {
                return UIImage(cgImage: image)
            }
        }
        return nil
    }
    
    
}

extension ViewController: YOLOModelManagerDelegate {
    func didRecieve(_ results: [VNRecognizedObjectObservation]) {
        if (self.detecting == false) {
            self.detecting = true
            DispatchQueue.main.async(execute: {
                for observation in results where observation is VNRecognizedObjectObservation {
                    let topLabelObservation = observation.labels[0]
                    let objectBounds = VNImageRectForNormalizedRect(observation.boundingBox, Int(self.bufferSize.width), Int(self.bufferSize.height))
                    let shapeLayer = self.createRoundedRectLayerWithBounds(objectBounds)
                    let textLayer = self.createTextSubLayerInBounds(objectBounds,
                                                                    identifier: topLabelObservation.identifier,
                                                                    confidence: topLabelObservation.confidence)
                    shapeLayer.addSublayer(textLayer)
                    self.detectionOverlay.addSublayer(shapeLayer)
                    self.calcurateTime(stime:self.stime)
                }
            })
            usleep(500*500) // ms
            self.detecting = false
            self.detectionOverlay.sublayers = nil
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
