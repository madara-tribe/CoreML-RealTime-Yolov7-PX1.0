import AVFoundation
import Vision
import SwiftUI

final class ViewController: CALayerController {
    private var detectionOverlay: CALayer! = nil
    
    var uiimage: UIImage?
    var detecting:Bool = false
    var stime:Date!
    
    private let resnet50ModelManager = Resnet50ModelManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        resnet50ModelManager.delegate = self
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
    //confidence: VNConfidence
    func createTextSubLayerInBounds(identifier: String) -> CATextLayer {
        let textLayer = CATextLayer()
        textLayer.name = "Object Label"
        let formattedString = NSMutableAttributedString(string: String(format: "\(identifier)"))
        let largeFont = UIFont(name: "Helvetica", size: 24.0)!
        formattedString.addAttributes([NSAttributedString.Key.font: largeFont], range: NSRange(location: 0, length: identifier.count))
        textLayer.string = formattedString
        textLayer.bounds = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width, height: UIScreen.main.bounds.size.width)
        textLayer.position = CGPoint(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY)
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
        resnet50ModelManager.performRequet(image:uiimage!)
        //self.predtime.text = String(Double(uiimage!.size.height))
    }
}

extension ViewController: Resnet50ModelManagerDelegate {
    func didRecieve(_ observation: VNClassificationObservation) {
        self.detectionOverlay.sublayers = nil
        if (self.detecting == false) {
            self.detecting = true
            DispatchQueue.main.async(execute: {
                //let textLayer = self.createTextSubLayerInBounds(identifier:observation.identifier, confidence:observation.confidence)
                let textLayer = self.createTextSubLayerInBounds(identifier:"Latency: " + calcurateTime(stime:self.stime))
                //self.obsLabel2.text = "\(observation.identifier) is \(ceil(observation.confidence*1000)/10)%"
                self.detectionOverlay.addSublayer(textLayer)
                //detectionOverlay.addSublayer(self.predtime)
            })
            usleep(500*1000) // ms
            self.detecting = false
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
