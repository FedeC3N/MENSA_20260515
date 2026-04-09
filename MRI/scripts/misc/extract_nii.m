%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Descomprimir NIfTI (.nii.gz ? .nii)
% Este script:
% 1) Recorre todas las subcarpetas de root_dir
% 2) Busca archivos .nii.gz
% 3) Los descomprime a .nii
% 4) Elimina el .nii.gz original
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear
clc
restoredefaultpath

% =========================
%  RUTA DE LA CARPETA RAÍZ
%  =========================
root_dir = fullfile('C:','Users','Human','Desktop','IZB','Proyectos','HIQ','Estudios','MENSA_20260515','MRI','data');

if ~isfolder(root_dir)
    error('La carpeta no existe: %s', root_dir);
end

% =========================
%  BUSCAR SUBCARPETAS
%  =========================
subdirs = dir(root_dir);
subdirs = subdirs([subdirs.isdir]);
subdirs = subdirs(~ismember({subdirs.name}, {'.','..'}));

fprintf('Se encontraron %d carpetas.\n', numel(subdirs));

% =========================
%  PROCESAR CADA SUJETO
%  =========================
for i = 1:numel(subdirs)

    subj_dir = fullfile(root_dir, subdirs(i).name);

    fprintf('\nProcesando carpeta: %s\n', subdirs(i).name);

    % Buscar .nii.gz en la carpeta (no recursivo)
    gz_files = dir(fullfile(subj_dir, '*.nii.gz'));

    for j = 1:numel(gz_files)

        gz_path = fullfile(subj_dir, gz_files(j).name);

        % Nombre destino (.nii)
        nii_name = erase(gz_files(j).name, '.gz');
        nii_path = fullfile(subj_dir, nii_name);

        % Si ya existe el .nii, no recomprimir
        if isfile(nii_path)
            warning('Ya existe: %s ? se elimina solo el .gz', nii_name);
            delete(gz_path);
            continue;
        end

        try
            % Descomprimir
            gunzip(gz_path);

            % Eliminar el .gz
            delete(gz_path);

            fprintf('OK: %s\n', gz_files(j).name);

        catch ME
            warning('Error con %s: %s', gz_files(j).name, ME.message);
        end

    end
end

fprintf('\nDescompresión completada.\n');