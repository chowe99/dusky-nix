# openwakeword — on-device wake word detection
{ pkgs }:

let
  # Pre-download ONNX models (openwakeword expects them in resources/models/)
  releaseBase = "https://github.com/dscripka/openWakeWord/releases/download/v0.5.1";
  models = {
    "hey_jarvis_v0.1.onnx" = pkgs.fetchurl {
      url = "${releaseBase}/hey_jarvis_v0.1.onnx";
      hash = "sha256-lKE8/mAHWxMvakcufkYugSPucIYbw/tYQ0pzcS7g0ss=";
    };
    "embedding_model.onnx" = pkgs.fetchurl {
      url = "${releaseBase}/embedding_model.onnx";
      hash = "sha256-cNFkKQwdCV0dTuFJvF4AVDJQpzFrWfMdBWz/e9MHXB8=";
    };
    "melspectrogram.onnx" = pkgs.fetchurl {
      url = "${releaseBase}/melspectrogram.onnx";
      hash = "sha256-uisOD4t7h1NposicsTNg/1O6xDbyiVzO2fR5+mXrF28=";
    };
  };
in
pkgs.python3Packages.buildPythonPackage rec {
  pname = "openwakeword";
  version = "0.6.0";
  format = "wheel";

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/8a/33/dafd6822bebe463a9098951d06a0d88fb4f8c946ce087025bc4fa132e533/openwakeword-${version}-py3-none-any.whl";
    hash = "sha256-b0I6Tjrp3Q480StQ/4q/aWefaHtKs0nXyCwCHA4qvJ0=";
  };

  dependencies = with pkgs.python3Packages; [
    onnxruntime
    numpy
    scipy
    scikit-learn
    tqdm
    requests
  ];

  # tflite-runtime is not in nixpkgs but openwakeword works with onnxruntime alone
  pythonRemoveDeps = [ "tflite-runtime" ];

  # Install ONNX models into the package's resources/models/ directory
  postInstall = ''
    MODEL_DIR="$out/${pkgs.python3.sitePackages}/openwakeword/resources/models"
    mkdir -p "$MODEL_DIR"
    ${builtins.concatStringsSep "\n" (
      pkgs.lib.mapAttrsToList (name: src: ''cp ${src} "$MODEL_DIR/${name}"'') models
    )}
  '';

  pythonImportsCheck = [ "openwakeword" ];

  meta = {
    description = "Open-source on-device wake word detection";
    homepage = "https://pypi.org/project/openwakeword/";
  };
}
