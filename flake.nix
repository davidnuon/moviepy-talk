{
  description = "Development environment for moviepy-talk notebooks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
    in
    {
      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

          python = pkgs.python3.override {
            packageOverrides = final: prev: {
              # Override moviepy to 1.0.3 so `moviepy.editor` and 1.x APIs used in the notebooks work,
              # patched for compatibility with modern decorator, matplotlib, and Pillow in nixpkgs.
              moviepy = prev.moviepy.overridePythonAttrs (old: rec {
                version = "1.0.3";
                src = pkgs.fetchFromGitHub {
                  owner = "Zulko";
                  repo = "moviepy";
                  rev = "v${version}";
                  hash = "sha256-l7AwzAKSaEV+pPbltKgwllK6X54oruU2w0AvoCsrESE=";
                };
                postPatch = ''
                  substituteInPlace moviepy/decorators.py \
                    --replace-fail "names = func_code.co_varnames[1:]" "names = f.__wrapped__.__code__.co_varnames[1:] if hasattr(f, '__wrapped__') else func_code.co_varnames[1:]"
                  substituteInPlace moviepy/video/io/bindings.py \
                    --replace-fail "buf = canvas.tostring_rgb()" "return np.asarray(canvas.buffer_rgba())[:, :, :3]"
                  substituteInPlace moviepy/video/fx/resize.py \
                    --replace-fail "Image.ANTIALIAS" "getattr(Image, 'Resampling', Image).LANCZOS"
                '';
                pythonRelaxDeps = [ "decorator" ];
                doCheck = false;
              });
            };
          };

          pythonEnv = python.withPackages (ps: with ps; [
            # Packages from requirements.txt
            appnope
            apptools
            configobj
            cycler
            decorator
            entrypoints
            imageio
            ipykernel
            ipython
            ipython-genutils
            ipywidgets
            jinja2
            jsonschema
            jupyter
            jupyter-client
            jupyter-console
            jupyter-core
            markupsafe
            matplotlib
            mistune
            moviepy
            nbconvert
            nbformat
            notebook
            numpy
            pexpect
            pickleshare
            prompt-toolkit
            ptyprocess
            pyface
            pygame
            pygments
            pyparsing
            python-dateutil
            pytz
            pyzmq
            qtconsole
            simplegeneric
            six
            terminado
            tornado
            tqdm
            traitlets
            traits
            traitsui
            wcwidth
            widgetsnbextension

            # Additional runtime dependencies for MoviePy / notebooks
            opencv4
            pillow
            scipy
          ]);

          fontsConf = pkgs.makeFontsConf {
            fontDirectories = [
              pkgs.corefonts
              pkgs.dejavu_fonts
            ];
          };
        in
        {
          default = pkgs.mkShell {
            packages = [
              pythonEnv
              pkgs.ffmpeg
              pkgs.imagemagick
              pkgs.fontconfig
              pkgs.corefonts
              pkgs.dejavu_fonts
            ];

            FONTCONFIG_FILE = "${fontsConf}";

            shellHook = ''
              # Register a "python2" kernelspec pointing to our Python environment
              # so the existing notebooks (which specify the "python2" kernel in metadata)
              # run seamlessly without needing to change kernels manually.
              export JUPYTER_DATA_DIR="''${TMPDIR:-/tmp}/moviepy-talk-jupyter-data"
              mkdir -p "$JUPYTER_DATA_DIR/kernels/python2"
              cat > "$JUPYTER_DATA_DIR/kernels/python2/kernel.json" <<EOF
              {
                "argv": [
                  "${pythonEnv}/bin/python",
                  "-m",
                  "ipykernel_launcher",
                  "-f",
                  "{connection_file}"
                ],
                "display_name": "Python (Nix DevShell)",
                "language": "python"
              }
              EOF
            '';
          };
        }
      );
    };
}
