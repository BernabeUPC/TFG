% Charge the desired DICOM file
DCM_route = '***';

% Read the information 
DICOM_image = dicomread(DCM_route);
info_DICOMfile = dicominfo(DCM_route);

% Display the DICOM image
figure(1)
imshow(DICOM_image, []);