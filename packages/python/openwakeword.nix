# openwakeword — on-device wake word detection
{ pkgs }:

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

  pythonImportsCheck = [ "openwakeword" ];

  meta = {
    description = "Open-source on-device wake word detection";
    homepage = "https://pypi.org/project/openwakeword/";
  };
}
