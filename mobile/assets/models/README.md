# TFLite Models

Place `yolov8n.tflite` here.

Export from Python:

```bash
yolo export model=yolov8n.pt format=tflite half=True
```

The exported file will be at `yolov8n_saved_model/yolov8n_float16.tflite`.
Rename to `yolov8n.tflite` and copy here.
