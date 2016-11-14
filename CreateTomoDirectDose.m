function varargout = CreateTomoDirectDose(varargin)
% CreateTomoDirectDose reads in TomoDirect DQA per-beam binary doses
% and creates a DICOM RTDOSE file that can be opened by a DICOM viewer. The
% software can also adjust the IEC Y position to make the per beam DICOM
% RTDOSE files compatible with the ScandiDos Delta4 software, to allow per
% beam IMRT QA analysis of TomoDirect plans. The function requires the
% DICOM RTPLAN to generate the DICOM header and binary .img/.header files
% exported from the TomoTherapy DQA Software.
%
% TomoTherapy and TomoDirect are a registered trademarks of Accuray 
% Incorporated. Delta4 is a registered trademark of ScandiDos AB.
%
% This function can be executed without input arguments, upon which it will
% prompt the user to select the DICOM RTPLAN file and then the folder
% containing the binary dose files. The function will scan recursively
% through subfolders to identify all binary dose files. The per beam DICOM
% RTDOSE files will be written to the same folder as the selected DICOM 
% RTPLAN file.
% 
% Alternatively, the function can be executed with two inputs, the first 
% the filename (full or relative to this function) of the DICOM RTPlan 
% file and the second as the path to the binary folder. A flag to apply the
% beam isocenter offset can optionally be passed as a third input argument
% ('yes' or 'no').
%
% Finally, if specified the written DICOM files will be returned as a cell 
% array. Several examples are shown below:
%
%   % Execute function with no inputs, storing the files
%   files = CreateTomoDirectDose;
%
%   % Execute function with input arguments, not storing the result
%   CreateTomoDirectDose('/path/rtplan.dcm', '/path/to/binary', 'yes');
%
% This function requires the MATLAB Image Processing Toolbox as it uses the
% dicominfo() and dicomwrite() functions.
%
% Author: Mark Geurts, mark.w.geurts@gmail.com
% Copyright (C) 2016 University of Wisconsin Board of Regents
%
% This program is free software: you can redistribute it and/or modify it 
% under the terms of the GNU General Public License as published by the  
% Free Software Foundation, either version 3 of the License, or (at your 
% option) any later version.
%
% This program is distributed in the hope that it will be useful, but 
% WITHOUT ANY WARRANTY; without even the implied warranty of 
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General 
% Public License for more details.
% 
% You should have received a copy of the GNU General Public License along 
% with this program. If not, see http://www.gnu.org/licenses/.

% Turn off MATLAB warnings
warning('off','all');

% Set version handle
version = '1.0.0';

% Determine path of current application
[path, ~, ~] = fileparts(mfilename('fullpath'));

% Set current directory to location of this application
cd(path);

% Set version information.  See LoadVersionInfo for more details.
versionInfo = LoadVersionInfo;

% Store program and MATLAB/etc version information as a string cell array
string = {'TomoDirect DICOM Beam Dose Creator'
    sprintf('Version: %s (%s)', version, versionInfo{6});
    sprintf('Author: Mark Geurts <mark.w.geurts@gmail.com>');
    sprintf('MATLAB Version: %s', versionInfo{2});
    sprintf('MATLAB License Number: %s', versionInfo{3});
    sprintf('Operating System: %s', versionInfo{1});
    sprintf('CUDA: %s', versionInfo{4});
    sprintf('Java Version: %s', versionInfo{5})
};

% Add dashed line separators      
separator = repmat('-', 1,  size(char(string), 2));
string = sprintf('%s\n', separator, string{:}, separator);

% Log information
Event(string, 'INIT');

%% Add DICOM tools submodule
% Add DICOM tools submodule to search path
addpath('./dicom_tools');

% Check if MATLAB can find WriteDICOMDose. This feature can be tested by
% executing TomoExport('unitWriteDICOMDose')
if exist('WriteDICOMDose', 'file') ~= 2
    
    % If not, throw an error
    Event(['The DICOM Tools submodule does not exist in the ', ...
        'search path. Use git clone --recursive or git submodule init ', ...
        'followed by git submodule update to fetch all submodules'], ...
        'ERROR');
end

% Check if MATLAB can find dicominfo
if exist('dicominfo', 'file') ~= 2
    
    % If not, throw an error
    Event(['The MATLAB Image Processing toolbox must be installed to run ', ...
        'this application'], 'ERROR');
end

