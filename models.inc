# Model download definitions for test coverage
# Changing this file invalidates the CI model cache (key includes file hash)

download-models: download
	@$(DL) tgz    mobilenet_v2_1.0_224_quant.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/mobilenet_v2_1.0_224_quant.tgz"
	@$(DL) tgz    inception_v4_299_quant.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/inception_v4_299_quant_20181026.tgz"
	@$(DL) zip    detect.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip" \
		detect.tflite
	@$(DL) direct multi_person_mobilenet_v1_075_float.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/gpu/multi_person_mobilenet_v1_075_float.tflite"
	@$(DL) direct deeplabv3_257_mv_gpu.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/gpu/deeplabv3_257_mv_gpu.tflite"
	@$(DL) zip    smartreply.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/smartreply_1.0_2017_11_01.zip" \
		smartreply.tflite
	@$(DL) zip    mobilebert_float_20191023.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/bert_qa/mobilebert_qa_vocab.zip" \
		mobilebert_float_20191023.tflite
	@$(DL) direct text_classification.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/text_classification/text_classification.tflite"
	@$(DL) base64 mobilenet_v3-small_224_1.0_float.tflite \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/mobilenet_v3-small_224_1.0_float.tflite?format=TEXT"
	@$(DL) base64 asr_float.tflite \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/asr_float.tflite?format=TEXT"
	@$(DL) base64 tts_float.tflite \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/tts_float.tflite?format=TEXT"
