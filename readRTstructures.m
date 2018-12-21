function contours = readRTstructures(rtssheader, imgheaders, imgIdx)

%% Collect all the SOP Instance UIDs
instanceUids = {};
for i = 1 : length(imgheaders)
    instanceUids{end + 1} = imgheaders{i}.SOPInstanceUID;
end

%%
xfm = getAffineXfm(imgheaders);

dimmin = [0 0 0 1]';
dimmax = double([imgheaders{1}.Columns-1 imgheaders{1}.Rows-1 length(imgheaders)-1 1])';

template = false([imgheaders{1}.Columns imgheaders{1}.Rows length(imgheaders)]);

ROIContourSequence = fieldnames(rtssheader.ROIContourSequence);
contours = struct('ROIName', {}, 'Points', {}, 'VoxPoints', {}, ...
    'Segmentation', {}, 'color', {});

%% Loop through contours
for i = 1:length(ROIContourSequence)
    
    % Get a struct for THIS contour
    item = rtssheader.ROIContourSequence.(ROIContourSequence{i});
    contour = struct('ROIName', [], 'Points', [], 'VoxPoints', [], ...
        'Segmentation', [], 'color', item.ROIDisplayColor);
    
    contour.ROIName = rtssheader.StructureSetROISequence.(ROIContourSequence{i}).ROIName;
    contour.Segmentation = template;
    
    try
        ContourSequence = fieldnames(rtssheader.ROIContourSequence.(ROIContourSequence{i}).ContourSequence);
        
        %% Loop through segments (slices)
        segments = cell(1,length(ContourSequence));
        for j = 1:length(ContourSequence)
            
            contourData = item.ContourSequence.(ContourSequence{j});
            
            if strcmp(contourData.ContourGeometricType, 'CLOSED_PLANAR')
                %% Read points
                segments{j} = reshape(contourData.ContourData, 3, ...
                    contourData.NumberOfContourPoints)';
                
                %% Make lattice
                points = xfm \ [segments{j} ones(size(segments{j},1), 1)]';
                start = xfm \ [segments{j}(1,:) 1]';
                minvox = max(floor(min(points, [], 2)), dimmin);
                maxvox = min( ceil(max(points, [], 2)), dimmax);
                
                % Get the starting coordinate
                if nargin < 3 || isempty(imgIdx)
                    % Use DICOM coordinates, as in the original code
                    minvox(3) = round(start(3));
                else
                    % Get the corresponding image header
                    imageSequence = item.ContourSequence.(ContourSequence{j}).ContourImageSequence;
                    assert(length(imageSequence) == 1)
                    instanceUid = imageSequence.Item_1.ReferencedSOPInstanceUID;
                    isCorrectHeader = strcmp(instanceUids, instanceUid);
                    
                    % Use the pre-computed index
                    minvox(3) = imgIdx(isCorrectHeader);
                end
                maxvox(3) = minvox(3);
                
                [x,y,z] = meshgrid(minvox(1):maxvox(1), minvox(2):maxvox(2), minvox(3):maxvox(3));
                points = xfm * [x(:) y(:) z(:) ones(size(x(:)))]';
                
                %% Make binary image
                in = inpolygon(points(1,:), points(2,:), segments{j}(:,1), segments{j}(:,2));
                contour.Segmentation((minvox(1):maxvox(1))+1, (minvox(2):maxvox(2))+1, (minvox(3):maxvox(3))+1) = permute(reshape(in, size(x)), [2 1]);
                
            end
        end
        contour.Points = vertcat(segments{:});
        
        % Skip empty contours
        if isempty(contour.Points)
            warning(['Skipping empty contour ' contour.ROIName])
            continue
        end
        
        %% Save contour points in voxel coordinates
        contour.VoxPoints = xfm \ [contour.Points ones(size(contour.Points,1), 1)]';
        contour.VoxPoints = contour.VoxPoints(1:3,:)';
        
        %% Add the contour to the output
        contours(end + 1) = contour;
        
    catch ME
        % Don't display errors about non-existent fields.
        if ~strcmp(ME.identifier, 'MATLAB:nonExistentField')
            rethrow(ME)
        end
    end
    
end
