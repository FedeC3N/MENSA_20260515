%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Crea structura de carpeta para supercomputador
% Este script:
% 1) Busca archivos .nii.gz con patrón HIQ_XXX_..._nii.gz
% 2) Extrae los IDs únicos HIQ_XXX
% 3) Crea una carpeta por sujeto
% 4) Mueve a esa carpeta todos los archivos que empiecen por ese ID
% 5) Copia a cada carpeta: acqparm.txt, bval, bvec
%
% 09/04/2026
% Federico Ramirez-Torano
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
clear
clc
restoredefaultpath

% =========================
%  RUTA DE LA CARPETA RAÍZ
%  =========================
root_dir = fullfile('C:','Users','Human','Desktop','IZB','Proyectos','HIQ','Estudios','MENSA_20260515','MRI','data','DWI');

% =========================
%  ARCHIVOS A COPIAR
%  =========================
files_to_copy = {'acqparm.txt', 'bval', 'bvec'};

% =========================
%  COMPROBACIONES INICIALES
%  =========================
if ~isfolder(root_dir)
    error('La carpeta no existe: %s', root_dir);
end

for i = 1:numel(files_to_copy)
    src_file = fullfile(root_dir, files_to_copy{i});
    if ~isfile(src_file)
        warning('No se encontró el archivo a copiar: %s', src_file);
    end
end

% % =========================
%  BUSCAR ARCHIVOS NIFTI
%  =========================
all_files = dir(fullfile(root_dir, '*.nii'));
all_names = {all_files.name};

% Expresión regular:
% captura HIQ_XXX al inicio del nombre, por ejemplo:
% HIQ_024_0_DWI.nii.gz
% HIQ_024_0_T1.nii.gz
expr = '^(HIQ_[0-9]{3})_.*\.nii$';

subject_ids = {};

for i = 1:numel(all_names)
    tokens = regexp(all_names{i}, expr, 'tokens', 'once');
    if ~isempty(tokens)
        subject_ids{end+1} = tokens{1}; %#ok<SAGROW>
    end
end

subject_ids = unique(subject_ids);

fprintf('Se encontraron %d sujetos únicos.\n', numel(subject_ids));
disp(subject_ids(:));

% =========================
%  CREAR CARPETAS Y MOVER
%  =========================
for i = 1:numel(subject_ids)
    subj_id = subject_ids{i};
    subj_dir = fullfile(root_dir, subj_id);

    % Crear carpeta si no existe
    if ~isfolder(subj_dir)
        mkdir(subj_dir);
        fprintf('Carpeta creada: %s\n', subj_dir);
    end

    % Buscar todos los archivos que empiecen por ese ID
    subj_files = dir(fullfile(root_dir, [subj_id, '_*']));

    for j = 1:numel(subj_files)
        % Saltar carpetas
        if subj_files(j).isdir
            continue;
        end

        src = fullfile(root_dir, subj_files(j).name);
        dst = fullfile(subj_dir, subj_files(j).name);

        % No mover si el archivo ya está en destino
        if isfile(dst)
            warning('Ya existe en destino, no se mueve: %s', dst);
            continue;
        end

        movefile(src, dst);
        fprintf('Movido: %s -> %s\n', subj_files(j).name, subj_id);
    end

    % Copiar acqparm.txt, bval y bvec a la carpeta del sujeto
    for k = 1:numel(files_to_copy)
        src_copy = fullfile(root_dir, files_to_copy{k});
        dst_copy = fullfile(subj_dir, files_to_copy{k});

        if isfile(src_copy)
            copyfile(src_copy, dst_copy);
            fprintf('Copiado a %s: %s\n', subj_id, files_to_copy{k});
        end
    end
end

fprintf('\nOrganización completada.\n');