%% Collect inputs
% If the file/folder were specified as inputs
if nargin >= 2
    
    % Store dicom variables
    [dicom_dir, dicom_plan, ext] = fileparts(varargin{1});
    dicom_plan = [dicom_plan ext];
    
    % Store binary dir
    binary_dir = varargin{2};
    
else
    % Request the user to select the DICOM RT-Plan
    Event('UI window opened to select file');
    [dicom_plan, dicom_dir] = uigetfile({'*.dcm', 'DICOM RT-Plan (*.dcm)'}, ...
        'Select the DICOM RT Plan', path);

    % Request the user to select the folder containing the binaries
    Event('UI window opened to select TomoDirect binary dose folder');
    binary_dir = uigetdir(path, ['Select the Folder Containing ', ...
        'the TomoDirect Binary Dose']);
end

% If use cancelled, stop execution
if isnumeric(dicom_dir) || isnumeric(binary_dir)
    Event('You must select input files', 'ERROR');
end

%% Load RTPLAN
% Load the DICOM RT Plan
Event(['Loading DICOM RT Plan ', fullfile(dicom_dir, dicom_plan)]);
rtplan = dicominfo(fullfile(dicom_dir, dicom_plan));

% Verify selected file is RT Plan
if ~isfield(rtplan, 'BeamSequence')
    Event('The file you selected is not a DICOM RT Plan', 'ERROR');
end
    
% Store patient demographics and referencing UIDs
info.seriesDescription = 'TomoDirect Beam Dose';
info.studyDescription = rtplan.StudyDescription;
info.patientName = rtplan.PatientName;
info.patientID = rtplan.PatientID;
info.patientBirthDate = rtplan.PatientBirthDate;
info.studyUID = rtplan.StudyInstanceUID;
info.frameRefUID = rtplan.FrameOfReferenceUID;
info.structureSetUID = rtplan.ReferencedStructureSetSequence.Item_1...
    .ReferencedSOPInstanceUID;
info.planUID = rtplan.SOPInstanceUID;

%% Determine beam isocenter offset
% If the user provided the Delta4 flag in varargin{3}
if nargin == 3
    
    % Store provided input
    delta = varargin{3};

% Otherwise, prompt user as to whether the export is for the Delta4
else
    delta = questdlg('Apply beam isocenter offset? (Delta4)', ...
        'IEC Y Offset', 'Yes', 'No', 'Yes');
end

% If applying red laser offset, convert private tag reference isocenter
if strcmpi(delta, 'Yes')
    
    % Log choice
    Event('User chose to apply beam isocenter offset in IEC Y');
    
    % Generate temporary file name
    t = tempname;
    
    % Open temporary file
    fid = fopen(t, 'w', 'b');
    
    % Write current 300D/10A9 tag contents (dicominfo interprets as uint8)
    fwrite(fid, rtplan.Private_300d_10a9, 'uint8');
    
    % Close file
    fclose(fid);
    
    % Open temporary file again
    fid = fopen(t, 'r', 'b');
    
    % Read back in as text, storing contents in refiso vector
    refiso = cell2mat(textscan(fid, '%f\\%f\\%f'));
    
    % Close file
    fclose(fid);
 
% Otherwise, store empty refiso vector
else
    refiso = zeros(1,3);
end

%% Load DICOM files
% Scan the directory for binary files
Event(['Scanning ', binary_dir, ' for binary files']);

% Retrieve folder contents of selected directory
list = dir(binary_dir);

% Initialize counters
i = 0;
c = 0;

% Start timer
t = tic;

% If a valid screen size is returned (MATLAB was run without -nodisplay)
if usejava('jvm') && feature('ShowFigureWindows')
    
    % Start waitbar
    p = waitbar(0, 'Generating DICOM RT Dose images from binary files');
end

