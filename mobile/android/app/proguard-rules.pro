# Keep TensorFlow Lite GPU delegate classes (referenced reflectively).
-keep class org.tensorflow.lite.gpu.** { *; }
-dontwarn org.tensorflow.lite.gpu.**

# Keep TensorFlow Lite core classes.
-keep class org.tensorflow.lite.** { *; }
-dontwarn org.tensorflow.lite.**
