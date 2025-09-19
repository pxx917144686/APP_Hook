import SwiftUI
import UIKit

@available(iOS 15, *)
final class SatellaController: UIViewController {
    static let shared: SatellaController = .init()
    
    var model: SatellaModel = .shared
    var host: UIView = .init()
    var windows: [UIWindow] = []
    
    override func loadView() {
        view = PassthroughView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let size: CGSize = UIScreen.main.bounds.size
        let geoX: Double = size.width * 0.85
        let geoY: Double = size.height * 0.5
        
        view.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: size)
        
        let tellaVC: UIHostingController = .init(rootView: SatellaView())
        let tapGest: UITapGestureRecognizer = .init(target: self, action: #selector(handleTap))
        let panGest: UIPanGestureRecognizer = .init(target: self, action: #selector(handlePan))
        
        host = UIView(frame: CGRect(origin: CGPoint(x: geoX, y: geoY), size: CGSize(width: 33, height: 33)))
        
        tellaVC.view.frame = CGRect(origin: CGPoint(x: 0, y: 0), size: CGSize(width: 33, height: 33))
        tellaVC.view.backgroundColor = .clear
        host.backgroundColor = .clear
        
        host.addGestureRecognizer(tapGest)
        host.addGestureRecognizer(panGest)
        
        host.addSubview(tellaVC.view)
        view.addSubview(host)
    }
    
    @objc func handleTap() {
        model.isShowing.toggle()
    }
    
    @objc func handlePan(gesture: UIPanGestureRecognizer) {
        host.center = gesture.location(in: view)
    }
}

