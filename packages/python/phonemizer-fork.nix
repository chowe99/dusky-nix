# phonemizer-fork — text-to-phoneme conversion (fork used by kokoro-onnx)
{ pkgs }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "phonemizer-fork";
  version = "3.3.2";
  format = "wheel";

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/64/f1/0dcce21b0ae16a82df4b6583f8f3ad8e55b35f7e98b6bf536a4dd225fa08/phonemizer_fork-${version}-py3-none-any.whl";
    hash = "sha256-lzBcdvQYOzgl2uj0wDImX+eMmUbOWMR9S2IWE0kmS3Q=";
  };

  dependencies = with pkgs.python3Packages; [
    attrs
    dlinfo
    joblib
    segments
    typing-extensions
  ];

  pythonImportsCheck = [ "phonemizer" ];

  meta = {
    description = "Text-to-phoneme conversion (fork for kokoro-onnx)";
    homepage = "https://pypi.org/project/phonemizer-fork/";
  };
}
