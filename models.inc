# Model download definitions for test coverage
# Changing this file invalidates the CI model cache (key includes file hash)

download-models: download
	@# mobilenet_v2 (tgz, 43MB archive)
	curl -sL --fail \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite_11_05_08/mobilenet_v2_1.0_224_quant.tgz" \
		| tar xzf - -C $(MODEL_DIR) mobilenet_v2_1.0_224_quant.tflite
	@# inception_v4 (tgz, 700MB archive - stream-extract just the .tflite)
	curl -sL --fail \
		"https://storage.googleapis.com/download.tensorflow.org/models/inception_v4_299_quant_20181026.tgz" \
		| tar xzf - -C $(MODEL_DIR) inception_v4_299_quant.tflite
	@# coco_ssd (zip, 2.8MB archive)
	curl -sL --fail -o $(MODEL_DIR)/_coco_ssd.zip \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/coco_ssd_mobilenet_v1_1.0_quant_2018_06_29.zip"
	unzip -joq $(MODEL_DIR)/_coco_ssd.zip detect.tflite -d $(MODEL_DIR)
	rm -f $(MODEL_DIR)/_coco_ssd.zip
	@# multi_person_mobilenet (direct .tflite, 5MB)
	curl -sL --fail -o $(MODEL_DIR)/multi_person_mobilenet_v1_075_float.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/gpu/multi_person_mobilenet_v1_075_float.tflite"
	@# deeplabv3 (direct .tflite, 2.8MB)
	curl -sL --fail -o $(MODEL_DIR)/deeplabv3_257_mv_gpu.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/gpu/deeplabv3_257_mv_gpu.tflite"
	@# smartreply (zip, 6MB archive)
	curl -sL --fail -o $(MODEL_DIR)/_smartreply.zip \
		"https://storage.googleapis.com/download.tensorflow.org/models/smartreply_1.0_2017_11_01.zip"
	unzip -joq $(MODEL_DIR)/_smartreply.zip smartreply.tflite -d $(MODEL_DIR)
	rm -f $(MODEL_DIR)/_smartreply.zip
	@# mobilebert (zip, 93MB archive)
	curl -sL --fail -o $(MODEL_DIR)/_mobilebert.zip \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/bert_qa/mobilebert_qa_vocab.zip"
	unzip -joq $(MODEL_DIR)/_mobilebert.zip mobilebert_float_20191023.tflite -d $(MODEL_DIR)
	rm -f $(MODEL_DIR)/_mobilebert.zip
	@# text_classification (direct .tflite, 0.8MB)
	curl -sL --fail -o $(MODEL_DIR)/text_classification.tflite \
		"https://storage.googleapis.com/download.tensorflow.org/models/tflite/text_classification/text_classification.tflite"
	@# Android MLTS models from googlesource (base64-encoded, new ops: hard_swish, lstm, rnn, log_softmax)
	@# mobilenet_v3 (10MB - adds hard_swish)
	curl -sL --fail \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/mobilenet_v3-small_224_1.0_float.tflite?format=TEXT" \
		| base64 -d > $(MODEL_DIR)/mobilenet_v3-small_224_1.0_float.tflite
	@# asr_float (19MB - adds lstm, log_softmax)
	curl -sL --fail \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/asr_float.tflite?format=TEXT" \
		| base64 -d > $(MODEL_DIR)/asr_float.tflite
	@# tts_float (1.4MB - adds rnn)
	curl -sL --fail \
		"https://android.googlesource.com/platform/test/mlts/models/+/refs/heads/main/assets/tts_float.tflite?format=TEXT" \
		| base64 -d > $(MODEL_DIR)/tts_float.tflite
