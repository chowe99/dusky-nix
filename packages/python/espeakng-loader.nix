# espeakng-loader — bundles espeak-ng shared libraries for kokoro-onnx phonemization
{ pkgs }:

pkgs.python3Packages.buildPythonPackage rec {
  pname = "espeakng-loader";
  version = "0.2.4";
  format = "wheel";

  src = pkgs.fetchurl {
    url = "https://files.pythonhosted.org/packages/de/1e/25ec5ab07528c0fbb215a61800a38eca05c8a99445515a02d7fa5debcb32/espeakng_loader-${version}-py3-none-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
    hash = "sha256-CHIbryfRPUYfa+bu2aZSd+cNaCNP9IT9i5iXsiLNy20=";
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  buildInputs = [
    pkgs.stdenv.cc.cc.lib  # libstdc++
  ];

  pythonImportsCheck = [ "espeakng_loader" ];

  meta = {
    description = "Bundled espeak-ng for Python (used by kokoro-onnx)";
    homepage = "https://pypi.org/project/espeakng-loader/";
  };
}
