function [imgheaders, filenames] = loadDicomImageInfo(imagedir, ...
    studyInstanceUID)

imagefiles = dir([imagedir filesep '*']);
imagefiles = imagefiles(~[imagefiles.isdir]);

imgheaders = {};
filenames = {};

for i  = 1:length(imagefiles)
    try
        filename = fullfile(imagedir, imagefiles(i).name);
        info = dicominfo(filename);
        
        % Skip files from other studies and DICOM-RT files.
        if strcmp(info.StudyInstanceUID, studyInstanceUID ) ...
                && isempty(regexpi(info.Modality, '^RT.*'))
            imgheaders{end + 1} = info;
            filenames{end + 1} = filename;
        end
        
    catch ME
        % Don't display errors about files not in DICOM format.
        if ~strcmpi(ME.identifier, 'Images:dicominfo:notDICOM')
            warning(ME.identifier, ME.message);
        end
    end
end
