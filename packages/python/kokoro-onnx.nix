# kokoro-onnx — ONNX-based text-to-speech engine
{ pkgs, espeakng-loader, phonemizer-fork }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "kokoro-onnx";
  version = "0.5.0";
  format = "wheel";

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/0d/55/0bfcb4aa50033c89e5ac132af3d07fac0543824ce6eaefd4d1bfdcc3795b/kokoro_onnx-${version}-py3-none-any.whl";
    hash = "sha256-Thw4opbbXbwfci9p9ePBPy4od7PlsUUof1bsBXAT41c=";
  };

  dependencies = [
    espeakng-loader
    phonemizer-fork
    pkgs.python3Packages.numpy
    pkgs.python3Packages.onnxruntime
    pkgs.python3Packages.soundfile
  ];

  pythonImportsCheck = [ "kokoro_onnx" ];

  meta = {
    description = "ONNX-based text-to-speech with Kokoro voices";
    homepage = "https://pypi.org/project/kokoro-onnx/";
  };
}
