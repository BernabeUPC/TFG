clear all
clc

%% Select and open the DICOM archives
OGarchives_route = '***';

% Selection of the route where the new archives will be stored
AnonArchives_route = '***';

% Separation of the DICOM archives from the rest of the selected folder
dicom_archives = dir(fullfile(OGarchives_route, '*.dcm'));

%% Anonymization of each of the DICOM archives

for i = 1:length(dicom_archives)
    % Route of the original archive
    dcmOG_route = fullfile(OGarchives_route, dicom_archives(i).name);
    % Name of the DICOM file without extension
    [~, name_without_extension, ~] = fileparts(dicom_archives(i).name);
    % Route of the output DICOM file (anonymized copy)
    copy_route = fullfile(AnonArchives_route, [name_without_extension '_anon.dcm']);
    info_dcmOG = dicominfo(dcmOG_route);
    % Creation of the copy
    if ~exist(copy_route, 'file')
        copyfile(dcmOG_route, copy_route);
    else
        disp(['The copy of ' name_without_extension ' already exists. No copy has been created.']);
        continue; 
    end
    % Anonymization process
    img_copy = dicomread(copy_route);
    Info_copy = info_dcmOG;
    [rows, columns, numberOfColorChannels] = size(img_copy);
    if numberOfColorChannels > 1
        img_gray = rgb2gray(img_copy);
    else
        img_gray = img_copy;
    end
    BW = imbinarize (img_gray);
    % Anonymization of the image
    e_struct1 = strel('disk', 10, 4);
    img_eroded = imerode (BW, e_struct1);
    e_struct2 = strel('disk', 150, 4);
    img_dil = imdilate (img_eroded, e_struct2);
    % Separation of the pixel data and application of the mask
    pixel_data_format = info_dcmOG.BitsAllocated;
    if pixel_data_format == 8
        % Transform the mask to uint8
        mask = im2uint8(img_dil);
    elseif pixel_data_format == 16
        % Transform the mask to uint16
        mask = im2uint16(img_dil);
    elseif pixel_data_format == 32
        % Transform the mask to double
        mask = im2double(img_dil);
    else 
        disp('Pixel data are not recognized');
    end
    % Aplication of the mask
    img_anon = img_copy;
    img_anon(~mask) = 0;
    % Selection of the fields to anonymize
    FieldsToRemove = {'InstitutionName','InstitutionAddress',...
        'ReferringPhysicianAdress','ReferringPhysicianTelephoneNumbers','StationName','StudyDescription',...
        'SeriesDescription','InstitutionalDepartmentName','PhysiciansOfRecord','PerformingPhysicianName',...
        'NameOfPhysiciansReadingStudy','RequestingPhysician','OperatorsName','AdmittingDiagnosesDescription',...
        'DerivationDescription','PatientBirthTime','OtherPatientIDs','OtherPatientNames','PatientBirthName','PatientAge',...
        'PatientAddress','PatientTelephoneNumbers','PatientOrientation','PatientSize','PatientWeight',...
        'PatientMotherBirthName','MilitaryRank','BranchOfService','MedicalRecordLocator','Occupation',...
        'EthnicGroup','AdditionalPatientHistory','PatientReligiousPreference','PatientComments',...
        'DeviceSerialNumber','ProtocolName','ImageComments','RequestAttributesSequence'};
    FieldsToSubstitute_NonZeroLength = {'ContentSequence'};
    FieldsToSubstitute_ZeroLength = {'AccessionNumber','ReferringPhysicianName','PatientName',...
        'PatientID','PatientBirthDate','PatientSex','StudyID',};
    FieldsToSubstitute_NonZeroLengthUID = {'InstanceCreatorUID','SOPInstanceUID',...
        'ReferencedImageSequence.Item_1.ReferencedSOPInstanceUID',...
        'ReferencedImageSequence.Item_2.ReferencedSOPInstanceUID',...
        'ReferencedImageSequence.Item_3.ReferencedSOPInstanceUID',...
        'ReferencedStudySequence.Item_1.ReferencedSOPInstanceUID',...
        'ReferencedPerformedProcedureStepSequence.Item_1.ReferencedSOPInstanceUID',...
        'ReferencedPatientSequence.Item_1.ReferencedSOPInstanceUID',...
        'SourceImageSequence.Item_1.ReferencedSOPInstanceUID','StudyInstanceUID','SeriesInstanceUID',...
        'FrameOfReferenceUID','SynchronizationFrameOfReferenceUID','StorageMediaFileSetUID',...
        'ReferencedFrameOfReferenceUID','RelatedFrameOfReferenceUID'};
    % Anonimization of the selected fields 
    for r = 1:length(FieldsToRemove)
        field = FieldsToRemove{r};
        if isfield(Info_copy, field)
            Info_copy = rmfield(Info_copy, field);
        end
    end
    for nzl = 1:length(FieldsToSubstitute_NonZeroLength)
        fieldNZL = FieldsToSubstitute_NonZeroLength{nzl};
        if isfield(Info_copy, fieldNZL)
            Info_copy.(fieldNZL) = 'Anonym'; % Add the desired non-zero length value
        end
    end
    for zl = 1:length(FieldsToSubstitute_ZeroLength)
        fieldZL = FieldsToSubstitute_ZeroLength{zl};
        if isfield(Info_copy, fieldZL)
            Info_copy.(fieldZL) = '';
        end
    end
    for nzlUID = 1:length(FieldsToSubstitute_NonZeroLengthUID)
        fieldNZLUID = FieldsToSubstitute_NonZeroLengthUID{nzlUID};
        nestedFieldArray = strsplit(fieldNZLUID, '.');
        Struct = Info_copy;
        for i = 1:length(nestedFieldArray)
            currentPart = nestedFieldArray{i};
            % Check if the current field exists in the current structure
            if isfield(Struct, currentPart)
                if i < length(nestedFieldArray)
                    % Move to the next level of the structure
                    Struct = Struct.(currentPart);
                else
                    % Creation of the dummy UID Value. It can be manually changed too
                    dummyUID = dicomuid;
                    if i > 1
                        if i == 2
                            Info_copy.(nestedFieldArray{1}).(currentPart) = dummyUID; 
                        end
                        if i == 3
                            Info_copy.(nestedFieldArray{1}).(nestedFieldArray{2}).(currentPart) = dummyUID; 
                        end
                        if i == 4
                            Info_copy.(nestedFieldArray{1}).(nestedFieldArray{2}).(nestedFieldArray{3}).(currentPart) = dummyUID; 
                        end
                    else
                        Info_copy.(currentPart) = dummyUID; 
                    end
                end
            else
                % The field doesn't exist
                disp(['Field not found: ', fieldNZLUID]);
            end
        end
    end
    % Save the modifications in the new DICOM file
    dicomwrite(img_anon, copy_route, Info_copy, 'CreateMode', 'copy');
end