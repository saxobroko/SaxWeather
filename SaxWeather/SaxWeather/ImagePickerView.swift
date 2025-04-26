//
//  ImagePickerView.swift
//  SaxWeather
//

import SwiftUI

#if os(iOS)
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: (UIImage) -> Void
    @Environment(\.presentationMode) private var presentationMode
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                parent.onImageSelected(uiImage)
            }
            picker.dismiss(animated: true)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
#endif

#if os(macOS)
import AppKit
import UniformTypeIdentifiers

struct ImagePickerView: NSViewRepresentable {
    @Binding var image: NSImage?
    var onImageSelected: (NSImage) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: "Choose Image", target: context.coordinator, action: #selector(Coordinator.pickImage))
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {}

    class Coordinator: NSObject {
        let parent: ImagePickerView
        init(_ parent: ImagePickerView) { self.parent = parent }
        @objc func pickImage() {
            let panel = NSOpenPanel()
            if #available(macOS 12.0, *) {
                panel.allowedContentTypes = [.png, .jpeg, .heic]
            } else {
                panel.allowedFileTypes = ["png", "jpg", "jpeg", "heic"]
            }
            panel.begin { response in
                if response == .OK, let url = panel.url, let nsImage = NSImage(contentsOf: url) {
                    DispatchQueue.main.async {
                        self.parent.image = nsImage
                        self.parent.onImageSelected(nsImage)
                    }
                }
            }
        }
    }
}
#endif
