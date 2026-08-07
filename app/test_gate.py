import onnxruntime as ort
import numpy as np
from PIL import Image
import os

model_path = r"c:\Users\hameed\skinguard_ai\assets\models\ood_gate.onnx"
session = ort.InferenceSession(model_path)

mean = np.array([0.485, 0.456, 0.406], dtype=np.float32)
std = np.array([0.229, 0.224, 0.225], dtype=np.float32)

images = {
    "Wall": r"C:\Users\hameed\.gemini\antigravity-ide\brain\6c593f55-36ee-4c38-8366-82199e9dc64d\test_wall_1786092815879.png",
    "Face": r"C:\Users\hameed\.gemini\antigravity-ide\brain\6c593f55-36ee-4c38-8366-82199e9dc64d\test_face_1786092835212.png",
    "Object (Couch)": r"C:\Users\hameed\.gemini\antigravity-ide\brain\6c593f55-36ee-4c38-8366-82199e9dc64d\test_object_1786092856193.png",
    "Plain Skin": r"C:\Users\hameed\.gemini\antigravity-ide\brain\6c593f55-36ee-4c38-8366-82199e9dc64d\test_skin_1786092879711.png",
}

print("Running OOD Gate Verification Test...")
print("-" * 50)

for name, path in images.items():
    if not os.path.exists(path):
        print(f"File not found: {path}")
        continue
        
    img = Image.open(path).convert("RGB")
    img = img.resize((224, 224), Image.Resampling.BILINEAR)
    
    img_data = np.array(img, dtype=np.float32) / 255.0
    img_data = (img_data - mean) / std
    
    # HWC to NCHW
    img_data = np.transpose(img_data, (2, 0, 1))
    img_data = np.expand_dims(img_data, axis=0)
    
    inputs = {session.get_inputs()[0].name: img_data}
    outs = session.run(None, inputs)
    
    # Sigmoid on output
    raw_val = outs[0][0][0]
    prob = 1.0 / (1.0 + np.exp(-raw_val))
    
    print(f"[{name}]")
    print(f"  valid_lesion prob: {prob:.4f}")
    if prob < 0.85:
        print("  Verdict: REJECTED (Gate working correctly)")
    else:
        print("  Verdict: PASSED (Failed rejection)")
    print("-" * 50)
