function contours = dicomrt2matlab(rtssfile, imagedir, vol)

%% Parse input
if nargin < 2 || isempty(imagedir)
  imagedir = fileparts(rtssfile);
end

%% Load DICOM headers
fprintf('Reading image headers...\n');
rtssheader = dicominfo(rtssfile);
[imageheaders, filenames] = loadDicomImageInfo(imagedir, rtssheader.StudyInstanceUID);


%% Search for each image in the image directory
addpath(genpath('~/aimutil'));

% Read the image volume, if it wasn't provided
if nargin < 3 || isempty(vol)
    vol = imRead3D(imagedir);
end

% Process each slice to get its index in the volume
imageIdx = nan(length(imageheaders), 1);
gcp
parfor i = 1 : length(imageheaders)
    slice = imRead3D(filenames{i});
    imageIdx(i) = sliceGetZ(slice, vol, 1e2); 
end


%% Read contour sequences
fprintf('Converting RT structures...\n');
%contours = readRTstructures(rtssheader, imageheaders); %#ok<NASGU> %
%Original Github code
%contours = convexPoints2bin(contours, imageheaders); %#ok<NASGU>
contours = readRTstructures(rtssheader, imageheaders, imageIdx);


