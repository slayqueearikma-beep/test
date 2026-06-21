# AITDR LaTeX screenshot insertions

This repository contains a drop-in LaTeX section for adding the Azure and Terraform screenshots to the AITDR report.

## How to use

1. Save the screenshots in the `figures/` directory using the filenames listed in `figures/README.md`.
2. In the main report `.tex` file, add this line where the screenshot evidence should appear, for example near the end of Chapter 6:

   ```tex
   \input{sections/azure_screenshots}
   ```

The report already defines `\safeincludegraphics`, so missing image files will render as placeholders instead of breaking compilation.
