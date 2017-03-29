## Create TomoDirect per-beam DICOM RTDOSE files

by Mark Geurts <mark.w.geurts@gmail.com>
<br>Copyright &copy; 2016, University of Wisconsin Board of Regents

`CreateTomoDirectDose` reads in TomoDirect DQA per-beam binary doses and creates a DICOM RTDOSE file that can be opened by a DICOM viewer. The software can also adjust the IEC Y position to make the per beam DICOM RTDOSE files compatible with the ScandiDos Delta4 software, to allow per beam IMRT QA analysis of TomoDirect plans. The function requires the DICOM RTPLAN to generate the DICOM header and binary .img/.header files exported from the TomoTherapy DQA Software.

TomoTherapy and TomoDirect are a registered trademarks of Accuray Incorporated. Delta4 is a registered trademark of ScandiDos AB. MATLAB is a registered trademark of MathWorks Inc. 

## Contents

* [Installation and Use](README.md#installation-and-use)
* [Compatibility and Requirements](README.md#compatibility-and-requirements)
* [Troubleshooting](README.md#troubleshooting)

## Installation and Use

To install the function as a MATLAB App, download and execute the `CreateTomoDirectDose.mlappinstall` file from this directory. If downloading the repository via git, make sure to download all submodules by running  `git clone --recursive https://github.com/mwgeurts/tomodirect_beams`.

This function can be executed without input arguments, upon which it will prompt the user to select the DICOM RTPLAN file and then the folder containing the binary dose files. The function will scan recursively through subfolders to identify all binary dose files. The per beam DICOM RTDOSE files will be written to the same folder as the selected DICOM RTPLAN file. 

Alternatively, the function can be executed with two inputs, the first the file name (full or relative to this function) of the DICOM RTPlan file and the second as the path to the binary folder. A flag to apply the beam isocenter offset can optionally be passed as a third input argument('yes' or 'no').

Finally, if specified the written DICOM files will be returned as a cell array. Several examples are shown below:

```matlab
% Execute function with no inputs, storing the files  
files = CreateTomoDirectDose;

% Execute function with input arguments, not storing the result  
CreateTomoDirectDose('/path/rtplan.dcm', '/path/to/binary', 'yes');
```

## Compatibility and Requirements

This function has been validated for MATLAB version 8.5 on Macintosh OSX 10.10 (Yosemite). The function and its components use the Image Processing Toolbox MATLAB functions `dicominfo()` and `dicomwrite()` to read and write to the provided DICOM files.

## Troubleshooting

This application records key input parameters and results to a log.txt file using the `Event()` function. The log is the most important route to troubleshooting errors encountered by this software.  The author can also be contacted using the information above.  Refer to the license file for a full description of the limitations on liability when using or this software or its components.

## License

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with this program. If not, see http://www.gnu.org/licenses/.
