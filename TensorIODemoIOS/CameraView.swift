import SwiftUI
import AVFoundation
import TensorIO

struct SheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var image: UIImage?
    @Binding var inference: NSDictionary?

    var body: some View {
        VStack {
            ZStack {
                VStack {
                    if (image != nil) {
                        Image(uiImage: image!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 250)
                    }
                    else {
                        Text("Nil image")
                    }
                    if (inference != nil) {
                        Text("Weight " + String(inference?["Weight"] as! Double))
                        Text("Height " + String(inference?["Height"] as! Double))
                        Text("Age " + String(inference?["Age"] as! Double))
                        Text("Sex " + String(inference?["Sex"] as! Double))
                    }
                }
                
            }
        }
    }
}
 
struct CustomCameraPhotoView: View {
    @State private var inference: NSDictionary?
    @State private var showSheet = false;
    @State private var showingCustomCamera = false
    @State private var inputImage: UIImage?
    
    var body: some View {
        ZStack {
            VStack {
                CustomCameraView(image: self.$inputImage, showSheet: self.$showSheet, inference: self.$inference)
            }
        }
        .sheet(isPresented: $showSheet) {
            SheetView(image: self.$inputImage, inference: self.$inference);
        }
    }
}


struct CustomCameraView: View {
    @Binding var image: UIImage?
    @Binding var showSheet: Bool
    @Binding var inference: NSDictionary?
    @State var didTapCapture: Bool = false
    var body: some View {
        ZStack(alignment: .bottom) {
            
            CustomCameraRepresentable(image: self.$image, showSheet: self.$showSheet, inference: self.$inference, didTapCapture: $didTapCapture)
            CaptureButtonView().onTapGesture {
                self.didTapCapture = true
            }
        }
    }
    
}


struct CustomCameraRepresentable: UIViewControllerRepresentable {
    
    @Environment(\.presentationMode) var presentationMode

    @Binding var image: UIImage?
    @Binding var showSheet: Bool
    @Binding var inference: NSDictionary?
    @Binding var didTapCapture: Bool
    
    func makeUIViewController(context: Context) -> CustomCameraController {
        let controller = CustomCameraController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ cameraViewController: CustomCameraController, context: Context) {
        
        if(self.didTapCapture) {
            cameraViewController.didTapRecord()
        }
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate, AVCapturePhotoCaptureDelegate {
        let parent: CustomCameraRepresentable
        
        init(_ parent: CustomCameraRepresentable) {
            self.parent = parent
        }
        
        func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
            
            parent.didTapCapture = false
            
            if let imageData = photo.fileDataRepresentation() {
                parent.image = UIImage(data: imageData)
                
                // IMPORTANT: Step 2 take captured image and perform inference
                let pixels = parent.image!.pixelBuffer()!
                let value = pixels.takeUnretainedValue() as CVPixelBuffer
                let buffer = TIOPixelBuffer(pixelBuffer:value, orientation: .up)
                let modelPath = Bundle.main.path(forResource: "phenomenal-face", ofType: "tiobundle")
                let model = TIOTFLiteModel.withBundleAtPath(modelPath!)!
                var result = model.run(on: buffer);

                parent.inference = result as! NSDictionary?;
                parent.showSheet = true;
            }
        }
    }
}

class CustomCameraController: UIViewController {
    
    var image: UIImage?
    
    var captureSession = AVCaptureSession()
    var backCamera: AVCaptureDevice?
    var frontCamera: AVCaptureDevice?
    var currentCamera: AVCaptureDevice?
    var photoOutput: AVCapturePhotoOutput?
    var cameraPreviewLayer: AVCaptureVideoPreviewLayer?
    
    //DELEGATE
    var delegate: AVCapturePhotoCaptureDelegate?
    
    func didTapRecord() {
        
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: delegate!)
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    func setup() {
        setupCaptureSession()
        setupDevice()
        setupInputOutput()
        setupPreviewLayer()
        startRunningCaptureSession()
    }
    func setupCaptureSession() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
    }
    
    func setupDevice() {
        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [AVCaptureDevice.DeviceType.builtInWideAngleCamera],
                                                                      mediaType: AVMediaType.video,
                                                                      position: AVCaptureDevice.Position.unspecified)
        for device in deviceDiscoverySession.devices {
            
            switch device.position {
            case AVCaptureDevice.Position.front:
                self.frontCamera = device
            case AVCaptureDevice.Position.back:
                self.backCamera = device
            default:
                break
            }
        }
        
        self.currentCamera = self.frontCamera
    }
    
    
    func setupInputOutput() {
        do {
            
            let captureDeviceInput = try AVCaptureDeviceInput(device: currentCamera!)
            captureSession.addInput(captureDeviceInput)
            photoOutput = AVCapturePhotoOutput()
            photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])], completionHandler: nil)
            captureSession.addOutput(photoOutput!)
            
        } catch {
            print(error)
        }
        
    }
    func setupPreviewLayer()
    {
        self.cameraPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        self.cameraPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        self.cameraPreviewLayer?.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        self.cameraPreviewLayer?.frame = self.view.frame
        self.view.layer.insertSublayer(cameraPreviewLayer!, at: 0)
        
    }
    func startRunningCaptureSession(){
        captureSession.startRunning()
    }
}


struct CaptureButtonView: View {
    @State private var animationAmount: CGFloat = 1
    var body: some View {
        Image(systemName: "photo").font(.largeTitle)
            .padding(30)
            .background(Color.red)
            .foregroundColor(.white)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.red)
                    .scaleEffect(animationAmount)
                    .opacity(Double(2 - animationAmount))
                    .animation(Animation.easeOut(duration: 1)
                        .repeatForever(autoreverses: false))
        )
            .onAppear
            {
                self.animationAmount = 2
            }
    }
}