% Start recursive loop through each folder, subfolder
while i < size(list, 1)

    % Update waitbar
    if exist('p', 'var') && ishandle(p)
        waitbar(i/size(list, 1), p);
    end
    
    % Increment current folder being analyzed
    i = i + 1;

    % If the folder content is . or .., skip to next folder in list
    if strcmp(list(i).name, '.') || strcmp(list(i).name, '..')
        continue

    % Otherwise, if the folder content is a subfolder    
    elseif list(i).isdir == 1

        % Retrieve the subfolder contents
        sublist = dir(fullfile(path, list(i).name));

        % Look through the subfolder contents
        for j = 1:size(sublist, 1)

            % If the subfolder content is . or .., skip to next subfolder 
            if strcmp(sublist(j).name, '.') || ...
                    strcmp(sublist(j).name, '..')
                continue
            else

                % Otherwise, replace the subfolder name with its full
                % reference
                sublist(j).name = fullfile(list(i).name, ...
                    sublist(j).name);
            end
        end

        % Append the subfolder contents to the main folder list
        list = vertcat(list, sublist); %#ok<AGROW>

        % Clear temporary variable
        clear sublist;

    % Otherwise, see if the file is an image file
    elseif strcmpi(list(i).name(end-3:end), '.img') 
        
        % Search for the gantry angle in the name
        tokens = regexpi(list(i).name, 'dose_([0-9\.]+).img', 'tokens');
        
        % If the gantry angle was not found, continue
        if isempty(tokens)
            continue;
        end
        
        % Store angle
        angle = str2double(tokens{1});
        
        % Identify beam number
        info.referencedBeamNumber = 0;
        
        % Loop through the beams
        for j = 1:length(fieldnames(rtplan.BeamSequence))
            
            % If the gantry angle equals the plan
            if angle == rtplan.BeamSequence.(sprintf('Item_%i', j))...
                    .ControlPointSequence.Item_1.GantryAngle
                
                % Store the current beam number and stop searching
                info.referencedBeamNumber = j;
                break;
            end  
        end
        
        % Assume image orientation
        info.orientation = [1;0;0;0;1;0];
        
        % Otherwise, search for associated header
        if exist(fullfile(binary_dir, [list(i).name(1:end-4), ...
                '.header']), 'file') == 2
            
            % Open file
            fid = fopen(fullfile(binary_dir, ...
                [list(i).name(1:end-4), '.header']), 'r');
            
            % Initialize header structure
            header = struct();
            
            % Retrieve first header line
            tline = fgetl(fid);
            
            % Loop through header lines
            while ischar(tline)
                
                % Scan for numeric input
                tokens = regexpi(tline, ...
                    '([a-z_])+ = ([-0-9\.]+);', 'tokens');
                
                % If line was numeric
                if ~isempty(tokens)
                    
                    % Store in header structure
                    header.(tokens{1}{1}) = str2double(tokens{1}{2});
                end
                
                % Retrieve next line
                tline = fgetl(fid);
            end
            
            % Close file
            fclose(fid);
            
        % If header is not available, warn user and skip
        else
            Event(['The associated header for ', list(i).name, ...
                ' could not be found'], 'WARN');
            continue;
        end
        
        % Open file
        fid = fopen(fullfile(binary_dir, list(i).name), 'r', 'b');
        
        % Load binary file
        dose.data = reshape(fread(fid, header.x_dim * header.y_dim * ...
            header.z_dim, 'single', 'l'), header.x_dim, header.y_dim, ...
            header.z_dim);
        
        % Set width element
        dose.start = [header.x_start header.y_start header.z_start];
        dose.width = [header.x_pixdim header.y_pixdim header.z_pixdim];
       
        % If for Delta4, apply beam isocenter offset
        if strcmpi(delta, 'Yes')

            % Adjust IEC Y position only
            dose.start(3) = header.z_start + refiso(3)/10 - ...
                 rtplan.BeamSequence.(sprintf('Item_%i', ...
                 info.referencedBeamNumber)).ControlPointSequence.Item_1...
                 .IsocenterPosition(3)/10;
        end
        
        % Close file
        fclose(fid); 
        
        % Increment counter
        c = c + 1;
        
        % Write DICOM file
        WriteDICOMDose(dose, fullfile(dicom_dir, [list(i).name(1:end-4), ...
            '.dcm']), info);
        
        % If output argument is provided
        if nargout == 1
            
            % Append file name of DICOM file to output cell array
            varargout{1}{c} = fullfile(dicom_dir, [list(i).name(1:end-4), ...
                '.dcm']);
        end
    end
end

%% Finish up
% Close waitbar
if exist('p', 'var') && ishandle(p)
    close(p);
end

% Log success
msgbox(sprintf('%i TomoDirect beam DICOM RT Dose images created', c), ...
    'Completed', 'help');
Event(sprintf(['CreateTomoDirectDose completed successfully, creating %i ', ...
    'DICOM RT Dose images in %0.03f seconds'], c, toc(t)));

% Clear temporary variables
clear angle binary_dir c delta dicom_dir dicom_plan dose ext fid header i ...
    info j list p path rtplan separator string t tline tokens version ...
    versionInfo refiso fid;